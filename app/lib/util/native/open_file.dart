import 'package:doorstep_app/util/native/channel/android_channel.dart' as android_channel;
import 'package:doorstep_app/util/native/platform_check.dart';
import 'package:doorstep_app/widget/dialogs/cannot_open_file_dialog.dart';
import 'package:flutter/material.dart';
import 'package:localsend_isolates/model/file_type.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';

/// Opens the selected file which is stored on the device.
Future<void> openFile(
  BuildContext context,
  FileType fileType,
  String filePath, {
  void Function()? onDeleteTap,
}) async {
  if ((fileType == FileType.apk || filePath.toLowerCase().endsWith('.apk')) && checkPlatform([TargetPlatform.android])) {
    await Permission.requestInstallPackages.request();
  }

  if (filePath.startsWith('content://')) {
    try {
      await android_channel.openContentUri(uri: filePath);
      return;
    } catch (_) {}
  }

  try {
    final fileOpenResult = await OpenFilex.open(filePath);
    if (fileOpenResult.type == ResultType.done) {
      return;
    }
  } catch (_) {}

  // On Android, try platform channel fallback
  if (checkPlatform([TargetPlatform.android])) {
    try {
      await android_channel.openContentUri(uri: filePath);
      return;
    } catch (_) {}
  }

  if (context.mounted) {
    await CannotOpenFileDialog.open(context, filePath, onDeleteTap);
  }
}
