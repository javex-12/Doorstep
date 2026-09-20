import 'dart:async';

import 'package:doorstep_app/config/doorstep_theme.dart';
import 'package:doorstep_app/model/persistence/favorite_device.dart';
import 'package:doorstep_app/model/persistence/paired_device.dart';
import 'package:doorstep_app/model/persistence/watched_folder.dart';
import 'package:doorstep_app/pages/doorstep_browse_page.dart';
import 'package:doorstep_app/provider/device_info_provider.dart';
import 'package:doorstep_app/provider/doorstep_connection_request_provider.dart';
import 'package:doorstep_app/provider/doorstep_pairing_provider.dart';
import 'package:doorstep_app/provider/doorstep_quick_send_provider.dart';
import 'package:doorstep_app/provider/doorstep_settings_provider.dart';
import 'package:doorstep_app/provider/doorstep_watcher_provider.dart';
import 'package:doorstep_app/provider/local_ip_provider.dart';
import 'package:doorstep_app/provider/network/nearby_devices_provider.dart';
import 'package:doorstep_app/provider/network/scan_facade.dart';
import 'package:doorstep_app/provider/network/send_provider.dart';
import 'package:doorstep_app/provider/selection/selected_sending_files_provider.dart';
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

  bool _initialScanScheduled = false;

  @override
  void initState() {
    super.initState();
    if (_isMobile) {
      // Announce this phone to every known laptop so its IP and last-seen stay
      // fresh (handles DHCP drift and app restarts without re-scanning).
      Future.microtask(() => ref.notifier(doorstepPairingProvider).reconnectToPairedDevices()); // ignore: discarded_futures
    }
  }

  /// Discovery runs three ways at once so a network that blocks one of them
  /// still finds the other device:
  ///  1. UDP multicast (fastest, works on most home routers)
  ///  2. UDP broadcast on the same interfaces (survives multicast filtering)
  ///  3. HTTP subnet sweep on the local interfaces (last resort, always works)
  void _refreshDiscovery() {
    ref.redux(nearbyDevicesProvider).dispatch(StartMulticastScan());
    final subnets = ref.read(localIpProvider).localIps.take(3).toList();
    if (subnets.isNotEmpty) {
      // ignore: discarded_futures
      ref.global.dispatchAsync(StartLegacySubnetScan(subnets: subnets));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Kick off the subnet sweep once the first frame is up. Guarded so a
    // dependency change cannot queue a second scan on top of the first.
    if (_initialScanScheduled) return;
    _initialScanScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshDiscovery();
    });
  }

  @override
  Widget build(BuildContext context) {
    final watchedFolders = context.watch(doorstepWatcherProvider);
    final pairedDevices = context.watch(doorstepPairingProvider);
    final settings = context.watch(doorstepSettingsProvider);
    final deviceInfo = context.watch(deviceFullInfoProvider);
    final nearbyDevices = context.watch(nearbyDevicesProvider).allDevices;
    final connectionRequests = context.watch(doorstepConnectionRequestProvider);
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

              // ── Someone nearby wants to connect ──────────────────────────
              // This is the door: a device that found Doorstep asks to come in,
              // and only the person holding the phone can let it.
              if (connectionRequests.isNotEmpty) ...[
                for (final request in connectionRequests) _ConnectionRequestCard(request: request),
                const SizedBox(height: 20),
              ],

              _StatusPanel(
                alias: deviceInfo.alias,
                ip: deviceInfo.ip,
                port: deviceInfo.port,
                sleepMode: settings.sleepMode,
                // Battery saver is a phone concern; a plugged-in computer has no
                // reason to stop announcing itself.
                onToggleSleep: _isMobile
                    ? () => ref
                          .notifier(doorstepSettingsProvider)
                          .setSleepMode(!settings.sleepMode) // ignore: discarded_futures
                    : null,
              ),
              const SizedBox(height: 26),

              // ── Nearby ────────────────────────────────────────────────────
              DoorstepSection(
                title: 'Nearby',
                // Plain language on purpose: the user never needs to reason about
                // networks, only about devices.
                subtitle: discoveredNearby.isEmpty
                    ? 'Anyone near you with Doorstep open appears here'
                    : '${discoveredNearby.length} ready to connect',
                action: TextButton(
                  onPressed: _refreshDiscovery,
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  child: const Text('Search'),
                ),
                children: discoveredNearby.isEmpty
                    ? [
                        _SearchingRow(onManual: () => _showManualPairing(context)),
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

              // ── Share ─────────────────────────────────────────────────────
              // The smallest useful transfer: no file, no folder, no picker.
              DoorstepSection(
                title: 'Share',
                subtitle: pairedDevices.isEmpty ? 'Connect a device first' : 'Send something without a folder',
                children: [
                  DoorstepListTile(
                    icon: Icons.sticky_note_2_outlined,
                    title: 'Send a note',
                    subtitle: 'Type or paste text and send it straight over',
                    enabled: pairedDevices.isNotEmpty,
                    trailing: const DoorstepChevron(),
                    onTap: () => _sendNote(context),
                  ),
                ],
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

  /// Composes a note and hands it to the quick-send card.
  ///
  /// Quick-send sends straight away when exactly one trusted device is online
  /// and shows a picker otherwise, so a note needs no device picker of its own.
  Future<void> _sendNote(BuildContext context) async {
    final paired = ref.read(doorstepPairingProvider);
    if (paired.isEmpty) {
      context.showSnackBar('Connect a device first.');
      return;
    }

    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Send a note'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 5,
            minLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Paste a link, an address, a code…',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: const Text('Send'),
            ),
          ],
        );
      },
    );

    final message = text?.trim();
    if (message == null || message.isEmpty) return;
    ref.notifier(doorstepQuickSendProvider).requestQuickSend([buildNoteFile(message)]);
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

  /// Fallback for networks where *automatic* discovery finds nothing — for
  /// example a router that blocks both multicast and broadcast. The user types
  /// the other device's address, and Doorstep runs the exact same HTTP
  /// discovery against that one address. Nothing is trusted implicitly: the
  /// device still has to answer the Doorstep handshake, and the user still
  /// chooses the trust level exactly as in the automatic flow.
  Future<void> _showManualPairing(BuildContext context) async {
    final controller = TextEditingController();
    final entered = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Connect manually'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Only needed when Doorstep cannot find the other device on its own.\n\nOpen Doorstep on the other device, look at the address on its screen, and type it here.',
                style: TextStyle(color: DoorstepTheme.textMutedOf(ctx), fontSize: 13.5, height: 1.45),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  labelText: 'Device address',
                  hintText: '192.168.1.5',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Search'),
            ),
          ],
        );
      },
    );

    final address = entered?.trim();
    if (address == null || address.isEmpty) return;

    // Accept both "192.168.1.5" and "192.168.1.5:53317".
    var host = address;
    final port = ref.read(deviceFullInfoProvider).port;
    var targetPort = port;
    final colon = address.lastIndexOf(':');
    if (colon > 0 && !address.contains(']')) {
      final parsed = int.tryParse(address.substring(colon + 1));
      if (parsed != null && parsed > 0 && parsed <= 65535) {
        host = address.substring(0, colon);
        targetPort = parsed;
      }
    }

    if (!context.mounted) return;
    context.showSnackBar('Looking for a Doorstep device at $host…');

    await ref.redux(nearbyDevicesProvider).dispatchAsync(
      StartFavoriteScan(
        devices: [FavoriteDevice.fromValues(fingerprint: '', ip: host, port: targetPort, alias: host)],
        https: true,
      ),
    );
    if (!context.mounted) return;

    Device? found;
    for (final device in ref.read(nearbyDevicesProvider).allDevices.values) {
      if (device.ip == host) {
        found = device;
        break;
      }
    }

    if (found == null) {
      context.showSnackBar('No Doorstep device answered at $host. Check the address, and that Doorstep is running on the other device.');
      return;
    }

    final trust = await showTrustDeviceDialog(
      context,
      alias: found.alias,
      incoming: false,
      address: '$host:$targetPort',
    );
    if (trust == null) return;
    await ref.notifier(doorstepPairingProvider).pairWithDiscoveredDevice(found, trustLevel: trust);
    if (context.mounted) {
      context.showSnackBar(
        trust == DeviceTrustLevel.persistent
            ? '${found.alias} connected — it will reconnect automatically.'
            : '${found.alias} connected for this session only.',
      );
    }
  }
}

