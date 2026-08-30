import 'dart:async';
import 'dart:convert';

import 'package:doorstep_app/model/persistence/paired_device.dart';
import 'package:doorstep_app/provider/device_info_provider.dart';
import 'package:doorstep_app/provider/doorstep_settings_provider.dart';
import 'package:doorstep_app/provider/doorstep_watcher_provider.dart';
import 'package:doorstep_app/provider/http_provider.dart';
import 'package:doorstep_app/provider/network/nearby_devices_provider.dart';
import 'package:doorstep_app/provider/persistence_provider.dart';
import 'package:doorstep_app/util/doorstep_pairing_helper.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:localsend_isolates/constants.dart';
import 'package:localsend_isolates/model/device.dart';
import 'package:localsend_isolates/rust/api/model.dart' as rust_model;
import 'package:localsend_isolates/util/rust.dart';
import 'package:logging/logging.dart';
import 'package:refena_flutter/refena_flutter.dart';

final doorstepPairingProvider = NotifierProvider<DoorstepPairingNotifier, List<PairedDevice>>((ref) {
  return DoorstepPairingNotifier();
});

class DoorstepPairingNotifier extends Notifier<List<PairedDevice>> {
  static final _logger = Logger('DoorstepPairingNotifier');
  late final PersistenceService _persistence;

  @override
  List<PairedDevice> init() {
    _persistence = ref.read(persistenceProvider);
    final raw = _persistence.getPairedDevicesRaw();
    return raw.map((e) => PairedDevice.fromJson(jsonDecode(e) as Map<String, dynamic>)).toList();
  }

  Future<void> _save(List<PairedDevice> devices) async {
    final persistence = ref.read(persistenceProvider);
    await persistence.setPairedDevicesRaw(
      devices.map((d) => jsonEncode(d.toJson())).toList(),
    );
  }

  /// Returns (creating and persisting on first call) the long-lived pairing
  /// token of *this* device.
  Future<String> getOrCreateOwnToken() async {
    final persistence = ref.read(persistenceProvider);
    final existing = persistence.getDoorstepOwnToken();
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final token = DoorstepPairingPayload.generateDeviceToken();
    await persistence.setDoorstepOwnToken(token);
    return token;
  }

  /// Opens the pairing window: for the next [_pairingWindow], a device that
  /// registers back with [token] is trusted as the one that scanned the QR.
  void beginPairing(String token) {
    _pendingPairingToken = token;
    _pendingPairingUntil = DateTime.now().add(_pairingWindow);
  }

  /// Accepts an incoming pairing request from a scanned QR payload.
  /// This is the *phone* side: the laptop is stored as a paired device.
  ///
  /// [trustLevel] decides how the laptop is remembered:
  ///  - [DeviceTrustLevel.persistent] — saved to disk, auto-reconnects.
  ///  - [DeviceTrustLevel.temporary] — in-memory only, gone after restart,
  ///    never auto-reconnected to.
  Future<PairedDevice> acceptPairing({
    required DoorstepPairingPayload payload,
    required String localIp,
    required int localPort,
    required DeviceTrustLevel trustLevel,
  }) async {
    final device = PairedDevice(
      id: payload.deviceId,
      alias: payload.alias,
      fingerprint: payload.fingerprint,
      // The token that proves trust is the one embedded in the scanned QR —
      // the laptop only accepts connections presenting it. Generating a fresh
      // token here would silently break reconnects.
      token: payload.token,
      lastKnownIp: payload.ip,
      port: payload.port,
      lastSeen: DateTime.now(),
      trustLevel: trustLevel,
    );

    final updated = [...state.where((d) => d.id != device.id), device];
    state = updated;
    // Temporary devices are session-only: never written to disk.
    if (trustLevel == DeviceTrustLevel.persistent) {
      await _save(updated);
    } else {
      _logger.info('Paired with ${device.alias} as a temporary device (not saved)');
    }
    return device;
  }

  /// Direct one-tap pairing with a discovered network device (no QR code required).
  Future<PairedDevice> pairWithDiscoveredDevice(
    Device device, {
    DeviceTrustLevel trustLevel = DeviceTrustLevel.persistent,
  }) async {
    final ownToken = await getOrCreateOwnToken();
    final paired = PairedDevice(
      id: device.fingerprint,
      alias: device.alias,
      fingerprint: device.fingerprint,
      token: ownToken,
      lastKnownIp: device.ip ?? '0.0.0.0',
      port: device.port,
      lastSeen: DateTime.now(),
      trustLevel: trustLevel,
    );

    final updated = [...state.where((d) => d.id != paired.id), paired];
    state = updated;
    if (trustLevel == DeviceTrustLevel.persistent) {
      await _save(updated);
    }

    // Register our identity with the peer so both sides are linked
    unawaited(registerWithPairedDevice(paired));
    _logger.info('Paired with ${device.alias} (${device.ip}:${device.port}) directly from network discovery');
    return paired;
  }

  /// The *laptop* side of the two-way handshake: a device registered itself on
  /// this server. If the register carries the Doorstep handshake carrier,
  /// the device is stored as paired. Registers without the carrier are ignored.
  ///
  /// Returns the created/updated device, or `null` when the register is not a
  /// valid Doorstep handshake.
  Future<PairedDevice?> acceptRegisterHandshake({
    required String? deviceModel,
    required String fingerprint,
    required String alias,
    required String ip,
    required int port,
  }) async {
    final handshake = DoorstepPairingHandshake.parse(deviceModel);
    if (handshake == null) {
      return null;
    }

    final device = PairedDevice(
      id: fingerprint,
      alias: alias,
      fingerprint: fingerprint,
      // The phone's own token — the trust anchor for the reverse direction.
      token: handshake.phoneToken.isNotEmpty ? handshake.phoneToken : (await getOrCreateOwnToken()),
      lastKnownIp: ip,
      port: port,
      lastSeen: DateTime.now(),
      trustLevel: handshake.trustLevel,
    );

    final updated = [...state.where((d) => d.id != device.id), device];
    state = updated;
    // Temporary devices are session-only: never written to disk.
    if (handshake.trustLevel == DeviceTrustLevel.persistent) {
      await _save(updated);
    }

    // The pairing window is consumed by the first accepted handshake.
    _pendingPairingToken = null;
    _pendingPairingUntil = null;

    _logger.info('Paired with $alias ($ip:$port) via Doorstep network handshake (${handshake.trustLevel.name})');
    return device;
  }

