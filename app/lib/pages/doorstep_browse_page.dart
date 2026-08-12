import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:localsend_app/config/doorstep_theme.dart';
import 'package:localsend_app/model/persistence/paired_device.dart';
import 'package:localsend_app/provider/doorstep_browse_provider.dart';
import 'package:localsend_app/provider/doorstep_pairing_provider.dart';
import 'package:localsend_app/widget/doorstep_card.dart';
import 'package:localsend_isolates/util/file_size_helper.dart';
import 'package:refena_flutter/refena_flutter.dart';

// ── Data models for the laptop's browse API ────────────────────────────────

class DoorstepBrowseRoot {
  final String id;
  final String name;

  const DoorstepBrowseRoot({required this.id, required this.name});

  factory DoorstepBrowseRoot.fromJson(Map<String, dynamic> json) => DoorstepBrowseRoot(id: json['id'] as String, name: json['name'] as String);
}

class DoorstepBrowseEntry {
  final String name;
  final bool isDir;
  final int size;
  final DateTime? modified;

  const DoorstepBrowseEntry({required this.name, required this.isDir, required this.size, this.modified});

  factory DoorstepBrowseEntry.fromJson(Map<String, dynamic> json) => DoorstepBrowseEntry(
    name: json['name'] as String,
    isDir: json['isDir'] as bool,
    size: (json['size'] as num?)?.toInt() ?? 0,
    modified: json['mtime'] != null ? DateTime.tryParse(json['mtime'] as String) : null,
  );
}

class DoorstepBrowseException implements Exception {
  final int statusCode;
  final String body;

  DoorstepBrowseException(this.statusCode, this.body);

  @override
  String toString() => 'Browse request failed ($statusCode)';
}

/// Thin client for the laptop's `/doorstep/*` endpoints. File bytes are never
/// exchanged here — [requestPull] only asks the laptop to start a LocalSend
/// transfer, which then flows through the normal (encrypted) pipeline.
class DoorstepBrowseApi {
  static const _connectTimeout = Duration(seconds: 5);

  /// A listing of a very large folder can legitimately take a while to build
  /// and ship; the cap just guarantees the phone never waits forever on a
  /// hung (or gone) laptop.
  static const _responseTimeout = Duration(seconds: 30);

  static Uri _uri(String host, int port, String endpoint, Map<String, String> params) {
    return Uri(
      scheme: 'http',
      host: host,
      port: port,
      path: '/doorstep/$endpoint',
      queryParameters: params,
    );
  }