// ── Searching (empty nearby state) ───────────────────────────────────────────

/// One slim line while discovery runs.
///
/// An empty state with an icon, a headline, a paragraph and a link is the right
/// treatment for "you have nothing yet"; it is the wrong treatment for "this is
/// still happening". Discovery is expected to find something within a second or
/// two, so it gets a single row that disappears on its own.
class _SearchingRow extends StatelessWidget {
  final VoidCallback onManual;

  const _SearchingRow({required this.onManual});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Row(
        children: [
          SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              color: DoorstepTheme.primaryOf(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Looking for devices…',
              style: TextStyle(color: DoorstepTheme.textMutedOf(context), fontSize: 13.5),
            ),
          ),
          TextButton(
            onPressed: onManual,
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            child: const Text('Connect manually'),
          ),
        ],
      ),
    );
  }
}

// ── Incoming connection request ──────────────────────────────────────────────

/// A device nearby is asking to connect.
///
/// Accepting trusts it exactly like connecting by hand. Declining keeps it out
/// and remembers the answer, so the door stays closed without nagging.
class _ConnectionRequestCard extends StatefulWidget {
  final DoorstepConnectionRequest request;

  const _ConnectionRequestCard({required this.request});

  @override
  State<_ConnectionRequestCard> createState() => _ConnectionRequestCardState();
}

