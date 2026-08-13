import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:doorstep_app/model/persistence/paired_device.dart';
import 'package:doorstep_app/model/persistence/watched_folder.dart';
import 'package:doorstep_app/provider/doorstep_pairing_provider.dart';
import 'package:doorstep_app/provider/doorstep_transfer_provider.dart';
import 'package:doorstep_app/provider/doorstep_watcher_provider.dart';
import 'package:doorstep_app/provider/settings_provider.dart';
import 'package:doorstep_app/util/native/cross_file_converters.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:refena_flutter/refena_flutter.dart';

final _logger = Logger('DoorstepBrowse');

/// The live folder browser is served on `doorstepPort + 1`. The phone learns
/// the laptop's LocalSend port from the pairing QR and derives the same port,
/// so both sides stay in sync even when the port is customized.
int doorstepBrowsePort(int doorstepPort) => doorstepPort + 1;

/// System junk that must never show up in the phone-side browser.
const _hiddenFileNames = <String>{'.DS_Store', 'Thumbs.db', 'desktop.ini'};

class DoorstepBrowseState {
  final bool running;
  final int port;
  final String? error;

  const DoorstepBrowseState({required this.running, required this.port, this.error});
}

final doorstepBrowseProvider = NotifierProvider<DoorstepBrowseNotifier, DoorstepBrowseState>((ref) {
  return DoorstepBrowseNotifier();
});

/// The laptop side of the live folder browser.
///
/// Serves three authenticated endpoints over plain HTTP (metadata only — the
/// file bytes always travel through the LocalSend mTLS transfer protocol):
///
///   GET  /doorstep/roots?token=…        → watched folders
///   GET  /doorstep/list?token=…&root=…&path=…  → one directory (lazy)
///   POST /doorstep/pull?token=…&root=…&path=… → send a file to the phone
///
/// The `token` is the phone's own pairing token; it is verified against the
/// laptop's paired-devices list in constant time.
class DoorstepBrowseNotifier extends Notifier<DoorstepBrowseState> {
  HttpServer? _server;

  @override
  DoorstepBrowseState init() {
    // Laptop-only; the phone only calls out to the laptop's server.
    unawaited(Future.microtask(_start));
    return const DoorstepBrowseState(running: false, port: 0);
  }

