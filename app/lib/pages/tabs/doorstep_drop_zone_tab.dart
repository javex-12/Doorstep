import 'dart:async';

import 'package:doorstep_app/config/doorstep_theme.dart';
import 'package:doorstep_app/model/persistence/paired_device.dart';
import 'package:doorstep_app/model/persistence/watched_folder.dart';
import 'package:doorstep_app/pages/doorstep_browse_page.dart';
import 'package:doorstep_app/pages/doorstep_pair_scan_page.dart';
import 'package:doorstep_app/provider/device_info_provider.dart';
import 'package:doorstep_app/provider/doorstep_pairing_provider.dart';
import 'package:doorstep_app/provider/doorstep_settings_provider.dart';
import 'package:doorstep_app/provider/doorstep_watcher_provider.dart';
import 'package:doorstep_app/provider/network/send_provider.dart';
import 'package:doorstep_app/provider/selection/selected_sending_files_provider.dart';
import 'package:doorstep_app/util/doorstep_pairing_helper.dart';
import 'package:doorstep_app/util/native/file_picker.dart';
import 'package:doorstep_app/util/native/pick_directory_path.dart';
import 'package:doorstep_app/widget/doorstep_card.dart';
import 'package:doorstep_app/widget/doorstep_header.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:localsend_isolates/model/device.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:refena_flutter/refena_flutter.dart';

class DoorstepDropZoneTab extends StatefulWidget {
  const DoorstepDropZoneTab({super.key});

  @override
  State<DoorstepDropZoneTab> createState() => _DoorstepDropZoneTabState();
}

