import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

final _logger = Logger('ContextMenuHelper');

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
      return await File(_getWindowsFilePath(_windowsFileName)).exists();
    default:
      return false;
  }
}

/// Repairs the "Send to Doorstep" shortcut if it is stale.
///
/// Windows' SendTo shortcut stores the absolute path of the exe at the time it
/// was created. If the app is later moved (e.g. the folder was re-extracted
/// from a zip), Windows reports "doorstep.exe is not available". Running
/// this on every desktop start re-creates the shortcut pointing at the *current*
/// exe whenever the stored target no longer exists.
Future<void> refreshContextMenu() async {
  if (defaultTargetPlatform != TargetPlatform.windows) {
    return;
  }
  try {
    final shortcutFile = File(_getWindowsFilePath(_windowsFileName));
    if (!await shortcutFile.exists()) {
      return; // Not enabled — nothing to repair.
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
    if (storedTarget != null && storedTarget.isNotEmpty && storedTarget.toLowerCase() == currentExe.toLowerCase()) {
      return; // Shortcut already points at this exe.
    }

    _logger.info('SendTo shortcut is stale ($storedTarget), re-creating for $currentExe');
    await enableContextMenu();
  } catch (e) {
    _logger.warning('Failed to refresh context menu: $e');
  }
}

const _windowsFileName = 'Doorstep';

String _getWindowsFilePath(String appName) {
  final appData = Platform.environment['APPDATA'];
  return '$appData/Microsoft/Windows/SendTo/$appName.lnk';
}
