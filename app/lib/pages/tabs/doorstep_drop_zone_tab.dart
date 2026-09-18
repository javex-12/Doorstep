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
import 'package:doorstep_app/provider/network/nearby_devices_provider.dart';
import 'package:doorstep_app/provider/network/send_provider.dart';
import 'package:doorstep_app/provider/selection/selected_sending_files_provider.dart';
import 'package:doorstep_app/util/doorstep_pairing_helper.dart';
import 'package:doorstep_app/util/native/file_picker.dart';
import 'package:doorstep_app/util/native/open_folder.dart';
import 'package:doorstep_app/util/native/pick_directory_path.dart';
import 'package:doorstep_app/util/ui/snackbar.dart';
import 'package:doorstep_app/widget/dialogs/trust_device_dialog.dart';
import 'package:doorstep_app/widget/doorstep_card.dart';
import 'package:doorstep_app/widget/doorstep_empty_state.dart';
import 'package:doorstep_app/widget/doorstep_header.dart';
import 'package:doorstep_app/widget/doorstep_list_tile.dart';
import 'package:doorstep_app/widget/doorstep_section.dart';
import 'package:doorstep_app/widget/doorstep_status_chip.dart';
import 'package:doorstep_isolates/model/device.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// Doorstep home.
///
/// Designed as a *status first* dashboard: this device's state is the hero, then
/// devices you can connect to right now, then the devices you already trust,
/// then the folders/files that move.
class DoorstepDropZoneTab extends StatefulWidget {
  const DoorstepDropZoneTab({super.key});

  @override
  State<DoorstepDropZoneTab> createState() => _DoorstepDropZoneTabState();
}

class _DoorstepDropZoneTabState extends State<DoorstepDropZoneTab> with Refena {
  static bool get _isMobile => defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

  DateTime? _lastRefresh;

  @override
  void initState() {
    super.initState();
    if (_isMobile) {
      // Announce this phone to every known laptop so its IP and last-seen stay
      // fresh (handles DHCP drift and app restarts without re-scanning).
      Future.microtask(() => ref.notifier(doorstepPairingProvider).reconnectToPairedDevices()); // ignore: discarded_futures
    }
    Future.microtask(() => ref.redux(nearbyDevicesProvider).dispatch(StartMulticastScan())); // ignore: discarded_futures
    _lastRefresh = DateTime.now();
  }

