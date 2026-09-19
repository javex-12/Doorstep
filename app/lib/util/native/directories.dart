import 'dart:io' show Directory, Platform;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart' as path;

/// Where a received file lands when the user has not picked a destination.
///
/// Always a **Doorstep** folder inside Downloads (or Documents on iOS), never
/// the bare Downloads folder. That is deliberate: the single most common
/// question after a transfer is "where did it go?", and a folder named after
/// the app answers it before it is asked. The folder is created here so the
/// native writer always has somewhere to put the bytes.
Future<String> getDefaultDestinationDirectory() async {
  final base = await _baseDownloadDirectory();
  final doorstep = Directory(_join(base, 'Doorstep'));
  try {
    if (!doorstep.existsSync()) {
      await doorstep.create(recursive: true);
    }
  } catch (_) {
    // Fall back to the base directory when the app cannot create the folder
    // (e.g. scoped storage on Android); the transfer must still work.
    return base;
  }
  return doorstep.path;
}

Future<String> _baseDownloadDirectory() async {
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      final dir = await path.getDownloadsDirectory();
      return dir?.path ?? '/storage/emulated/0/Download';
    case TargetPlatform.iOS:
      return (await path.getApplicationDocumentsDirectory()).path;
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.fuchsia:
      var downloadDir = await path.getDownloadsDirectory();
      if (downloadDir == null) {
        final home = Platform.environment['HOMEPATH'] ?? Platform.environment['HOME'] ?? '';
        downloadDir = Directory(_join(home, 'Downloads'));
        if (!downloadDir.existsSync()) {
          downloadDir = Directory(home);
        }
      }
      return downloadDir.path.replaceAll('\\', '/');
  }
}

String _join(String a, String b) {
  if (a.isEmpty) return b;
  final separator = a.contains('\\') ? '\\' : '/';
  return a.endsWith(separator) ? '$a$b' : '$a$separator$b';
}

Future<String> getCacheDirectory() async {
  return (await path.getTemporaryDirectory()).path;
}