  static Future<Map<String, dynamic>> _getJson(String host, int port, String token, String endpoint, Map<String, String> params) async {
    final client = HttpClient()..connectionTimeout = _connectTimeout;
    try {
      final request = await client.getUrl(_uri(host, port, endpoint, {...params, 'token': token})).timeout(_connectTimeout);
      final response = await request.close().timeout(_connectTimeout);
      final body = await response.transform(utf8.decoder).join().timeout(_responseTimeout);
      if (response.statusCode != 200) {
        throw DoorstepBrowseException(response.statusCode, body);
      }
      return jsonDecode(body) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }

  static Future<List<DoorstepBrowseRoot>> fetchRoots(String host, int port, String token) async {
    final json = await _getJson(host, port, token, 'roots', {});
    final list = (json['roots'] as List?) ?? const [];
    return list.map((e) => DoorstepBrowseRoot.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<DoorstepBrowseEntry>> fetchListing(
    String host,
    int port,
    String token, {
    required String root,
    required String path,
  }) async {
    final json = await _getJson(host, port, token, 'list', {'root': root, 'path': path});
    final list = (json['entries'] as List?) ?? const [];
    return list.map((e) => DoorstepBrowseEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> requestPull(
    String host,
    int port,
    String token, {
    required String root,
    required String path,
  }) async {
    final client = HttpClient()..connectionTimeout = _connectTimeout;
    try {
      final request = await client.postUrl(_uri(host, port, 'pull', {'root': root, 'path': path, 'token': token})).timeout(_connectTimeout);
      final response = await request.close().timeout(_connectTimeout);
      await response.drain<void>().timeout(_responseTimeout);
      if (response.statusCode != 200) {
        throw DoorstepBrowseException(response.statusCode, 'pull failed');
      }
    } finally {
      client.close(force: true);
    }
  }
}

// ── Page ───────────────────────────────────────────────────────────────────

class DoorstepBrowsePage extends StatefulWidget {
  /// Optional pre-selected laptop; when null the most recently seen one is used
  /// (and a switcher appears in the app bar when several are paired).
  const DoorstepBrowsePage({super.key, this.laptop});

  final PairedDevice? laptop;

  @override
  State<DoorstepBrowsePage> createState() => _DoorstepBrowsePageState();
}

class _DoorstepBrowsePageState extends State<DoorstepBrowsePage> with Refena {
  static const _refreshInterval = Duration(seconds: 15);

  PairedDevice? _laptop;
  String? _token;
  List<PairedDevice> _paired = const [];
  List<DoorstepBrowseRoot>? _roots;
  DoorstepBrowseRoot? _root;
  final List<String> _pathStack = [];
  List<DoorstepBrowseEntry>? _entries;
  bool _loading = true;
  String? _error;
  String? _pulling;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  String? get _host {
    final laptop = _laptop;
    if (laptop == null) return null;
    return ref.notifier(doorstepPairingProvider).reachableIpOf(laptop);
  }

  Future<void> _init() async {
    _paired = ref.read(doorstepPairingProvider);
    if (_paired.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'No paired devices. Pair your laptop first on the Doorstep tab.';
      });
      return;
    }

    var laptop = widget.laptop ?? _paired.reduce((a, b) => a.lastSeen.isAfter(b.lastSeen) ? a : b);
    if (!_paired.any((d) => d.id == laptop.id)) {
      laptop = _paired.first;
    }

    final token = await ref.notifier(doorstepPairingProvider).getOrCreateOwnToken();
    if (!mounted) return;
    setState(() {
      _laptop = laptop;
      _token = token;
    });
    await _loadRoots();
  }

  void _switchLaptop(PairedDevice laptop) {
    if (laptop.id == _laptop?.id) return;
    _refreshTimer?.cancel();
    setState(() {
      _laptop = laptop;
      _roots = null;
      _root = null;
      _pathStack.clear();
      _entries = null;
      _error = null;
      _loading = true;
    });
    unawaited(_loadRoots());
  }

  Future<void> _loadRoots() async {
    final laptopId = _laptop?.id;
    final host = _host;
    final token = _token;
    if (host == null || token == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not determine the laptop\u2019s address. Make sure it is on the same Wi-Fi and try again.';
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final roots = await DoorstepBrowseApi.fetchRoots(host, doorstepBrowsePort(_laptop!.port), token);
      if (!mounted || laptopId != _laptop?.id) return;
      setState(() {
        _roots = roots;
        _root = null;
        _pathStack.clear();
        _entries = null;
        _loading = false;
      });
      if (roots.isEmpty) {
        setState(() => _error = 'This laptop has no active drop zones yet.');
      }
    } catch (e) {
      if (!mounted || laptopId != _laptop?.id) return;
      setState(() {
        _loading = false;
        _error = 'Could not reach "${_laptop!.alias}". Make sure the Doorstep app is running on your laptop and you are on the same Wi-Fi.';
      });
    }
  }

  Future<void> _loadListing({bool silent = false}) async {
    final laptopId = _laptop?.id;
    final host = _host;
    final token = _token;
    final root = _root;
    if (host == null || token == null || root == null) {
      if (!silent && mounted) {
        setState(() {
          _loading = false;
          _error = 'Lost connection to the laptop.';
        });
      }
      return;
    }
    final requestRootId = root.id;
    final requestPath = _pathStack.join('/');
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final entries = await DoorstepBrowseApi.fetchListing(
        host,
        doorstepBrowsePort(_laptop!.port),
        token,
        root: requestRootId,
        path: requestPath,
      );
      if (!mounted || laptopId != _laptop?.id || requestRootId != _root?.id || requestPath != _pathStack.join('/')) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || laptopId != _laptop?.id || requestRootId != _root?.id || requestPath != _pathStack.join('/')) return;
      if (silent) return;
      setState(() {
        _loading = false;
        _error = 'Lost connection to "${_laptop!.alias}".';
      });
    }
  }

  Future<void> _openFolder(DoorstepBrowseEntry folder) async {
    setState(() {
      _pathStack.add(folder.name);
      _entries = null;
    });
    _restartRefreshTimer();
    await _loadListing();
  }

  void _goUp() {
    if (_pathStack.isEmpty) {
      setState(() {
        _root = null;
        _entries = null;
      });
      _restartRefreshTimer();
      unawaited(_loadRoots());
      return;
    }
    setState(() => _pathStack.removeLast());
    unawaited(_loadListing());
  }

  void _restartRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (mounted && _root != null && !_loading) {
        unawaited(_loadListing(silent: true));
      }
    });
  }

  Future<void> _requestPull(DoorstepBrowseEntry entry) async {
    final host = _host;
    final token = _token;
    final root = _root;
    if (host == null || token == null || root == null) return;
    setState(() => _pulling = entry.name);
    try {
      await DoorstepBrowseApi.requestPull(
        host,
        doorstepBrowsePort(_laptop!.port),
        token,
        root: root.id,
        path: [..._pathStack, entry.name].join('/'),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Requested "${entry.name}" — it is on its way.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not request that file. Is the laptop reachable?')),
      );
    } finally {
      if (mounted) setState(() => _pulling = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_laptop == null ? 'Browse Laptop' : 'Browse ${_laptop!.alias}'),
        actions: [
          if (_laptop != null)
            PopupMenuButton<PairedDevice>(
              tooltip: 'Switch laptop',
              icon: const Icon(Icons.swap_horiz_rounded),
              onSelected: _switchLaptop,
              itemBuilder: (_) => _paired
                  .map(
                    (d) => PopupMenuItem(
                      value: d,
                      child: Text(d.alias, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                    ),
                  )
                  .toList(),
            ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              _refreshTimer?.cancel();
              if (_root == null) {
                unawaited(_loadRoots());
              } else {
                unawaited(_loadListing());
              }
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading ? const Center(child: CircularProgressIndicator()) : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: DoorstepTheme.textMuted),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: DoorstepTheme.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() => _error = null);
                  if (_root == null) {
                    unawaited(_loadRoots());
                  } else {
                    unawaited(_loadListing());
                  }
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_root == null) {
      // ── Roots (watched folders) ──────────────────────────────────────────
      final roots = _roots ?? const <DoorstepBrowseRoot>[];
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: roots.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final root = roots[index];
          return _BrowseRow(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: DoorstepTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.folder_special_rounded, color: DoorstepTheme.primary, size: 22),
            ),
            title: root.name,
            subtitle: 'Drop zone',
            trailing: const Icon(Icons.chevron_right_rounded, color: DoorstepTheme.textMuted),
            onTap: () {
              setState(() {
                _root = root;
                _entries = null;
              });
              _restartRefreshTimer();
              unawaited(_loadListing());
            },
          );
        },
      );
    }

    // ── Directory listing ──────────────────────────────────────────────────
    final entries = _entries ?? const <DoorstepBrowseEntry>[];
    final breadcrumb = _pathStack.isEmpty ? _root!.name : '${_root!.name} / ${_pathStack.join(' / ')}';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Up',
                onPressed: _goUp,
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
              Expanded(
                child: Text(
                  breadcrumb,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: DoorstepTheme.textMuted, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: entries.isEmpty
              ? const Center(
                  child: Text('This folder is empty.', style: TextStyle(color: DoorstepTheme.textMuted)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final iconColor = entry.isDir ? DoorstepTheme.primary : DoorstepTheme.textMuted;

                    return _BrowseRow(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_iconFor(entry), color: iconColor, size: 22),
                      ),
                      title: entry.name,
                      subtitle: entry.isDir ? 'Folder' : entry.size.asReadableFileSize,
                      trailing: entry.isDir
                          ? const Icon(Icons.chevron_right_rounded, color: DoorstepTheme.textMuted)
                          : _pulling == entry.name
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: DoorstepTheme.primary),
                            )
                          : const Icon(Icons.download_rounded, color: DoorstepTheme.success, size: 20),
                      onTap: entry.isDir ? () => _openFolder(entry) : () => _requestPull(entry),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ── Row widget ─────────────────────────────────────────────────────────────

class _BrowseRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _BrowseRow({required this.leading, required this.title, required this.subtitle, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return DoorstepCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      backgroundColor: DoorstepTheme.surface.withValues(alpha: 0.5),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: DoorstepTheme.textMain,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: DoorstepTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────

IconData _iconFor(DoorstepBrowseEntry entry) {
  if (entry.isDir) return Icons.folder_rounded;
  final ext = entry.name.contains('.') ? entry.name.split('.').last.toLowerCase() : '';
  if (const ['png', 'jpg', 'jpeg', 'gif', 'webp', 'heic', 'bmp', 'svg'].contains(ext)) {
    return Icons.image_rounded;
  }
  if (const ['mp4', 'mkv', 'mov', 'avi', 'webm'].contains(ext)) return Icons.movie_rounded;
  if (const ['mp3', 'wav', 'flac', 'ogg', 'm4a'].contains(ext)) return Icons.music_note_rounded;
  if (const ['pdf'].contains(ext)) return Icons.picture_as_pdf_rounded;
  if (const ['zip', 'rar', '7z', 'tar', 'gz'].contains(ext)) return Icons.archive_rounded;
  if (const ['txt', 'md', 'log', 'json', 'csv'].contains(ext)) return Icons.description_rounded;
  return Icons.insert_drive_file_rounded;
}
