import 'package:dart_mappable/dart_mappable.dart';

part 'paired_device.mapper.dart';

/// How much a paired device is trusted.
enum DeviceTrustLevel {
  /// The user's own device — remembered across restarts, reconnects
  /// automatically and can push files at any time.
  persistent,

  /// A device trusted only for the current session — never persisted and
  /// never reconnected to after the app restarts.
  temporary,
}

@MappableClass()
class PairedDevice with PairedDeviceMappable {
  final String id;
  final String alias;
  final String fingerprint;
  final String token;
  final String lastKnownIp;
  final int port;
  final DateTime lastSeen;
  final bool autoTransfer;
  final List<String> allowedFolderIds;
  final DeviceTrustLevel trustLevel;

  const PairedDevice({
    required this.id,
    required this.alias,
    required this.fingerprint,
    required this.token,
    required this.lastKnownIp,
    required this.port,
    required this.lastSeen,
    this.autoTransfer = true,
    this.allowedFolderIds = const [],
    this.trustLevel = DeviceTrustLevel.persistent,
  });

  static const fromJson = PairedDeviceMapper.fromJson;
}