  Future<void> _start() async {
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) return;
    final port = doorstepBrowsePort(ref.read(settingsProvider).port);
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _server!.listen(_handleRequest, onError: (e) => _logger.warning('Browse server error: $e'));
      state = DoorstepBrowseState(running: true, port: port);
      _logger.info('Doorstep browse server listening on port $port');
    } catch (e) {
      state = DoorstepBrowseState(running: false, port: port, error: e.toString());
      _logger.warning('Failed to start Doorstep browse server on port $port: $e');
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final uri = request.uri;
      final query = uri.queryParameters;
      final paired = _authenticate(query['token'] ?? '');
      if (paired == null) {
        _respondJson(request, 401, {'error': 'unauthorized'});
        return;
      }

      // Every authenticated call is proof the phone is reachable right now —
      // keep the laptop's record fresh so reverse transfers keep working. The
      // browse page auto-refreshes every 5s, so throttle the (persisted)
      // update to avoid disk churn on every poll.
      final remoteIp = request.connectionInfo?.remoteAddress.address;
      final stale = DateTime.now().difference(paired.lastSeen).inSeconds > 60;
      if (remoteIp != null && remoteIp.isNotEmpty && remoteIp != '::1' && (remoteIp != paired.lastKnownIp || stale)) {
        unawaited(ref.notifier(doorstepPairingProvider).updateLastSeen(paired.id, remoteIp));
      }

      switch (uri.path) {
        case '/doorstep/roots':
          _handleRoots(request);
        case '/doorstep/list':
          await _handleList(request, query);
        case '/doorstep/pull':
          await _handlePull(request, paired, query);
        default:
          _respondJson(request, 404, {'error': 'not found'});
      }
    } catch (e, st) {
      _logger.warning('Browse request failed', e, st);
      _respondJson(request, 500, {'error': 'internal error'});
    }
  }

  PairedDevice? _authenticate(String token) {
    if (token.isEmpty) return null;
    for (final device in ref.read(doorstepPairingProvider)) {
      if (_constantTimeEquals(device.token, token)) return device;
    }
    return null;
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  void _handleRoots(HttpRequest request) {
    final roots = ref.read(doorstepWatcherProvider).where((f) => f.enabled).map((f) => {'id': f.id, 'name': f.name}).toList();
    _respondJson(request, 200, {'roots': roots});
  }

  Future<void> _handleList(HttpRequest request, Map<String, String> query) async {
    final root = _resolveRoot(query['root']);
    if (root == null) {
      _respondJson(request, 404, {'error': 'unknown root'});
      return;
    }
    final dirPath = await _resolveUnderRoot(root, query['path'] ?? '');
    if (dirPath == null) {
      _respondJson(request, 400, {'error': 'invalid path'});
      return;
    }
    final dir = Directory(dirPath);
    if (!dir.existsSync()) {
      _respondJson(request, 404, {'error': 'not found'});
      return;
    }

    // Collect the raw entries first, then stat them in parallel — sequential
    // `await entity.stat()` per file is very slow on folders with many files.
    final raw = await dir.list(followLinks: false).toList();
    final visible = raw.where((entity) {
      final name = p.basename(entity.path);
      return !name.startsWith('.') && !_hiddenFileNames.contains(name);
    }).toList();

    final entries = <Map<String, dynamic>>[];
    final stats = await Future.wait(
      visible.map((entity) async {
        final isDir = entity is Directory;
        var size = 0;
        DateTime? modified;
        if (!isDir) {
          try {
            final stat = await entity.stat();
            size = stat.size;
            modified = stat.modified;
          } catch (_) {
            // Unreadable entry (locked/permission) — still list it with size 0.
          }
        }
        return (name: p.basename(entity.path), isDir: isDir, size: size, modified: modified);
      }),
    );
    entries.addAll(
      stats.map(
        (s) => {
          'name': s.name,
          'isDir': s.isDir,
          'size': s.size,
          'mtime': s.modified?.toIso8601String(),
        },
      ),
    );
    entries.sort((a, b) {
      final aDir = a['isDir'] as bool;
      final bDir = b['isDir'] as bool;
      if (aDir != bDir) return aDir ? -1 : 1;
      return (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase());
    });

    _respondJson(request, 200, {'path': query['path'] ?? '', 'entries': entries});
  }

  Future<void> _handlePull(HttpRequest request, PairedDevice paired, Map<String, String> query) async {
    final root = _resolveRoot(query['root']);
    if (root == null) {
      _respondJson(request, 404, {'error': 'unknown root'});
      return;
    }
    final filePath = await _resolveUnderRoot(root, query['path'] ?? '');
    if (filePath == null || !FileSystemEntity.isFileSync(filePath)) {
      _respondJson(request, 400, {'error': 'invalid file'});
      return;
    }
    // Only answer "ok" when the phone is reachable right now — otherwise the
    // phone would show a success it cannot act on. The ip is a non-nullable
    // string, so check for the placeholder values it can actually hold.
    final target = ref.notifier(doorstepPairingProvider).resolveTarget(paired);
    final ip = target.ip;
    if (ip == null || ip.isEmpty || ip == '0.0.0.0' || ip == '-') {
      _respondJson(request, 503, {'error': 'device unreachable'});
      return;
    }
    try {
      final file = File(filePath);
      final crossFile = await CrossFileConverters.convertFile(file);
      unawaited(
        ref.notifier(doorstepTransferProvider).startTrackedTransfer(crossFile: crossFile, paired: paired, sourceLabel: 'Doorstep [browse]'),
      );
      _logger.info('Pull: sending ${p.basename(filePath)} to ${paired.alias}');
      _respondJson(request, 200, {'ok': true});
    } catch (e, st) {
      _logger.warning('Pull failed for $filePath', e, st);
      _respondJson(request, 500, {'error': 'transfer failed'});
    }
  }

  WatchedFolder? _resolveRoot(String? rootId) {
    if (rootId == null) return null;
    return ref.read(doorstepWatcherProvider).firstWhereOrNull((f) => f.id == rootId && f.enabled);
  }

  /// Resolves [rel] (a `/`-separated path relative to the watched root) into an
  /// absolute path, refusing anything that escapes the root — both textual
  /// traversal (`../`) and symlinks that point outside the watched folder.
  Future<String?> _resolveUnderRoot(WatchedFolder root, String rel) async {
    if (rel.isEmpty) return p.normalize(root.path);
    if (rel.startsWith('/') || rel.startsWith('\\')) rel = rel.substring(1);
    if (p.isAbsolute(rel)) return null;
    final full = p.normalize(p.join(root.path, rel));
    final rootNorm = p.normalize(root.path);
    if (Platform.isWindows) {
      if (!full.toLowerCase().startsWith('${rootNorm.toLowerCase()}${p.separator}')) return null;
    } else if (!full.startsWith('$rootNorm${p.separator}')) {
      return null;
    }
    // Resolve symlinks so a link inside the watched folder cannot reach out.
    try {
      final realFull = await Directory(full).resolveSymbolicLinks();
      final realRoot = await Directory(rootNorm).resolveSymbolicLinks();
      if (!_isWithin(realRoot, realFull)) return null;
    } catch (_) {
      return null;
    }
    return full;
  }

  bool _isWithin(String parent, String child) {
    final p1 = Platform.isWindows ? parent.toLowerCase() : parent;
    final p2 = Platform.isWindows ? child.toLowerCase() : child;
    return p2 == p1 || p2.startsWith('$p1${p.separator}');
  }

  void _respondJson(HttpRequest request, int status, Object body) {
    final bytes = utf8.encode(jsonEncode(body));
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..contentLength = bytes.length
      ..add(bytes);
    unawaited(request.response.close());
  }
}
