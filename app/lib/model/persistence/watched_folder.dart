import 'package:dart_mappable/dart_mappable.dart';

part 'watched_folder.mapper.dart';

@MappableClass()
class WatchedFolder with WatchedFolderMappable {
  final String id;
  final String name;
  final String path;
  final bool autoTransfer;
  final bool enabled;
  final DateTime createdAt;

  /// The paired devices this drop zone pushes files to. Empty = all paired
  /// devices (default). When set, only those device ids receive files.
  final List<String> targetDeviceIds;

  const WatchedFolder({
    required this.id,
    required this.name,
    required this.path,
    this.autoTransfer = true,
    this.enabled = true,
    this.targetDeviceIds = const [],
    required this.createdAt,
  });

  static const fromJson = WatchedFolderMapper.fromJson;
}
