import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:localsend_app/model/persistence/watched_folder.dart';
import 'package:localsend_app/provider/doorstep_pairing_provider.dart';
import 'package:localsend_app/provider/doorstep_transfer_provider.dart';
import 'package:localsend_app/provider/persistence_provider.dart';
import 'package:localsend_app/util/native/cross_file_converters.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _logger = Logger('DoorstepWatcher');

/// How long to wait between size samples when checking whether a freshly
/// created file is still being written.
const _fileSettleDelay = Duration(milliseconds: 500);

/// How many settle rounds to wait for a file's size to stop growing before
/// giving up and sending it anyway. Bounds the worst-case wait (~10s) so a
/// genuinely huge copy still makes it across instead of being dropped.
const _maxStabilityAttempts = 20;

final doorstepWatcherProvider = NotifierProvider<DoorstepWatcherNotifier, List<WatchedFolder>>((ref) {
  return DoorstepWatcherNotifier();
});

class DoorstepWatcherNotifier extends Notifier<List<WatchedFolder>> {
  final Map<String, StreamSubscription> _subscriptions = {};

  @override
  List<WatchedFolder> init() {
    // init() must return synchronously; kick async work into a microtask
    Future.microtask(_initDefaultFolder); // ignore: discarded_futures
    return [];
  }

  Future<void> _initDefaultFolder() async {
    final persistence = ref.read(persistenceProvider);
    final rawList = persistence.getWatchedFoldersRaw();
    List<WatchedFolder> folders = [];

    if (rawList.isEmpty) {
      // Drop zones are a laptop concept — only auto-create the default folder on desktop.
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        try {
          final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
          Directory? desktopDir;
          if (home != null) {
            desktopDir = Directory(p.join(home, 'Desktop'));
          }
          desktopDir ??= await getApplicationDocumentsDirectory();

          final defaultDoorstepDir = Directory(p.join(desktopDir.path, 'Doorstep'));
          if (!defaultDoorstepDir.existsSync()) {
            defaultDoorstepDir.createSync(recursive: true);
          }

          final defaultFolder = WatchedFolder(
            id: 'default_doorstep',
            name: 'Doorstep Drop Zone',
            path: defaultDoorstepDir.path,
            autoTransfer: true,
            enabled: true,
            createdAt: DateTime.now(),
          );

          folders = [defaultFolder];
          await _saveFolders(folders);
        } catch (e) {
          _logger.warning('Failed to auto-create default Doorstep folder: $e');
        }
      }
    } else {
      folders = rawList.map((e) => WatchedFolder.fromJson(jsonDecode(e) as Map<String, dynamic>)).toList();
    }

    state = folders;
    _startWatchingAll();
  }

  Future<void> _saveFolders(List<WatchedFolder> folders) async {
    final persistence = ref.read(persistenceProvider);
    final rawList = folders.map((f) => jsonEncode(f.toJson())).toList();
    await persistence.setWatchedFoldersRaw(rawList);
  }

  void _startWatchingAll() {
    for (final folder in state) {
      if (folder.enabled) {
        _watchFolder(folder);
      }
    }
  }

  void _watchFolder(WatchedFolder folder) {
    unawaited(_subscriptions[folder.id]?.cancel() ?? Future.value());
    final dir = Directory(folder.path);
    if (!dir.existsSync()) return;

    try {
      final sub = dir.watch(events: FileSystemEvent.create | FileSystemEvent.modify).listen((event) {
        if (event.type == FileSystemEvent.create && folder.autoTransfer) {
          unawaited(_handleNewFile(folder, event.path));
        }
      });
      _subscriptions[folder.id] = sub;
    } catch (e) {
      _logger.warning('Failed to watch directory ${folder.path}: $e');
    }
  }

  /// A new file appeared in [folder] — push it to every eligible paired device.
  Future<void> _handleNewFile(WatchedFolder folder, String path) async {
    try {
      if (FileSystemEntity.isDirectorySync(path)) return;

      final file = File(path);
      // A `create` event fires the moment a copy starts, but the bytes keep
      // arriving for a while — sending a half-written file would corrupt it
      // (the spec says: never corrupt a file). Wait until the size stops
      // growing, with a bounded number of attempts so a very large copy that
      // keeps growing still gets sent once the cap is reached.
      var stable = false;
      for (var attempt = 0; attempt < _maxStabilityAttempts; attempt++) {
        if (!file.existsSync()) return;
        final size = file.lengthSync();
        await Future.delayed(_fileSettleDelay);
        if (!file.existsSync()) return;
        if (file.lengthSync() == size) {
          stable = true;
          break;
        }
      }
      if (!stable) {
        _logger.warning('File kept growing for ${_maxStabilityAttempts * _fileSettleDelay.inMilliseconds}ms, sending anyway: $path');
      }
      if (!file.existsSync() || file.lengthSync() == 0) return;

      final crossFile = await CrossFileConverters.convertFile(file);
      final devices = ref.read(doorstepPairingProvider).where((d) {
        final folderAllowed = d.allowedFolderIds.isEmpty || d.allowedFolderIds.contains(folder.id);
        return d.autoTransfer && folderAllowed;
      }).toList();

      if (devices.isEmpty) {
        _logger.info('No paired devices for auto-transfer of ${file.path}');
        return;
      }

      _logger.info('Auto-transferring ${file.path} to ${devices.map((d) => d.alias).join(', ')}');
      for (final device in devices) {
        unawaited(
          ref
              .notifier(doorstepTransferProvider)
              .startTrackedTransfer(
                crossFile: crossFile,
                paired: device,
                sourceLabel: 'Doorstep [${folder.name}]',
              ),
        );
      }
    } catch (e, st) {
      _logger.warning('Failed to auto-transfer $path', e, st);
    }
  }

  /// Adds a folder to watch. Returns false (without changing state) if the path
  /// is not a usable local folder — e.g. an Android `content://` SAF URI, which
  /// cannot be watched with `Directory.watch`.
  Future<bool> addFolder(String path, {String? name}) async {
    if (path.startsWith('content://')) return false;
    final dir = Directory(path);
    if (!dir.existsSync()) return false;

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final folder = WatchedFolder(
      id: id,
      name: name ?? p.basename(path),
      path: path,
      autoTransfer: true,
      enabled: true,
      createdAt: DateTime.now(),
    );

    final updated = [...state, folder];
    state = updated;
    await _saveFolders(updated);
    _watchFolder(folder);
    return true;
  }

  Future<void> toggleAutoTransfer(String id) async {
    final updated = state.map((f) {
      if (f.id == id) {
        return f.copyWith(autoTransfer: !f.autoTransfer);
      }
      return f;
    }).toList();

    state = updated;
    await _saveFolders(updated);
  }

  Future<void> removeFolder(String id) async {
    unawaited(_subscriptions[id]?.cancel() ?? Future.value());
    _subscriptions.remove(id);
    final updated = state.where((f) => f.id != id).toList();
    state = updated;
    await _saveFolders(updated);
  }
}
