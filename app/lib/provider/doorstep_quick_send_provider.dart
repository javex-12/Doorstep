import 'dart:async';

import 'package:doorstep_app/model/cross_file.dart';
import 'package:doorstep_app/model/persistence/favorite_device.dart';
import 'package:doorstep_app/model/persistence/paired_device.dart';
import 'package:doorstep_app/model/state/nearby_devices_state.dart';
import 'package:doorstep_app/provider/doorstep_pairing_provider.dart';
import 'package:doorstep_app/provider/doorstep_transfer_provider.dart';
import 'package:doorstep_app/provider/network/nearby_devices_provider.dart';
import 'package:doorstep_app/provider/settings_provider.dart';
import 'package:doorstep_app/util/native/cross_file_converters.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:localsend_isolates/model/device.dart';
import 'package:logging/logging.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _logger = Logger('DoorstepQuickSend');

/// How long to keep collecting discovery results after files arrive before
/// deciding between auto-send (exactly one trusted device online), the device
/// picker (several), or falling back to the regular send tab (none).
const quickSendDiscoveryGrace = Duration(milliseconds: 2500);

/// Whether [paired] has been seen on the network recently — via multicast
/// announcements, an HTTP register, or the favorite HTTP scan — meaning it is
/// online right now and a send would not go into the void.
bool isPairedDeviceOnline(PairedDevice paired, NearbyDevicesState nearby) {
  for (final device in nearby.devices.values) {
    if (device.fingerprint == paired.fingerprint && device.ip != null && device.ip!.isNotEmpty && device.ip != '-') {
      return true;
    }
  }
  for (final device in nearby.signalingDevices[paired.fingerprint] ?? const <Device>{}) {
    if (device.ip != null && device.ip!.isNotEmpty) {
      return true;
    }
  }
  return false;
}

/// The trusted (persistent) devices among [paired] that are online right now.
/// This is the input to the quick-send decision: exactly one → auto-send,
/// several → picker, none → fall back to the send tab.
List<PairedDevice> onlineTrustedDevicesOf(List<PairedDevice> paired, NearbyDevicesState nearby) {
  return paired.where((d) => d.trustLevel == DeviceTrustLevel.persistent && isPairedDeviceOnline(d, nearby)).toList();
}

/// Merges [b] into [a] without duplicate files (same path). Keeps order of [a].
List<CrossFile> mergeQuickSendFiles(List<CrossFile> a, List<CrossFile> b) {
  final merged = [...a];
  for (final file in b) {
    if (!merged.any((e) => e.isSameFile(otherFile: file))) {
      merged.add(file);
    }
  }
  return merged;
}

/// A pending "send these files" request that came from outside the normal
/// in-app flow (Windows right-click, phone share sheet, app-start arguments).
@immutable
class DoorstepQuickSendRequest {
  final List<CrossFile> files;

  /// `true` while discovery is still settling (the overlay shows a spinner);
  /// `false` once the decision has been made — picker or fallback.
  /// Exactly-one-device auto-send closes the request instead.
  final bool searching;

  const DoorstepQuickSendRequest({required this.files, required this.searching});
}

final doorstepQuickSendProvider = NotifierProvider<DoorstepQuickSendNotifier, DoorstepQuickSendRequest?>((ref) {
  return DoorstepQuickSendNotifier();
});

class DoorstepQuickSendNotifier extends Notifier<DoorstepQuickSendRequest?> {
  Timer? _searchTimer;

  @override
  DoorstepQuickSendRequest? init() => null;

  /// Called when files arrive from an external trigger (right-click send,
  /// share sheet, app-start arguments). Merges with any pending request so a
  /// multi-file Windows right-click coalesces into a single popup.
  void requestQuickSend(List<CrossFile> files) {
    if (files.isEmpty) return;

    final existing = state;
    final merged = existing == null ? files : mergeQuickSendFiles(existing.files, files);
    state = DoorstepQuickSendRequest(files: merged, searching: true);

    _searchTimer?.cancel();
    _searchTimer = Timer(quickSendDiscoveryGrace, _resolve);

    _refreshDiscovery();
  }

  /// Sends every pending file to [device] and closes the request.
  Future<void> sendTo(PairedDevice device) async {
    final request = state;
    if (request == null) return;
    _logger.info('Quick-send: sending ${request.files.length} file(s) to ${device.alias}');
    _startTransfers(device, request.files);
    dismiss();
  }

  /// Closes the request without sending. Files stay in the regular send tab.
  void dismiss() {
    _searchTimer?.cancel();
    _searchTimer = null;
    state = null;
  }

  /// After the grace period: exactly one trusted device online → auto-send;
  /// otherwise keep the request up so the user can pick a device or fall back.
  void _resolve() {
    _searchTimer = null;
    final request = state;
    if (request == null) return;

    final online = _onlineTrustedDevices();
    if (online.length == 1) {
      final device = online.first;
      _logger.info('Quick-send: only ${device.alias} is online — auto-sending ${request.files.length} file(s)');
      _startTransfers(device, request.files);
      state = null;
      return;
    }
    if (online.length > 1) {
      _logger.info('Quick-send: ${online.length} trusted devices online — showing picker');
    } else {
      _logger.info('Quick-send: no trusted device online — falling back to send tab');
    }
    state = DoorstepQuickSendRequest(files: request.files, searching: false);
  }

  List<PairedDevice> _onlineTrustedDevices() {
    final nearby = ref.read(nearbyDevicesProvider);
    return onlineTrustedDevicesOf(ref.read(doorstepPairingProvider), nearby);
  }

  /// Actively refresh presence so the decision reflects the network right now:
  /// our multicast announcement makes every nearby device register back over
  /// HTTP, and the favorite scan HTTP-pings each trusted device's stored
  /// address. Together they confirm who is online within the grace period.
  void _refreshDiscovery() {
    ref.redux(nearbyDevicesProvider).dispatch(StartMulticastScan());
    final trusted = ref
        .read(doorstepPairingProvider)
        .where((d) => d.trustLevel == DeviceTrustLevel.persistent)
        .map(
          (d) => FavoriteDevice.fromValues(
            fingerprint: d.fingerprint,
            ip: d.lastKnownIp,
            port: d.port,
            alias: d.alias,
          ),
        )
        .where((f) => f.ip.isNotEmpty && f.ip != '0.0.0.0' && f.ip != '-')
        .toList();
    if (trusted.isNotEmpty) {
      final https = ref.read(settingsProvider).https;
      unawaited(ref.redux(nearbyDevicesProvider).dispatchAsync(StartFavoriteScan(devices: trusted, https: https)));
    }
  }

  void _startTransfers(PairedDevice device, List<CrossFile> files) {
    for (final file in files) {
      // The transfer queue serializes them — the receiver only accepts one
      // session at a time.
      unawaited(
        ref.notifier(doorstepTransferProvider).startTrackedTransfer(crossFile: file, paired: device, sourceLabel: 'Doorstep [quick send]'),
      );
    }
  }
}