class _DoorstepDropZoneTabState extends State<DoorstepDropZoneTab> with Refena {
  static bool get _isMobile => defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    if (_isMobile) {
      // Announce this phone to every known laptop so its IP and last-seen stay
      // fresh (handles DHCP drift and app restarts without re-scanning).
      Future.microtask(() => ref.notifier(doorstepPairingProvider).reconnectToPairedDevices()); // ignore: discarded_futures
    }
  }

  @override
  Widget build(BuildContext context) {
    final watchedFolders = context.watch(doorstepWatcherProvider);
    final pairedDevices = context.watch(doorstepPairingProvider);
    final settings = context.watch(doorstepSettingsProvider);
    final deviceInfo = context.watch(deviceFullInfoProvider);

    return Scaffold(
      backgroundColor: DoorstepTheme.backgroundOf(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DoorstepHeader(
                title: 'Doorstep',
                subtitle: _isMobile ? 'Pair with your laptop and receive files automatically.' : 'Your phone is now another folder on your computer.',
              ),
              const SizedBox(height: 24),

              // ── Hero Quick Settings Dashboard ─────────────────────────────
              _buildHeroDashboard(context, settings, deviceInfo),
              const SizedBox(height: 28),

              // ── Paired Devices ──────────────────────────────────────────
              const _SectionLabel(label: 'PAIRED DEVICES'),
              const SizedBox(height: 12),
              if (pairedDevices.isEmpty)
                const DoorstepCard(
                  child: Row(
                    children: [
                      Icon(Icons.devices, color: DoorstepTheme.textMuted, size: 28),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'No devices paired yet. Tap "Pair Device" to get started.',
                          style: TextStyle(color: DoorstepTheme.textMuted, fontSize: 13.5),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...pairedDevices.map(
                  (d) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _DeviceCard(device: d),
                  ),
                ),

              const SizedBox(height: 28),

              // ── Drop Zones ──────────────────────────────────────────────
              const _SectionLabel(label: 'ACTIVE DROP ZONES'),
              const SizedBox(height: 12),
              if (_isMobile)
                const DoorstepCard(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                    child: Row(
                      children: [
                        Icon(Icons.dns_outlined, color: DoorstepTheme.textMuted, size: 28),
                        SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Drop zones are folders on your laptop. Open Doorstep on your computer and add a folder — files dropped there arrive here automatically.',
                            style: TextStyle(color: DoorstepTheme.textMuted, fontSize: 13.5, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (watchedFolders.isEmpty)
                const DoorstepCard(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.folder_open, size: 40, color: DoorstepTheme.textMuted),
                          SizedBox(height: 10),
                          Text(
                            'Default Doorstep folder initializing…',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: DoorstepTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ...watchedFolders.map(
                  (folder) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _FolderCard(folder: folder),
                  ),
                ),

              if (_isMobile && pairedDevices.isNotEmpty) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _openBrowse(context),
                        icon: const Icon(Icons.folder_open, size: 18),
                        label: const Text('Browse Laptop'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _sendToLaptop(context),
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: const Text('Send Files'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              if (!_isMobile) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _addDropZone(context),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Add Drop Zone'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroDashboard(BuildContext context, DoorstepSettings settings, Device deviceInfo) {
    final ip = deviceInfo.ip;
    final displayIp = ip == null || ip == '-' ? 'Disconnected' : '$ip:${deviceInfo.port}';

    return DoorstepCard(
      borderColor: DoorstepTheme.surfaceBorder,
      backgroundColor: DoorstepTheme.surface.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DoorstepTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  _isMobile ? Icons.phone_android_rounded : Icons.laptop_chromebook_rounded,
                  color: DoorstepTheme.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deviceInfo.alias,
                      style: const TextStyle(
                        color: DoorstepTheme.textMain,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayIp,
                      style: const TextStyle(
                        color: DoorstepTheme.textMuted,
                        fontSize: 12.5,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              // Dynamic Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: settings.sleepMode ? DoorstepTheme.warning.withValues(alpha: 0.15) : DoorstepTheme.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: settings.sleepMode ? DoorstepTheme.warning : DoorstepTheme.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      settings.sleepMode ? 'Sleep Mode' : 'Active',
                      style: TextStyle(
                        color: settings.sleepMode ? DoorstepTheme.warning : DoorstepTheme.success,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 18),

          // Material You Quick Setting Tiles Grid
          Row(
            children: [
              // Tile 1: Sleep Mode Toggle Widget
              Expanded(
                child: InkWell(
                  onTap: () {
                    // ignore: discarded_futures
                    ref.notifier(doorstepSettingsProvider).setSleepMode(!settings.sleepMode);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: settings.sleepMode ? DoorstepTheme.warning.withValues(alpha: 0.15) : DoorstepTheme.surfaceBorder.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: settings.sleepMode ? DoorstepTheme.warning.withValues(alpha: 0.25) : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          settings.sleepMode ? Icons.bedtime_rounded : Icons.bedtime_outlined,
                          color: settings.sleepMode ? DoorstepTheme.warning : DoorstepTheme.textMuted,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sleep Mode',
                                style: TextStyle(
                                  color: settings.sleepMode ? DoorstepTheme.warning : DoorstepTheme.textMain,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                settings.sleepMode ? 'Quiet' : 'Auto-Accept',
                                style: const TextStyle(
                                  color: DoorstepTheme.textMuted,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Tile 2: Pair Device / Scanner Action
              Expanded(
                child: InkWell(
                  onTap: () => _showPairingModal(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: DoorstepTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: DoorstepTheme.primary.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.qr_code_scanner_rounded,
                          color: DoorstepTheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Pair Device',
                                style: TextStyle(
                                  color: DoorstepTheme.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isMobile ? 'Scan QR' : 'Show QR',
                                style: TextStyle(
                                  color: DoorstepTheme.primary.withValues(alpha: 0.7),
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _addDropZone(BuildContext context) async {
    final path = await pickDirectoryPath();
    if (path == null) return;
    final added = await ref.notifier(doorstepWatcherProvider).addFolder(path);
    if (!added && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not add that folder as a drop zone.')),
      );
    }
  }

  Future<void> _openBrowse(BuildContext context) async {
    final paired = ref.read(doorstepPairingProvider);
    if (paired.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pair a laptop first — tap "Pair Device" and scan its QR code.')),
      );
      return;
    }
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const DoorstepBrowsePage()),
      ),
    );
  }

  Future<void> _sendToLaptop(BuildContext context) async {
    final paired = ref.read(doorstepPairingProvider);
    if (paired.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pair a laptop first — tap "Pair Device" and scan its QR code.')),
      );
      return;
    }

    await ref.global.dispatchAsync(
      PickFileAction(option: FilePickerOption.file, context: context),
    );
    if (!context.mounted) return;

    final files = ref.read(selectedSendingFilesProvider);
    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No files selected.')),
      );
      return;
    }

    final laptop = paired.reduce((a, b) => a.lastSeen.isAfter(b.lastSeen) ? a : b);
    final target = ref.notifier(doorstepPairingProvider).resolveTarget(laptop);
    if (target.ip == null || target.ip == '0.0.0.0' || target.ip == '-') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The laptop is not reachable right now. Make sure it is on and on the same Wi-Fi.')),
      );
      return;
    }

    await ref
        .notifier(sendProvider)
        .startSession(
          target: target,
          files: files,
          background: false,
        );
  }

  Future<void> _showPairingModal(BuildContext context) async {
    if (_isMobile) {
      unawaited(Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DoorstepPairScanPage())));
      return;
    }

    final deviceInfo = ref.read(deviceFullInfoProvider);
    final ip = deviceInfo.ip;

    final ownToken = await ref.notifier(doorstepPairingProvider).getOrCreateOwnToken();
    if (!context.mounted) return;

    ref.notifier(doorstepPairingProvider).beginPairing(ownToken);

    final payload = DoorstepPairingPayload(
      deviceId: deviceInfo.fingerprint,
      alias: deviceInfo.alias,
      ip: ip == null || ip == '-' ? '0.0.0.0' : ip,
      port: deviceInfo.port,
      fingerprint: deviceInfo.fingerprint,
      token: ownToken,
      timestamp: DateTime.now(),
    );

    unawaited(
      showModalBottomSheet(
        context: context,
        backgroundColor: DoorstepTheme.surface,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (context) => _PairingModal(payload: payload),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: DoorstepTheme.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
      ),
    );
  }
}

// ── Device card ──────────────────────────────────────────────────────────────

class _DeviceCard extends StatefulWidget {
  final PairedDevice device;
  const _DeviceCard({required this.device});

  @override
  State<_DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends State<_DeviceCard> with SingleTickerProviderStateMixin, Refena {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    unawaited(_pulse.repeat(reverse: true));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sinceLastSeen = DateTime.now().difference(widget.device.lastSeen);
    final isOnline = sinceLastSeen.inMinutes < 5;

    return DoorstepCard(
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) => Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOnline ? DoorstepTheme.success : DoorstepTheme.textMuted,
                boxShadow: isOnline
                    ? [
                        BoxShadow(
                          color: Color.lerp(
                            const Color(0x0086EFAC),
                            const Color(0x9986EFAC),
                            _pulse.value,
                          )!,
                          blurRadius: 10,
                          spreadRadius: 3,
                        ),
                      ]
                    : [],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.device.alias,
                  style: const TextStyle(color: DoorstepTheme.textMain, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.device.lastKnownIp}:${widget.device.port}  ·  '
                  '${isOnline ? 'Online' : 'Last seen ${_formatAge(sinceLastSeen)}'}  ·  '
                  '${widget.device.trustLevel == DeviceTrustLevel.temporary ? 'Temporary' : 'Trusted'}',
                  style: const TextStyle(color: DoorstepTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.link_off_rounded, color: DoorstepTheme.textMuted, size: 22),
            tooltip: 'Revoke pairing',
            onPressed: () => _confirmRevoke(context),
          ),
        ],
      ),
    );
  }

  void _confirmRevoke(BuildContext context) {
    final isTemporary = widget.device.trustLevel == DeviceTrustLevel.temporary;
    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: DoorstepTheme.surface,
          title: Text(
            isTemporary ? 'Forget this device?' : 'Revoke ${widget.device.alias}?',
            style: const TextStyle(color: DoorstepTheme.textMain, fontWeight: FontWeight.bold),
          ),
          content: Text(
            isTemporary
                ? 'This temporary connection will be closed. The device will need to scan your QR code again to reconnect.'
                : '"${widget.device.alias}" will no longer be trusted. It will stop receiving files automatically and must scan your QR code again to reconnect.',
            style: const TextStyle(color: DoorstepTheme.textMuted, fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: DoorstepTheme.textMuted)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                // ignore: discarded_futures
                ref.notifier(doorstepPairingProvider).revokeDevice(widget.device.id);
              },
              child: Text(
                isTemporary ? 'Forget' : 'Revoke',
                style: const TextStyle(color: DoorstepTheme.danger, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatAge(Duration d) {
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}

// ── Folder card ──────────────────────────────────────────────────────────────

class _FolderCard extends StatelessWidget {
  final WatchedFolder folder;
  const _FolderCard({required this.folder});

  @override
  Widget build(BuildContext context) {
    return DoorstepCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: DoorstepTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.folder_special_rounded, color: DoorstepTheme.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  folder.name,
                  style: const TextStyle(color: DoorstepTheme.textMain, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  folder.path,
                  style: const TextStyle(color: DoorstepTheme.textMuted, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _pickTargetDevices(context, folder),
                  borderRadius: BorderRadius.circular(100),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: DoorstepTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: DoorstepTheme.primary.withValues(alpha: 0.25), width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.send_to_mobile_rounded, size: 13, color: DoorstepTheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          _targetDevicesLabel(context, folder),
                          style: const TextStyle(
                            color: DoorstepTheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                folder.autoTransfer ? 'Auto' : 'Manual',
                style: TextStyle(
                  color: folder.autoTransfer ? DoorstepTheme.success : DoorstepTheme.warning,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Switch(
                value: folder.autoTransfer,
                activeTrackColor: DoorstepTheme.success.withValues(alpha: 0.4),
                activeThumbColor: DoorstepTheme.success,
                onChanged: (_) {
                  // ignore: discarded_futures
                  context.ref.notifier(doorstepWatcherProvider).toggleAutoTransfer(folder.id);
                },
              ),
            ],
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: DoorstepTheme.danger, size: 22),
            tooltip: 'Remove drop zone',
            onPressed: () {
              _confirmRemove(context, folder);
            },
          ),
        ],
      ),
    );
  }

  String _targetDevicesLabel(BuildContext context, WatchedFolder folder) {
    final paired = context.ref.read(doorstepPairingProvider);
    if (folder.targetDeviceIds.isEmpty) return 'All devices';
    final count = folder.targetDeviceIds.where((id) => paired.any((d) => d.id == id)).length;
    return count == 0
        ? 'No devices'
        : count == 1
        ? '1 device'
        : '$count devices';
  }

  /// "Send to" selector: route this drop zone to specific paired devices.
  Future<void> _pickTargetDevices(BuildContext context, WatchedFolder folder) async {
    final paired = context.ref.read(doorstepPairingProvider);
    final allSelected = folder.targetDeviceIds.isEmpty;
    final selected = <String>{...folder.targetDeviceIds};

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            backgroundColor: DoorstepTheme.surface,
            title: const Text(
              'Send to…',
              style: TextStyle(color: DoorstepTheme.textMain, fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Files dropped into "${folder.name}" go to the devices you pick here.',
                    style: const TextStyle(color: DoorstepTheme.textMuted, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  // All devices
                  CheckboxListTile(
                    value: allSelected,
                    activeColor: DoorstepTheme.primary,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          selected.clear();
                        }
                      });
                      if (value == true) Navigator.of(ctx).pop(true); // all mode
                    },
                    title: const Text(
                      'All paired devices',
                      style: TextStyle(color: DoorstepTheme.textMain, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Every trusted device gets files from this folder',
                      style: TextStyle(color: DoorstepTheme.textMuted, fontSize: 11.5),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  if (paired.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'No devices paired yet.',
                        style: TextStyle(color: DoorstepTheme.textMuted, fontSize: 12),
                      ),
                    )
                  else
                    ...paired.map(
                      (d) => CheckboxListTile(
                        value: !allSelected && selected.contains(d.id),
                        activeColor: DoorstepTheme.primary,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              selected.add(d.id);
                            } else {
                              selected.remove(d.id);
                            }
                          });
                        },
                        title: Text(
                          d.alias,
                          style: const TextStyle(color: DoorstepTheme.textMain, fontSize: 14),
                        ),
                        subtitle: Text(
                          d.trustLevel == DeviceTrustLevel.temporary ? 'Temporary session' : 'Trusted device',
                          style: const TextStyle(color: DoorstepTheme.textMuted, fontSize: 11.5),
                        ),
                        secondary: Icon(
                          d.trustLevel == DeviceTrustLevel.temporary ? Icons.timer_rounded : Icons.check_circle_rounded,
                          color: d.trustLevel == DeviceTrustLevel.temporary ? DoorstepTheme.warning : DoorstepTheme.success,
                          size: 20,
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel', style: TextStyle(color: DoorstepTheme.textMuted)),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text(
                  'Apply',
                  style: TextStyle(color: DoorstepTheme.primary, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (result == null || !context.mounted) return;
    if (result == true) {
      // All devices
      await context.ref.notifier(doorstepWatcherProvider).setFolderTargetDevices(folder.id, const []);
    } else {
      await context.ref.notifier(doorstepWatcherProvider).setFolderTargetDevices(folder.id, selected.toList());
    }
  }

  void _confirmRemove(BuildContext context, WatchedFolder folder) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: DoorstepTheme.surface,
          title: const Text(
            'Remove Drop Zone?',
            style: TextStyle(color: DoorstepTheme.textMain, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Remove "${folder.name}" from Doorstep?\n\nYour files will not be deleted.',
            style: const TextStyle(color: DoorstepTheme.textMuted, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: DoorstepTheme.textMuted)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                unawaited(context.ref.notifier(doorstepWatcherProvider).removeFolder(folder.id));
              },
              child: const Text(
                'Remove',
                style: TextStyle(color: DoorstepTheme.danger, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pairing modal ─────────────────────────────────────────────────────────────

class _PairingModal extends StatelessWidget {
  final DoorstepPairingPayload payload;
  const _PairingModal({required this.payload});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(28, 20, 28, MediaQuery.of(context).viewInsets.bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: DoorstepTheme.surfaceBorder,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Pair Your Device',
            style: TextStyle(color: DoorstepTheme.textMain, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Open the Doorstep app on your phone and scan this code.\nYour phone will ask you whether this is a personal device.',
            textAlign: TextAlign.center,
            style: TextStyle(color: DoorstepTheme.textMuted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 10),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_rounded, color: DoorstepTheme.primary, size: 15),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Both devices must be on the same Wi-Fi network (or a hotspot).',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: DoorstepTheme.primary, fontSize: 11.5, height: 1.3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: DoorstepTheme.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: DoorstepTheme.surfaceBorder),
            ),
            child: Text(
              'Alias: ${payload.alias}  ·  IP: ${payload.ip}:${payload.port}',
              style: const TextStyle(color: DoorstepTheme.primary, fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: SizedBox(
              width: 200,
              height: 200,
              child: PrettyQrView.data(
                data: payload.encode(),
                decoration: const PrettyQrDecoration(
                  shape: PrettyQrSmoothSymbol(
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: DoorstepTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: DoorstepTheme.primary.withValues(alpha: 0.2)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.security_rounded, color: DoorstepTheme.primary, size: 16),
                SizedBox(width: 8),
                Text(
                  'LAN only  ·  Secure Encryption  ·  No Cloud',
                  style: TextStyle(color: DoorstepTheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
