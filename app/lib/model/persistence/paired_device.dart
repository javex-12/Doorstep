import 'package:dart_mappable/dart_mappable.dart';

part 'paired_device.mapper.dart';

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
  });

  static const fromJson = PairedDeviceMapper.fromJson;
}
