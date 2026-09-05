import 'package:doorstep_app/config/doorstep_theme.dart';
import 'package:doorstep_app/model/cross_file.dart';
import 'package:doorstep_app/model/persistence/paired_device.dart';
import 'package:doorstep_app/provider/doorstep_pairing_provider.dart';
import 'package:doorstep_app/provider/doorstep_quick_send_provider.dart';
import 'package:doorstep_app/provider/network/nearby_devices_provider.dart';
import 'package:doorstep_app/widget/doorstep_card.dart';
import 'package:doorstep_app/widget/doorstep_logo.dart';
import 'package:flutter/material.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// Popup shown when files arrive from outside the app (Windows right-click
/// "Send with Doorstep", the phone share sheet, app-start arguments):
/// a brief "looking for trusted devices" spinner, then either a device picker
/// or a fallback hint. Exactly-one-device auto-send is handled by
/// [DoorstepQuickSendNotifier] and surfaced by the transfer overlay.
class DoorstepQuickSendOverlay extends StatefulWidget {
  const DoorstepQuickSendOverlay({super.key});

  @override
  State<DoorstepQuickSendOverlay> createState() => _DoorstepQuickSendOverlayState();
}

class _DoorstepQuickSendOverlayState extends State<DoorstepQuickSendOverlay> with Refena {
  @override
  Widget build(BuildContext context) {
    final request = ref.watch(doorstepQuickSendProvider);
    if (request == null) {
      return const SizedBox.shrink();
    }

    // Rebuild when discovery or the paired list changes so the picker stays
    // live — a device that drops off the network disappears, a new one appears.
    final nearby = ref.watch(nearbyDevicesProvider);
    final paired = ref.watch(doorstepPairingProvider);
    final online = paired.where((d) => isPairedDeviceOnline(d, nearby)).toList();

    return Material(
      type: MaterialType.transparency,
      child: Container(
        color: DoorstepTheme.backgroundOf(context).withValues(alpha: 0.55),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: _QuickSendCard(request: request, online: online),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickSendCard extends StatelessWidget {
  final DoorstepQuickSendRequest request;
  final List<PairedDevice> online;

  const _QuickSendCard({required this.request, required this.online});

  @override
  Widget build(BuildContext context) {
    final files = request.files;
    final summary = files.length == 1 ? '1 file' : '${files.length} files';
    final ref = context.ref;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: DoorstepCard(
        borderColor: DoorstepTheme.borderOf(context),
        backgroundColor: DoorstepTheme.surfaceOf(context),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const DoorstepLogo(withText: false, size: 36),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.searching ? 'Looking for trusted devices…' : 'Send $summary to…',
                        style: TextStyle(
                          color: DoorstepTheme.textMainOf(context),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Doorstep Network · Direct Peer Link',
                        style: TextStyle(
                          color: DoorstepTheme.primaryOf(context),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (request.searching)
              _SearchingBody(
                files: files,
                onCancel: () => ref.notifier(doorstepQuickSendProvider).dismiss(),
              )
            else if (online.isEmpty)
              _NoDevicesBody(
                files: files,
                onDismiss: () => ref.notifier(doorstepQuickSendProvider).dismiss(),
              )
            else
              _DeviceList(
                online: online,
                onSend: (device) => ref.notifier(doorstepQuickSendProvider).sendTo(device),
                onCancel: () => ref.notifier(doorstepQuickSendProvider).dismiss(),
              ),
          ],
        ),
      ),
    );
  }
}

class _SearchingBody extends StatelessWidget {
  final List<CrossFile> files;
  final VoidCallback onCancel;

  const _SearchingBody({required this.files, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Listening for your trusted devices on the Doorstep Network…',
                style: TextStyle(color: DoorstepTheme.textMutedOf(context), fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          files.length == 1
              ? '1 file ready to send. If exactly one trusted device is online, it is sent automatically.'
              : '${files.length} files ready to send. If exactly one trusted device is online, it is sent automatically.',
          style: TextStyle(color: DoorstepTheme.textMutedOf(context), fontSize: 12.5, height: 1.4),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onCancel,
            child: const Text('Cancel'),
          ),
        ),
      ],
    );
  }
}

class _DeviceList extends StatelessWidget {
  final List<PairedDevice> online;
  final void Function(PairedDevice) onSend;
  final VoidCallback onCancel;

  const _DeviceList({required this.online, required this.onSend, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final ref = context.ref;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose a trusted device to send to:',
          style: TextStyle(color: DoorstepTheme.textMutedOf(context), fontSize: 13),
        ),
        const SizedBox(height: 12),
        ...online.map(
          (device) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DoorstepCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              onTap: () => onSend(device),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: DoorstepTheme.primaryOf(context).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.devices_rounded,
                      color: DoorstepTheme.primaryOf(context),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.alias,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: DoorstepTheme.textMainOf(context),
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${ref.notifier(doorstepPairingProvider).reachableIpOf(device) ?? device.lastKnownIp}:${device.port}  ·  Online',
                          style: TextStyle(color: DoorstepTheme.textMutedOf(context), fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.send_rounded,
                    color: DoorstepTheme.primaryOf(context),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onCancel,
            child: const Text('Cancel'),
          ),
        ),
      ],
    );
  }
}

class _NoDevicesBody extends StatelessWidget {
  final List<CrossFile> files;
  final VoidCallback onDismiss;

  const _NoDevicesBody({required this.files, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'No trusted devices are online right now.',
          style: TextStyle(color: DoorstepTheme.textMainOf(context), fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          files.length == 1
              ? 'Your file is ready in the Send tab — open Doorstep to pick a device, or pair one first.'
              : 'Your ${files.length} files are ready in the Send tab — open Doorstep to pick a device, or pair one first.',
          style: TextStyle(color: DoorstepTheme.textMutedOf(context), fontSize: 12.5, height: 1.4),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onDismiss,
            child: const Text('Open Doorstep'),
          ),
        ),
      ],
    );
  }
}