  /// Called when a device reconnects — updates its last-known IP and timestamp.
  Future<void> updateLastSeen(String deviceId, String newIp) async {
    final updated = state.map((d) {
      if (d.id == deviceId) {
        return d.copyWith(lastKnownIp: newIp, lastSeen: DateTime.now());
      }
      return d;
    }).toList();
    state = updated;
    await _save(updated);
  }

  /// Revoke a paired device by id — removes its token and entry, and drops it
  /// from every drop zone's target list so routing stays consistent.
  Future<void> revokeDevice(String deviceId) async {
    final updated = state.where((d) => d.id != deviceId).toList();
    state = updated;
    await _save(updated);
    // Be smart: don't leave revoked devices dangling in folder routing.
    // ignore: discarded_futures
    unawaited(ref.notifier(doorstepWatcherProvider).removeDeviceFromTargets(deviceId));
  }

  /// Sends this device's identity to [device] over the standard LocalSend
  /// `register` endpoint, carrying the Doorstep handshake tokens.
  ///
  /// The laptop answers by storing this device in its own paired list (and by
  /// updating the last-known IP, so the laptop can reach us after DHCP drift).
  /// Returns `true` when the register request succeeded.
  Future<bool> registerWithPairedDevice(PairedDevice device) async {
    final ip = reachableIpOf(device);
    if (ip == null) {
      _logger.warning('Cannot reach paired device ${device.alias}: no IP known');
      return false;
    }

    final deviceInfo = ref.read(deviceFullInfoProvider);
    final ownToken = await getOrCreateOwnToken();
    final payload = rust_model.RegisterDto(
      alias: deviceInfo.alias,
      version: protocolVersion,
      deviceModel: DoorstepPairingHandshake.encode(
        deviceInfo.deviceModel ?? '',
        laptopToken: device.token,
        phoneToken: ownToken,
        trustLevel: device.trustLevel,
      ),
      deviceType: deviceInfo.deviceType.toRust(),
      token: deviceInfo.fingerprint,
      port: deviceInfo.port,
      protocol: deviceInfo.getProtocolType(),
      hasWebInterface: deviceInfo.download,
    );

    try {
      final client = ref.read(httpProvider).pinnedTo(device.fingerprint);
      await client.register(
        protocol: payload.protocol,
        ip: ip,
        port: device.port,
        payload: payload,
      );
      _logger.info('Registered with paired device ${device.alias} at $ip:${device.port}');
      return true;
    } catch (e) {
      _logger.warning('Failed to register with paired device ${device.alias}: $e');
      return false;
    }
  }

  /// Re-registers with every paired device whose token this device knows.
  ///
  /// The phone uses this to reconnect after a restart or a network change: the
  /// laptop refreshes the phone's IP and last-seen, so auto-transfer keeps
  /// working without re-scanning. No-op on desktop (the laptop does not need
  /// to announce itself to the phones it already knows) and while Doorstep
  /// sleep mode is active (battery saver).
  Future<void> reconnectToPairedDevices() async {
    if (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    if (ref.read(doorstepSettingsProvider).sleepMode) {
      _logger.info('Sleep mode active — skipping reconnect announcements');
      return;
    }
    for (final device in state) {
      if (device.trustLevel != DeviceTrustLevel.persistent) {
        // Temporary devices never reconnect automatically — by design.
        _logger.info('Skipping reconnect to temporary device ${device.alias}');
        continue;
      }
      // ignore: discarded_futures
      unawaited(registerWithPairedDevice(device));
    }
  }

  /// Prefers a freshly discovered address (from the ongoing discovery) over
  /// the stored last-known IP, so DHCP/IP changes do not break reachability.
  String? reachableIpOf(PairedDevice device) {
    final nearby = ref.read(nearbyDevicesProvider).allDevices[device.fingerprint];
    if (nearby?.ip != null && nearby!.ip != '-' && nearby.ip!.isNotEmpty) {
      return nearby.ip;
    }
    if (device.lastKnownIp.isNotEmpty && device.lastKnownIp != '0.0.0.0' && device.lastKnownIp != '-') {
      return device.lastKnownIp;
    }
    return null;
  }

  /// Builds the send target for [paired], preferring a freshly discovered
  /// address over the stored last-known IP. Shared by the folder watcher and
  /// the live-browser pull flow.
  Device resolveTarget(PairedDevice paired) {
    final nearby = ref.read(nearbyDevicesProvider).allDevices[paired.fingerprint];
    return Device(
      signalingId: null,
      ip: (nearby?.ip != null && nearby!.ip != '-' && nearby.ip!.isNotEmpty) ? nearby.ip : paired.lastKnownIp,
      version: protocolVersion,
      port: nearby?.port ?? paired.port,
      https: true,
      fingerprint: paired.fingerprint,
      alias: paired.alias,
      deviceModel: nearby?.deviceModel,
      deviceType: DeviceType.mobile,
      download: false,
      discoveryMethods: nearby?.discoveryMethods ?? const {},
    );
  }
}