class _ConnectionRequestCardState extends State<_ConnectionRequestCard> with Refena {
  bool _busy = false;

  Future<void> _answer({required bool accept}) async {
    setState(() => _busy = true);
    final notifier = ref.notifier(doorstepConnectionRequestProvider);
    if (accept) {
      await notifier.accept(widget.request.fingerprint);
    } else {
      await notifier.decline(widget.request.fingerprint);
    }
    if (!mounted) return;
    context.showSnackBar(accept ? '${widget.request.alias} connected.' : 'Connection declined.');
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final remembered = request.trustLevel == DeviceTrustLevel.persistent;

    return DoorstepCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: DoorstepTheme.primaryOf(context).withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.person_add_alt_1_rounded, color: DoorstepTheme.primaryOf(context), size: 22),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${request.alias} wants to connect',
                      style: TextStyle(
                        color: DoorstepTheme.textMainOf(context),
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${request.ip}:${request.port} · ${remembered ? 'to be remembered' : 'this session only'}',
                      style: TextStyle(color: DoorstepTheme.textMutedOf(context), fontSize: 11.5, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _answer(accept: false),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13)),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : () => _answer(accept: true),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13)),
                  child: const Text('Connect'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Status panel (hero) ───────────────────────────────────────────────────────

/// This device's state, as one quiet line.
///
/// The old panel was a hero card with a big icon tile, a status chip, a divider
/// and three count columns — all of which duplicated what the section headers
/// below already say ("2 ready to connect", "1 connected"). What a user cannot
/// get anywhere else is whether *this* device is reachable, so that is all this
/// shows now.
class _StatusPanel extends StatelessWidget {
  final String alias;
  final String? ip;
  final int port;
  final bool sleepMode;
  final VoidCallback? onToggleSleep;

  const _StatusPanel({
    required this.alias,
    required this.ip,
    required this.port,
    required this.sleepMode,
    required this.onToggleSleep,
  });

  @override
  Widget build(BuildContext context) {
    final connected = ip != null && ip != '-' && ip!.isNotEmpty;
    final ready = connected && !sleepMode;

    final (label, tone) = sleepMode
        ? ('Sleep mode', DoorstepTheme.warningOf(context))
        : connected
        ? ('Ready for transfers', DoorstepTheme.successOf(context))
        : ('Not on a network', DoorstepTheme.dangerOf(context));

    return DoorstepCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
      child: Row(
        children: [
          _StatusDot(color: tone, pulse: ready),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: DoorstepTheme.textMainOf(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  connected ? '$alias · $ip:$port' : alias,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: DoorstepTheme.textMutedOf(context), fontSize: 12),
                ),
              ],
            ),
          ),
          if (onToggleSleep != null)
            IconButton(
              tooltip: sleepMode ? 'Wake Doorstep' : 'Sleep mode — stop announcing',
              onPressed: onToggleSleep,
              icon: Icon(sleepMode ? Icons.brightness_high_rounded : Icons.bedtime_outlined, size: 20),
              color: sleepMode ? DoorstepTheme.warningOf(context) : DoorstepTheme.textMutedOf(context),
            ),
        ],
      ),
    );
  }
}

/// A small status light. It breathes while this device is ready, so "ready"
/// reads at a glance without an icon, a badge or a colour name.
class _StatusDot extends StatefulWidget {
  final Color color;
  final bool pulse;

  const _StatusDot({required this.color, required this.pulse});

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void initState() {
    super.initState();
    if (widget.pulse) {
      // ignore: discarded_futures
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse && !_controller.isAnimating) {
      // ignore: discarded_futures
      _controller.repeat(reverse: true);
    } else if (!widget.pulse && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: widget.pulse ? 0.72 + 0.28 * _controller.value : 1),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: widget.pulse ? 0.18 + 0.22 * _controller.value : 0.25),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
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
              try {
                await ref.notifier(doorstepPairingProvider).pairWithDiscoveredDevice(device, trustLevel: trust);
              } catch (e) {
                // The device is discovered but not reachable yet. Say what
                // happened instead of letting a raw exception reach the user.
                if (context.mounted) {
                  context.showSnackBar('Could not finish connecting to ${device.alias}. Make sure it is still open, then try again.');
                }
                return;
              }
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
                      icon: folder.autoTransfer ? Icons.sync_rounded : Icons.touch_app_rounded,
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