  void _refreshDiscovery() {
    ref.redux(nearbyDevicesProvider).dispatch(StartMulticastScan());
    setState(() => _lastRefresh = DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final watchedFolders = context.watch(doorstepWatcherProvider);
    final pairedDevices = context.watch(doorstepPairingProvider);
    final settings = context.watch(doorstepSettingsProvider);
    final deviceInfo = context.watch(deviceFullInfoProvider);
    final nearbyDevices = context.watch(nearbyDevicesProvider).allDevices;
    final pairedFingerprints = pairedDevices.map((d) => d.fingerprint).toSet();
    final discoveredNearby = nearbyDevices.values
        .where((d) => !pairedFingerprints.contains(d.fingerprint) && d.fingerprint != deviceInfo.fingerprint)
        .toList();

    return Scaffold(
      backgroundColor: DoorstepTheme.backgroundOf(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DoorstepHeader(
                title: 'Doorstep',
                subtitle: _isMobile ? 'Connect once, then files find you.' : 'Your phone is another folder on this computer.',
                trailing: IconButton(
                  tooltip: 'Search again',
                  onPressed: _refreshDiscovery,
                  icon: const Icon(Icons.refresh_rounded, size: 22),
                ),
              ),
              const SizedBox(height: 20),

              _StatusPanel(
                alias: deviceInfo.alias,
                ip: deviceInfo.ip,
                port: deviceInfo.port,
                pairedCount: pairedDevices.length,
                nearbyCount: discoveredNearby.length,
                dropZoneCount: watchedFolders.length,
                sleepMode: settings.sleepMode,
                onToggleSleep: _isMobile
                    ? () => ref
                          .notifier(doorstepSettingsProvider)
                          .setSleepMode(!settings.sleepMode) // ignore: discarded_futures
                    : null,
                showDropZones: !_isMobile,
              ),
              const SizedBox(height: 26),

              // ── Nearby ────────────────────────────────────────────────────
              DoorstepSection(
                title: 'Nearby on the Doorstep network',
                subtitle: discoveredNearby.isEmpty
                    ? 'Make sure both devices are on the same Wi-Fi (or the same hotspot)'
                    : '${discoveredNearby.length} ready to connect',
                action: TextButton(
                  onPressed: _refreshDiscovery,
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  child: const Text('Search'),
                ),
                children: discoveredNearby.isEmpty
                    ? [
                        DoorstepEmptyState(
                          inline: true,
                          kind: DoorstepEmptyKind.searching,
                          icon: Icons.wifi_tethering_rounded,
                          title: 'Looking for devices…',
                          message: _lastRefresh == null
                              ? 'Doorstep is listening for other Doorstep devices on this network.'
                              : 'Nothing found yet. Both devices need to be on the same Wi-Fi network, or your phone on the laptop\'s hotspot.',
                          secondaryLabel: 'Having trouble? Connect manually',
                          onSecondary: () => _showManualPairing(context),
                        ),
                      ]
                    : [
                        ...discoveredNearby.map((d) => _DiscoveredDeviceRow(device: d)),
                      ],
              ),

              // ── Your devices ──────────────────────────────────────────────
              DoorstepSection(
                title: 'Your devices',
                subtitle: pairedDevices.isEmpty ? 'Nothing connected yet' : '${pairedDevices.length} connected',
                children: pairedDevices.isEmpty
                    ? [
                        DoorstepEmptyState(
                          inline: true,
                          kind: DoorstepEmptyKind.firstUse,
                          icon: Icons.devices_rounded,
                          title: 'No devices connected',
                          message: discoveredNearby.isNotEmpty
                              ? 'Tap Connect on a device above. Doorstep will ask whether it is your own device or just for this session.'
                              : 'Devices you connect to will appear here, and stay connected.',
                        ),
                      ]
                    : pairedDevices.map((d) => _PairedDeviceRow(device: d)).toList(),
              ),

              // ── Drop zones / send ─────────────────────────────────────────
              if (_isMobile)
                DoorstepSection(
                  title: 'Move files',
                  children: [
                    DoorstepListTile(
                      icon: Icons.folder_open_rounded,
                      title: 'Browse this computer',
                      subtitle: 'Open folders on your laptop and pull files over',
                      enabled: pairedDevices.isNotEmpty,
                      trailing: const DoorstepChevron(),
                      onTap: () => _openBrowse(context),
                    ),
                    DoorstepListTile(
                      icon: Icons.send_rounded,
                      title: 'Send files from this phone',
                      subtitle: 'Pick files and send them to a connected device',
                      enabled: pairedDevices.isNotEmpty,
                      trailing: const DoorstepChevron(),
                      onTap: () => _sendToLaptop(context),
                    ),
                    if (pairedDevices.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Text(
                          'Connect a device first — then you can send and browse.',
                          style: TextStyle(fontSize: 12.5, height: 1.4),
                        ),
                      ),
                  ],
                )
              else
                DoorstepSection(
                  title: 'Drop zones',
                  subtitle: watchedFolders.isEmpty
                      ? 'Folders that send automatically'
                      : '${watchedFolders.length} folder${watchedFolders.length == 1 ? '' : 's'} watched',
                  action: TextButton.icon(
                    onPressed: () => _addDropZone(context),
                    icon: const Icon(Icons.add_rounded, size: 17),
                    label: const Text('Add'),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  ),
                  children: watchedFolders.isEmpty
                      ? [
                          DoorstepEmptyState(
                            inline: true,
                            kind: DoorstepEmptyKind.firstUse,
                            icon: Icons.folder_special_rounded,
                            title: 'No drop zone yet',
                            message:
                                'Add a folder here. Anything you drop into it is sent to your connected devices automatically — even while Doorstep sits in the tray.',
                            actionLabel: 'Choose a folder',
                            onAction: () => _addDropZone(context),
                          ),
                        ]
                      : watchedFolders.map((f) => _FolderCard(folder: f)).toList(),
                ),

              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addDropZone(BuildContext context) async {
    final path = await pickDirectoryPath();
    if (path == null) return;
    final added = await ref.notifier(doorstepWatcherProvider).addFolder(path);
    if (!added && context.mounted) {
      context.showSnackBar('Could not add that folder as a drop zone.');
    }
  }

  Future<void> _openBrowse(BuildContext context) async {
    final paired = ref.read(doorstepPairingProvider);
    if (paired.isEmpty) {
      context.showSnackBar('Connect a device first.');
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
      context.showSnackBar('Connect a device first.');
      return;
    }

    await ref.global.dispatchAsync(
      PickFileAction(option: FilePickerOption.file, context: context),
    );
    if (!context.mounted) return;

    final files = ref.read(selectedSendingFilesProvider);
    if (files.isEmpty) {
      context.showSnackBar('No files selected.');
      return;
    }

    final laptop = paired.reduce((a, b) => a.lastSeen.isAfter(b.lastSeen) ? a : b);
    final target = ref.notifier(doorstepPairingProvider).resolveTarget(laptop);
    if (target.ip == null || target.ip == '0.0.0.0' || target.ip == '-') {
      context.showSnackBar('That device is not reachable right now. Check it is on and on the same Wi-Fi.');
      return;
    }

    await ref.notifier(sendProvider).startSession(target: target, files: files, background: false);
  }

  /// Fallback for networks where UDP discovery is blocked. Reachable from the
  /// nearby empty state, never the primary path.
  Future<void> _showManualPairing(BuildContext context) async {
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
        backgroundColor: DoorstepTheme.surfaceOf(context),
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (context) => _PairingModal(payload: payload),
      ),
    );
  }
}

// ── Status panel (hero) ───────────────────────────────────────────────────────

class _StatusPanel extends StatelessWidget {
  final String alias;
  final String? ip;
  final int port;
  final int pairedCount;
  final int nearbyCount;
  final int dropZoneCount;
  final bool sleepMode;
  final VoidCallback? onToggleSleep;
  final bool showDropZones;

  const _StatusPanel({
    required this.alias,
    required this.ip,
    required this.port,
    required this.pairedCount,
    required this.nearbyCount,
    required this.dropZoneCount,
    required this.sleepMode,
    required this.onToggleSleep,
    required this.showDropZones,
  });

  @override
  Widget build(BuildContext context) {
    final connected = ip != null && ip != '-' && ip!.isNotEmpty;

    final (chipLabel, chipTone, chipIcon) = sleepMode
        ? ('Sleep mode', DoorstepStatusTone.warning, Icons.bedtime_rounded)
        : connected
        ? ('Ready to receive', DoorstepStatusTone.positive, Icons.check_circle_rounded)
        : ('Not connected to Wi-Fi', DoorstepStatusTone.negative, Icons.wifi_off_rounded);

    return DoorstepCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: DoorstepTheme.primaryOf(context).withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS
                      ? Icons.phone_android_rounded
                      : Icons.laptop_mac_rounded,
                  color: DoorstepTheme.primaryOf(context),
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alias,
                      style: TextStyle(
                        color: DoorstepTheme.textMainOf(context),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      connected ? '$ip:$port' : 'Not on a network',
                      style: TextStyle(
                        color: DoorstepTheme.textMutedOf(context),
                        fontSize: 12.5,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              DoorstepStatusChip(label: chipLabel, tone: chipTone, icon: chipIcon, pulse: connected && !sleepMode),
              const Spacer(),
              if (onToggleSleep != null)
                TextButton.icon(
                  onPressed: onToggleSleep,
                  icon: Icon(sleepMode ? Icons.bedtime_rounded : Icons.bedtime_outlined, size: 16),
                  label: Text(sleepMode ? 'Wake' : 'Sleep'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: sleepMode ? DoorstepTheme.warning : DoorstepTheme.textMutedOf(context),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: DoorstepTheme.borderOf(context).withValues(alpha: 0.7)),
          const SizedBox(height: 14),
          Row(
            children: [
              _Stat(label: 'Nearby', value: '$nearbyCount'),
              _Stat(label: 'Devices', value: '$pairedCount'),
              if (showDropZones) _Stat(label: 'Drop zones', value: '$dropZoneCount'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: DoorstepTheme.textMainOf(context),
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(color: DoorstepTheme.textMutedOf(context), fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ── Nearby (discovered) device row ────────────────────────────────────────────

class _DiscoveredDeviceRow extends StatelessWidget {
  final Device device;

  const _DiscoveredDeviceRow({required this.device});

  @override
  Widget build(BuildContext context) {
    final ref = context.ref;
    final isPhone = device.deviceType == DeviceType.mobile;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: DoorstepTheme.primaryOf(context).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              isPhone ? Icons.phone_android_rounded : Icons.laptop_mac_rounded,
              color: DoorstepTheme.primaryOf(context),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.alias,
                  style: TextStyle(color: DoorstepTheme.textMainOf(context), fontSize: 14.5, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${device.ip} · on the Doorstep network',
                  style: TextStyle(color: DoorstepTheme.textMutedOf(context), fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: () async {
              final trust = await showTrustDeviceDialog(
                context,
                alias: device.alias,
                incoming: false,
                address: '${device.ip}:${device.port}',
              );
              if (trust == null) return;
              await ref.notifier(doorstepPairingProvider).pairWithDiscoveredDevice(device, trustLevel: trust);
              if (context.mounted) {
                context.showSnackBar(
                  trust == DeviceTrustLevel.persistent
                      ? '${device.alias} connected — it will reconnect automatically.'
                      : '${device.alias} connected for this session only.',
                );
              }
            },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }
}

// ── Paired device row ─────────────────────────────────────────────────────────

class _PairedDeviceRow extends StatelessWidget {
  final PairedDevice device;

  const _PairedDeviceRow({required this.device});

  @override
  Widget build(BuildContext context) {
    final sinceLastSeen = DateTime.now().difference(device.lastSeen);
    final isOnline = sinceLastSeen.inMinutes < 5;
    final isTemporary = device.trustLevel == DeviceTrustLevel.temporary;
    final connected = isOnline || isTemporary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: DoorstepTheme.primaryOf(context).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(Icons.devices_rounded, color: DoorstepTheme.primaryOf(context), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.alias,
                  style: TextStyle(color: DoorstepTheme.textMainOf(context), fontSize: 14.5, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  isTemporary
                      ? 'This session only'
                      : connected
                      ? 'Connected · ${device.lastKnownIp}'
                      : 'Last seen ${_formatAge(sinceLastSeen)}',
                  style: TextStyle(color: DoorstepTheme.textMutedOf(context), fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          DoorstepStatusChip(
            label: isTemporary ? 'Session' : (isOnline ? 'Online' : 'Offline'),
            tone: isTemporary ? DoorstepStatusTone.warning : (isOnline ? DoorstepStatusTone.positive : DoorstepStatusTone.neutral),
          ),
        ],
      ),
    );
  }

  static String _formatAge(Duration d) {
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}

// ── Folder (drop zone) card ───────────────────────────────────────────────────

class _FolderCard extends StatelessWidget {
  final WatchedFolder folder;

  const _FolderCard({required this.folder});

  @override
  Widget build(BuildContext context) {
    final ref = context.ref;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 13, 8, 13),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: DoorstepTheme.primaryOf(context).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(Icons.folder_special_rounded, color: DoorstepTheme.primaryOf(context), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  folder.name,
                  style: TextStyle(color: DoorstepTheme.textMainOf(context), fontSize: 14.5, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  folder.path,
                  style: TextStyle(color: DoorstepTheme.textMutedOf(context), fontSize: 11.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _MiniChip(
                      icon: Icons.send_to_mobile_rounded,
                      label: _targetDevicesLabel(context, folder),
                      onTap: () => _pickTargetDevices(context, folder),
                    ),
                    const SizedBox(width: 7),
                    _MiniChip(
                      icon: folder.autoTransfer ? Icons.bolt_rounded : Icons.touch_app_rounded,
                      label: folder.autoTransfer ? 'Automatic' : 'Manual',
                      tone: folder.autoTransfer ? DoorstepStatusTone.positive : DoorstepStatusTone.warning,
                      onTap: () => ref.notifier(doorstepWatcherProvider).toggleAutoTransfer(folder.id), // ignore: discarded_futures
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Drop zone options',
            icon: Icon(Icons.more_vert_rounded, size: 20, color: DoorstepTheme.textMutedOf(context)),
            onSelected: (value) {
              switch (value) {
                case 'open':
                  openFolder(folderPath: folder.path); // ignore: discarded_futures
                case 'remove':
                  _confirmRemove(context, folder);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'open', child: Text('Open folder')),
              PopupMenuItem(value: 'remove', child: Text('Remove drop zone')),
            ],
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
            title: const Text('Send this folder to…', style: TextStyle(fontWeight: FontWeight.w700)),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Files dropped into “${folder.name}” go to the devices you pick here.',
                    style: TextStyle(color: DoorstepTheme.textMutedOf(ctx), fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  CheckboxListTile(
                    value: allSelected,
                    activeColor: DoorstepTheme.primaryOf(ctx),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          selected.clear();
                        }
                      });
                      if (value == true) Navigator.of(ctx).pop(true);
                    },
                    title: Text(
                      'Every connected device',
                      style: TextStyle(color: DoorstepTheme.textMainOf(ctx), fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'New devices are included automatically',
                      style: TextStyle(color: DoorstepTheme.textMutedOf(ctx), fontSize: 11.5),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  if (paired.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'No devices connected yet.',
                        style: TextStyle(color: DoorstepTheme.textMutedOf(ctx), fontSize: 12),
                      ),
                    )
                  else
                    ...paired.map(
                      (d) => CheckboxListTile(
                        value: !allSelected && selected.contains(d.id),
                        activeColor: DoorstepTheme.primaryOf(ctx),
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              selected.add(d.id);
                            } else {
                              selected.remove(d.id);
                            }
                          });
                        },
                        title: Text(d.alias, style: TextStyle(color: DoorstepTheme.textMainOf(ctx), fontSize: 14)),
                        subtitle: Text(
                          d.trustLevel == DeviceTrustLevel.temporary ? 'This session only' : 'Connected device',
                          style: TextStyle(color: DoorstepTheme.textMutedOf(ctx), fontSize: 11.5),
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
                child: Text('Cancel', style: TextStyle(color: DoorstepTheme.textMutedOf(ctx))),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );

    if (result == null || !context.mounted) return;
    if (result == true) {
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
          title: const Text('Remove this drop zone?', style: TextStyle(fontWeight: FontWeight.w700)),
          content: Text(
            '“${folder.name}” will stop sending. You can add it again later — your files are not deleted.',
            style: TextStyle(color: DoorstepTheme.textMutedOf(ctx), fontSize: 14, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Keep', style: TextStyle(color: DoorstepTheme.textMutedOf(ctx))),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                unawaited(context.ref.notifier(doorstepWatcherProvider).removeFolder(folder.id));
              },
              child: const Text('Remove'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final DoorstepStatusTone tone;
  final VoidCallback onTap;

  const _MiniChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.tone = DoorstepStatusTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = switch (tone) {
      DoorstepStatusTone.positive => isDark ? DoorstepTheme.success : const Color(0xFF15803D),
      DoorstepStatusTone.warning => isDark ? DoorstepTheme.warning : const Color(0xFFA16207),
      DoorstepStatusTone.negative => isDark ? DoorstepTheme.danger : const Color(0xFFB91C1C),
      DoorstepStatusTone.neutral => DoorstepTheme.primaryOf(context),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: color.withValues(alpha: 0.24), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12.5, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pairing modal (fallback path only) ───────────────────────────────────────

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
              color: DoorstepTheme.borderOf(context),
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Connect manually',
            style: TextStyle(color: DoorstepTheme.textMainOf(context), fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4),
          ),
          const SizedBox(height: 8),
          Text(
            'Only needed if Doorstep cannot find your other device automatically.\nOpen Doorstep on the other device and scan this code.',
            textAlign: TextAlign.center,
            style: TextStyle(color: DoorstepTheme.textMutedOf(context), fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_rounded, color: DoorstepTheme.primaryOf(context), size: 15),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Both devices must be on the same Wi-Fi network (or a hotspot).',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: DoorstepTheme.primaryOf(context), fontSize: 11.5, height: 1.3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: DoorstepTheme.backgroundOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: DoorstepTheme.borderOf(context)),
            ),
            child: Text(
              '${payload.alias}  ·  ${payload.ip}:${payload.port}',
              style: TextStyle(color: DoorstepTheme.primaryOf(context), fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: SizedBox(
              width: 200,
              height: 200,
              child: PrettyQrView.data(
                data: payload.encode(),
                decoration: const PrettyQrDecoration(
                  shape: PrettyQrSmoothSymbol(color: Colors.black),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'LAN only · encrypted · nothing leaves your network',
            style: TextStyle(color: DoorstepTheme.textMutedOf(context), fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
