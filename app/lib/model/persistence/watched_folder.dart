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

  const WatchedFolder({
    required this.id,
    required this.name,
    required this.path,
    this.autoTransfer = true,
    this.enabled = true,
    required this.createdAt,
  });

  static const fromJson = WatchedFolderMapper.fromJson;
}
