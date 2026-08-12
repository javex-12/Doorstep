import 'package:dart_mappable/dart_mappable.dart';

part 'doorstep_transfer_state.mapper.dart';

enum DoorstepTransferStatus {
  pending,
  transferring,
  completed,
  failed,
  retrying,
}

@MappableClass()
class DoorstepTransferState with DoorstepTransferStateMappable {
  final String id;
  final String fileName;
  final int fileSize;
  final String sourceDevice;
  final String targetDevice;
  final DoorstepTransferStatus status;
  final double progress;
  final String? errorMessage;
  final DateTime timestamp;

  const DoorstepTransferState({
    required this.id,
    required this.fileName,
    required this.fileSize,
    required this.sourceDevice,
    required this.targetDevice,
    required this.status,
    this.progress = 0.0,
    this.errorMessage,
    required this.timestamp,
  });

  static const fromJson = DoorstepTransferStateMapper.fromJson;
}
