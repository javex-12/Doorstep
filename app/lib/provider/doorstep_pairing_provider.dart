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
import 'package:doorstep_isolates/constants.dart';
import 'package:doorstep_isolates/model/device.dart';
import 'package:doorstep_isolates/rust/api/model.dart' as rust_model;
import 'package:doorstep_isolates/util/rust.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:logging/logging.dart';
import 'package:refena_flutter/refena_flutter.dart';

final doorstepPairingProvider = NotifierProvider<DoorstepPairingNotifier, List<PairedDevice>>((ref) {
  return DoorstepPairingNotifier();
});

/// What handling an incoming register handshake decided.
enum DoorstepHandshakeOutcome {
  /// Not a Doorstep handshake — an ordinary register from a LocalSend-style peer.
  notDoorstep,

  /// The handshake did not prove it was addressed to this device.
  rejected,

  /// A device this user already trusts reconnected.
  known,

  /// A new device asked to connect and is waiting for the user's answer.
  awaitingApproval,
}

/// The outcome of [DoorstepPairingNotifier.handleRegisterHandshake].
class DoorstepHandshakeResult {
  final DoorstepHandshakeOutcome outcome;
  final DeviceTrustLevel trustLevel;
  final String peerToken;

  const DoorstepHandshakeResult(
    this.outcome, {
    this.trustLevel = DeviceTrustLevel.persistent,
    this.peerToken = '',
  });
}

class DoorstepPairingNotifier extends Notifier<List<PairedDevice>> {
  static final _logger = Logger('DoorstepPairingNotifier');
  late final PersistenceService _persistence;

  Timer? _reconnectTimer;

  @override
  List<PairedDevice> init() {
    _persistence = ref.read(persistenceProvider);
    final raw = _persistence.getPairedDevicesRaw();
    _startReconnectLoop();
    return raw.map((e) => PairedDevice.fromJson(jsonDecode(e) as Map<String, dynamic>)).toList();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    super.dispose();
  }

