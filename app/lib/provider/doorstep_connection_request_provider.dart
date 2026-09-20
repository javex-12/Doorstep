import 'package:collection/collection.dart';
import 'package:doorstep_app/model/persistence/paired_device.dart';
import 'package:doorstep_app/provider/doorstep_pairing_provider.dart';
import 'package:doorstep_app/provider/persistence_provider.dart';
import 'package:logging/logging.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _logger = Logger('DoorstepConnectionRequest');

/// A device nearby that asked to connect and is waiting for an answer.
///
/// This is the door in "anyone near you can see Doorstep, and *you* decide who
/// comes in". Nothing is trusted until [DoorstepConnectionRequestNotifier.accept]
/// runs, and a declined device is remembered so it cannot turn this into a nag.
class DoorstepConnectionRequest {
  final String fingerprint;
  final String alias;
  final String ip;
  final int port;

  /// The asking device's own long-lived token — becomes the trust anchor once
  /// the request is accepted.
  final String peerToken;

  /// Whether the peer asked to be remembered, or only for this session.
  final DeviceTrustLevel trustLevel;

  final DateTime receivedAt;

  const DoorstepConnectionRequest({
    required this.fingerprint,
    required this.alias,
    required this.ip,
    required this.port,
    required this.peerToken,
    required this.trustLevel,
    required this.receivedAt,
  });

  /// The device this request would become once accepted.
  PairedDevice toPairedDevice() {
    return PairedDevice(
      id: fingerprint,
      alias: alias,
      fingerprint: fingerprint,
      token: peerToken,
      lastKnownIp: ip,
      port: port,
      lastSeen: DateTime.now(),
      trustLevel: trustLevel,
    );
  }
}

final doorstepConnectionRequestProvider = NotifierProvider<DoorstepConnectionRequestNotifier, List<DoorstepConnectionRequest>>((ref) {
  return DoorstepConnectionRequestNotifier();
});

class DoorstepConnectionRequestNotifier extends Notifier<List<DoorstepConnectionRequest>> {
  /// Fingerprints the user already declined. Loaded from disk so a restart does
  /// not re-open a door the user closed.
  late final Set<String> _declined;

  @override
  List<DoorstepConnectionRequest> init() {
    _declined = ref.read(persistenceProvider).getDoorstepDeclinedPeers().toSet();
    return const [];
  }

  /// Whether [fingerprint] asked before and was declined.
  bool wasDeclined(String fingerprint) => _declined.contains(fingerprint);

  /// Records an incoming request. Replaces any earlier request from the same
  /// device so a re-announce does not stack prompts.
  void request(DoorstepConnectionRequest request) {
    if (_declined.contains(request.fingerprint)) {
      _logger.info('Ignoring connection request from previously declined ${request.alias}');
      return;
    }
    if (state.any((r) => r.fingerprint == request.fingerprint)) {
      // Already on screen — just refresh the address in case it moved.
      state = [for (final r in state) r.fingerprint == request.fingerprint ? request : r];
      return;
    }
    _logger.info('Connection request from ${request.alias} (${request.ip}:${request.port})');
    state = [...state, request];
  }

  /// Accepts a request: the device becomes trusted exactly as if the user had
  /// connected to it themselves.
  Future<void> accept(String fingerprint) async {
    final request = state.firstWhereOrNull((r) => r.fingerprint == fingerprint);
    if (request == null) return;
    await ref.notifier(doorstepPairingProvider).acceptConnectionRequest(request.toPairedDevice());
    _remove(fingerprint);
  }

  /// Declines a request. The device is not stored, and is remembered so it is
  /// not asked again until the user connects to it deliberately.
  Future<void> decline(String fingerprint) async {
    _remove(fingerprint);
    _declined.add(fingerprint);
    await ref.read(persistenceProvider).setDoorstepDeclinedPeers(_declined.toList());
    _logger.info('Declined connection request from $fingerprint');
  }

  /// Forgets a previous decline — used when the user connects to a device by
  /// hand, so a device they now want is not permanently locked out.
  Future<void> forgetDecline(String fingerprint) async {
    if (!_declined.remove(fingerprint)) return;
    await ref.read(persistenceProvider).setDoorstepDeclinedPeers(_declined.toList());
  }

  void _remove(String fingerprint) {
    state = state.where((r) => r.fingerprint != fingerprint).toList();
  }
}
