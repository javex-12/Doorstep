import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

final _logger = Logger('ContextMenuHelper');

/// Label of the direct Explorer context-menu item.
const _shellVerbName = 'Send with Doorstep';

/// HKCU registry paths of the direct "Send with Doorstep" verb. HKCU needs no
/// admin rights, so this works in a portable install too. The `*` key covers
/// every file type; the `Directory` key covers folders.
const _shellVerbKeys = [
  r'Software\Classes\*\shell\DoorstepSend',
  r'Software\Classes\Directory\shell\DoorstepSend',
];

Future<bool> enableContextMenu() async {
  if (defaultTargetPlatform != TargetPlatform.windows) {
    return false;
  }

  try {
    final String script =
        '''
\$TargetPath = "${Platform.resolvedExecutable}"
\$ShortcutFile = "${_getWindowsFilePath(_windowsFileName)}"
\$WScriptShell = New-Object -ComObject WScript.Shell
\$Shortcut = \$WScriptShell.CreateShortcut(\$ShortcutFile)
\$Shortcut.TargetPath = \$TargetPath
\$Shortcut.Save()
''';
    final result = await Process.run('powershell', ['-Command', script]);
    if (result.stderr != null && result.stderr!.isNotEmpty) {
      throw Exception('Failed to create shortcut: ${result.stderr}');
    }
    await _writeShellVerb();
    return await File(_getWindowsFilePath(_windowsFileName)).exists();
  } catch (e) {
    _logger.severe('Failed to enable context menu: $e');
    return false;
  }
}

Future<bool> disableContextMenu() async {
  try {
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        final file = File(_getWindowsFilePath(_windowsFileName));
        if (await file.exists()) {
          await file.delete();
        }
        for (final key in _shellVerbKeys) {
          await Process.run('reg', ['delete', 'HKCU\\$key', '/f']);
        }
        return true;
      default:
        return false;
    }
  } catch (e) {
    return false;
  }
}

Future<bool> isContextMenuEnabled() async {
  switch (defaultTargetPlatform) {
    case TargetPlatform.windows:
      final shortcutExists = await File(_getWindowsFilePath(_windowsFileName)).exists();
      if (shortcutExists) {
        return true;
      }
      // The shortcut may have been removed manually while the registry verb
      // is still installed.
      final reg = await Process.run('reg', ['query', 'HKCU\\${_shellVerbKeys.first}']);
      return reg.exitCode == 0;
    default:
      return false;
  }
}

/// Repairs the Windows integration if it is stale.
///
/// Windows' SendTo shortcut stores the absolute path of the exe at the time it
/// was created. If the app is later moved (e.g. the folder was re-extracted
/// from a zip), Windows reports "doorstep.exe is not available" and the
/// "Send with Doorstep" verb points at the old location. Running this on every
/// desktop start re-creates both pointing at the *current* exe.
Future<void> refreshContextMenu() async {
  if (defaultTargetPlatform != TargetPlatform.windows) {
    return;
  }
  try {
    final shortcutFile = File(_getWindowsFilePath(_windowsFileName));
    var enabled = await shortcutFile.exists();
    if (!enabled) {
      final reg = await Process.run('reg', ['query', 'HKCU\\${_shellVerbKeys.first}']);
      enabled = reg.exitCode == 0;
    }
    if (!enabled) {
      return; // Never enabled — nothing to repair.
    }

    // Read the shortcut's target. If it still resolves to this exe, leave it.
    final script =
        '''
\$ShortcutFile = "${_getWindowsFilePath(_windowsFileName)}"
\$WScriptShell = New-Object -ComObject WScript.Shell
\$Shortcut = \$WScriptShell.CreateShortcut(\$ShortcutFile)
Write-Output \$Shortcut.TargetPath
''';
    final result = await Process.run('powershell', ['-Command', script]);
    final currentExe = Platform.resolvedExecutable.replaceAll('/', '\\');
    final storedTarget = result.stdout?.toString().trim();
    final shortcutStale = storedTarget == null || storedTarget.isEmpty || storedTarget.toLowerCase() != currentExe.toLowerCase();
    if (shortcutStale) {
      _logger.info('SendTo shortcut is stale ($storedTarget), re-creating for $currentExe');
      await enableContextMenu();
    } else {
      // Shortcut is fine — still re-point the registry verb at the current
      // exe (idempotent) in case the app was moved.
      await _writeShellVerb();
    }
  } catch (e) {
    _logger.warning('Failed to refresh context menu: $e');
  }
}

/// Registers (or re-points) the direct "Send with Doorstep" Explorer verb for
/// files and folders. Idempotent.
Future<void> _writeShellVerb() async {
  final exe = Platform.resolvedExecutable;
  final command = '"$exe" "%1"';
  for (final key in _shellVerbKeys) {
    await Process.run('reg', ['add', 'HKCU\\$key', '/ve', '/d', _shellVerbName, '/f']);
    await Process.run('reg', ['add', 'HKCU\\$key', '/v', 'Icon', '/d', '"$exe,0"', '/f']);
    await Process.run('reg', ['add', 'HKCU\\$key\\command', '/ve', '/d', command, '/f']);
  }
}

const _windowsFileName = 'Doorstep';

String _getWindowsFilePath(String appName) {
  final appData = Platform.environment['APPDATA'];
  return '$appData/Microsoft/Windows/SendTo/$appName.lnk';
}