  /// Keeps this phone's reachability fresh, for as long as Doorstep runs.
  ///
  /// Reconnecting once at startup was not enough. If the computer happened to
  /// be asleep at that moment there was no second attempt, so the connection
  /// silently went stale and the user had to connect by hand — precisely the
  /// thing Doorstep exists to remove. This retries quietly in the background;
  /// re-registering is idempotent, so a redundant attempt costs nothing.
  void _startReconnectLoop() {
    if (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) {
      // The computer does not announce itself back to phones: its address is
      // stable enough, and the phones re-register on their own schedule.
      return;
    }
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      try {
        unawaited(reconnectToPairedDevices());
      } catch (e) {
        _logger.info('Background reconnect skipped: $e');
      }
    });
  }

  /// A fire-and-forget register that can never surface as an unhandled async
  /// error.
  ///
  /// The handshake is best-effort by design: a peer that is asleep, on a
  /// different port, or briefly unreachable is a normal state, not a failure the
  /// user should see. Reporting it was what made "Connect" throw an error even
  /// though pairing had succeeded.
  void _registerQuietly(PairedDevice device) {
    unawaited(
      registerWithPairedDevice(device).catchError((Object e) {
        _logger.info('${device.alias} is not reachable yet: $e');
        return false;
      }),
    );
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

  /// Opens the pairing window: for the next 90 seconds, a device that
  /// registers back with [token] is trusted as the one that scanned the QR.
  ///
  /// Kept as a no-op for API compatibility — the window was never enforced;
  /// trust comes from the Doorstep handshake carrier in the register payload.
  void beginPairing(String token) {}

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
    // The peer's token is not known yet: discovery carries its fingerprint, not
    // its secret. Until the peer hands its token back (it does that when it
    // accepts this request) we address it by fingerprint, which is enough to
    // prove the request was aimed at *it*.
    final paired = PairedDevice(
      id: device.fingerprint,
      alias: device.alias,
      fingerprint: device.fingerprint,
      token: '',
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

    // Actually ask: this register is what makes the other device show
    // "<you> wants to connect" and wait for an answer. Until it says yes, the
    // entry above is a request, not a trusted device.
    _registerQuietly(paired);
    _logger.info('Connection request sent to ${device.alias} (${device.ip}:${device.port})');
    return paired;
  }

  /// This side of the two-way handshake: a device registered itself on this
  /// server carrying the Doorstep carrier.
  ///
  /// Three things can happen, and the caller decides what to show the user:
  ///  - the carrier is missing            → [DoorstepHandshakeOutcome.notDoorstep]
  ///  - the token does not prove anything → [DoorstepHandshakeOutcome.rejected]
  ///  - a device we already trust said hi → [DoorstepHandshakeOutcome.known]
  ///  - a *new* device asked to connect   → [DoorstepHandshakeOutcome.awaitingApproval]
  ///
  /// Nothing is trusted here. A new device only becomes paired once the user
  /// answers the request (see `doorstepConnectionRequestProvider`).
  Future<DoorstepHandshakeResult> handleRegisterHandshake({
    required String? deviceModel,
    required String fingerprint,
    required String alias,
    required String ip,
    required int port,
  }) async {
    final handshake = DoorstepPairingHandshake.parse(deviceModel);
    if (handshake == null) {
      return const DoorstepHandshakeResult(DoorstepHandshakeOutcome.notDoorstep);
    }

    // The asking device must present *our* token. It can only know it by having
    // discovered us or been given it by the user — so this is the proof that the
    // request is aimed at us and not replayed at the network.
    // Two accepted forms of "this is addressed to me":
    //  - our own token   → the peer got it from us (accepted before, or QR)
    //  - our fingerprint → the peer found us by discovery and is asking now
    // Neither is an authorisation: the user still decides (below). They only
    // prove the request was aimed at this device rather than sprayed at the LAN.
    final ownToken = await getOrCreateOwnToken();
    final ownFingerprint = ref.read(deviceFullInfoProvider).fingerprint;
    if (handshake.laptopToken != ownToken && handshake.laptopToken != ownFingerprint) {
      _logger.warning('Rejected Doorstep handshake from $alias ($ip): not addressed to this device');
      return const DoorstepHandshakeResult(DoorstepHandshakeOutcome.rejected);
    }

    final peerToken = handshake.phoneToken.isNotEmpty ? handshake.phoneToken : ownToken;
    final result = DoorstepHandshakeResult(
      DoorstepHandshakeOutcome.awaitingApproval,
      trustLevel: handshake.trustLevel,
      peerToken: peerToken,
    );

    final existing = _find(fingerprint);
    if (existing != null) {
      // A device we already know: refresh where it is now, and adopt its token
      // if we were still addressing it by fingerprint (first approval).
      final adopted = existing.token.isEmpty ? existing.copyWith(token: peerToken) : existing;
      await _upsert(adopted.copyWith(alias: alias, lastKnownIp: ip, port: port, lastSeen: DateTime.now()));
      _logger.info('${adopted.alias} reconnected at $ip:$port');
      return DoorstepHandshakeResult(DoorstepHandshakeOutcome.known, trustLevel: adopted.trustLevel, peerToken: adopted.token);
    }

    if (!ref.read(doorstepSettingsProvider).askBeforeConnecting) {
      // The user turned the prompt off: accept silently, as before.
      await acceptConnectionRequest(
        PairedDevice(
          id: fingerprint,
          alias: alias,
          fingerprint: fingerprint,
          token: peerToken,
          lastKnownIp: ip,
          port: port,
          lastSeen: DateTime.now(),
          autoTransfer: handshake.trustLevel == DeviceTrustLevel.persistent,
          trustLevel: handshake.trustLevel,
        ),
      );
      return DoorstepHandshakeResult(DoorstepHandshakeOutcome.known, trustLevel: handshake.trustLevel, peerToken: peerToken);
    }

    return result;
  }

  /// Finalises a connection request the user accepted.
  ///
  /// Trusting a device that asked to connect is deliberately *not* the same as
  /// trusting a device you connected to yourself: automatic drop-zone delivery
  /// stays off until the user turns it on for that device, so accepting a
  /// request can never silently start pushing files.
  Future<PairedDevice> acceptConnectionRequest(PairedDevice device) async {
    final normalised = device.copyWith(autoTransfer: device.autoTransfer && device.trustLevel == DeviceTrustLevel.persistent);
    final updated = [...state.where((d) => d.id != device.id), normalised];
    state = updated;
    if (normalised.trustLevel == DeviceTrustLevel.persistent) {
      await _save(updated);
    }
    _logger.info('Accepted connection from ${normalised.alias} (${normalised.lastKnownIp}:${normalised.port}, ${normalised.trustLevel.name})');

    // Hand our token back so the other side stops addressing us by fingerprint
    // and becomes a real trusted device on its own list too. Without this the
    // request would only ever be half-accepted.
    if (normalised.lastKnownIp.isNotEmpty && normalised.lastKnownIp != '0.0.0.0' && normalised.lastKnownIp != '-') {
      _registerQuietly(normalised);
    }
    return normalised;
  }

  PairedDevice? _find(String idOrFingerprint) {
    for (final device in state) {
      if (device.id == idOrFingerprint || device.fingerprint == idOrFingerprint) return device;
    }
    return null;
  }

  Future<void> _upsert(PairedDevice device) async {
    final updated = [...state.where((d) => d.id != device.id), device];
    state = updated;
    if (device.trustLevel == DeviceTrustLevel.persistent) {
      await _save(updated);
    }
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

  /// Sends this device's identity to [device] over the standard Doorstep
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
        // Addressed to the peer's token when we have it, otherwise to its
        // fingerprint (the pre-approval form). Both are accepted by the peer and
        // both prove the request was aimed at that specific device.
        laptopToken: device.token.isNotEmpty ? device.token : device.fingerprint,
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
      _registerQuietly(device);
    }
  }

  /// The `Device` entry for [paired] currently known from any discovery
  /// source — LAN multicast, an HTTP register, or the favorite HTTP scan — or
  /// `null` when the device has not been seen recently.
  ///
  /// Scans by fingerprint rather than relying on `allDevices[fingerprint]`:
  /// LAN devices are stored keyed by IP, so a fingerprint lookup would miss
  /// them (it only matches signaling devices).
  Device? freshlyDiscovered(PairedDevice paired) {
    final nearby = ref.read(nearbyDevicesProvider);
    for (final device in nearby.devices.values) {
      if (device.fingerprint == paired.fingerprint && device.ip != null && device.ip!.isNotEmpty && device.ip != '-') {
        return device;
      }
    }
    for (final device in nearby.signalingDevices[paired.fingerprint] ?? const <Device>{}) {
      if (device.ip != null && device.ip!.isNotEmpty) {
        return device;
      }
    }
    return null;
  }

  /// Prefers a freshly discovered address (from the ongoing discovery) over
  /// the stored last-known IP, so DHCP/IP changes do not break reachability.
  String? reachableIpOf(PairedDevice device) {
    final nearby = freshlyDiscovered(device);
    if (nearby?.ip != null && nearby!.ip != '-' && nearby.ip!.isNotEmpty) {
      return nearby.ip;
    }
    if (device.lastKnownIp.isNotEmpty && device.lastKnownIp != '0.0.0.0' && device.lastKnownIp != '-') {
      return device.lastKnownIp;
    }
    return null;
  }

  /// Builds the send target for [paired], preferring a freshly discovered
  /// address over the stored last-known IP. Shared by the folder watcher, the
  /// live-browser pull flow, and quick-send.
  Device resolveTarget(PairedDevice paired) {
    final nearby = freshlyDiscovered(paired);
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
