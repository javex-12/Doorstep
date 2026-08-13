// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'watched_folder.dart';

class WatchedFolderMapper extends ClassMapperBase<WatchedFolder> {
  WatchedFolderMapper._();

  static WatchedFolderMapper? _instance;
  static WatchedFolderMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = WatchedFolderMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'WatchedFolder';

  static String _$id(WatchedFolder v) => v.id;
  static const Field<WatchedFolder, String> _f$id = Field('id', _$id);
  static String _$name(WatchedFolder v) => v.name;
  static const Field<WatchedFolder, String> _f$name = Field('name', _$name);
  static String _$path(WatchedFolder v) => v.path;
  static const Field<WatchedFolder, String> _f$path = Field('path', _$path);
  static bool _$autoTransfer(WatchedFolder v) => v.autoTransfer;
  static const Field<WatchedFolder, bool> _f$autoTransfer = Field(
    'autoTransfer',
    _$autoTransfer,
    opt: true,
    def: true,
  );
  static bool _$enabled(WatchedFolder v) => v.enabled;
  static const Field<WatchedFolder, bool> _f$enabled = Field(
    'enabled',
    _$enabled,
    opt: true,
    def: true,
  );
  static List<String> _$targetDeviceIds(WatchedFolder v) => v.targetDeviceIds;
  static const Field<WatchedFolder, List<String>> _f$targetDeviceIds = Field(
    'targetDeviceIds',
    _$targetDeviceIds,
    opt: true,
    def: const [],
  );
  static DateTime _$createdAt(WatchedFolder v) => v.createdAt;
  static const Field<WatchedFolder, DateTime> _f$createdAt = Field(
    'createdAt',
    _$createdAt,
  );

  @override
  final MappableFields<WatchedFolder> fields = const {
    #id: _f$id,
    #name: _f$name,
    #path: _f$path,
    #autoTransfer: _f$autoTransfer,
    #enabled: _f$enabled,
    #targetDeviceIds: _f$targetDeviceIds,
    #createdAt: _f$createdAt,
  };

  static WatchedFolder _instantiate(DecodingData data) {
    return WatchedFolder(
      id: data.dec(_f$id),
      name: data.dec(_f$name),
      path: data.dec(_f$path),
      autoTransfer: data.dec(_f$autoTransfer),
      enabled: data.dec(_f$enabled),
      targetDeviceIds: data.dec(_f$targetDeviceIds),
      createdAt: data.dec(_f$createdAt),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static WatchedFolder fromJson(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<WatchedFolder>(map);
  }

  static WatchedFolder deserialize(String json) {
    return ensureInitialized().decodeJson<WatchedFolder>(json);
  }
}

mixin WatchedFolderMappable {
  String serialize() {
    return WatchedFolderMapper.ensureInitialized().encodeJson<WatchedFolder>(
      this as WatchedFolder,
    );
  }

  Map<String, dynamic> toJson() {
    return WatchedFolderMapper.ensureInitialized().encodeMap<WatchedFolder>(
      this as WatchedFolder,
    );
  }

  WatchedFolderCopyWith<WatchedFolder, WatchedFolder, WatchedFolder>
  get copyWith => _WatchedFolderCopyWithImpl<WatchedFolder, WatchedFolder>(
    this as WatchedFolder,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return WatchedFolderMapper.ensureInitialized().stringifyValue(
      this as WatchedFolder,
    );
  }

  @override
  bool operator ==(Object other) {
    return WatchedFolderMapper.ensureInitialized().equalsValue(
      this as WatchedFolder,
      other,
    );
  }

  @override
  int get hashCode {
    return WatchedFolderMapper.ensureInitialized().hashValue(
      this as WatchedFolder,
    );
  }
}

extension WatchedFolderValueCopy<$R, $Out>
    on ObjectCopyWith<$R, WatchedFolder, $Out> {
  WatchedFolderCopyWith<$R, WatchedFolder, $Out> get $asWatchedFolder =>
      $base.as((v, t, t2) => _WatchedFolderCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class WatchedFolderCopyWith<$R, $In extends WatchedFolder, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>>
  get targetDeviceIds;
  $R call({
    String? id,
    String? name,
    String? path,
    bool? autoTransfer,
    bool? enabled,
    List<String>? targetDeviceIds,
    DateTime? createdAt,
  });
  WatchedFolderCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _WatchedFolderCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, WatchedFolder, $Out>
    implements WatchedFolderCopyWith<$R, WatchedFolder, $Out> {
  _WatchedFolderCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<WatchedFolder> $mapper =
      WatchedFolderMapper.ensureInitialized();
  @override
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>>
  get targetDeviceIds => ListCopyWith(
    $value.targetDeviceIds,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(targetDeviceIds: v),
  );
  @override
  $R call({
    String? id,
    String? name,
    String? path,
    bool? autoTransfer,
    bool? enabled,
    List<String>? targetDeviceIds,
    DateTime? createdAt,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (name != null) #name: name,
      if (path != null) #path: path,
      if (autoTransfer != null) #autoTransfer: autoTransfer,
      if (enabled != null) #enabled: enabled,
      if (targetDeviceIds != null) #targetDeviceIds: targetDeviceIds,
      if (createdAt != null) #createdAt: createdAt,
    }),
  );
  @override
  WatchedFolder $make(CopyWithData data) => WatchedFolder(
    id: data.get(#id, or: $value.id),
    name: data.get(#name, or: $value.name),
    path: data.get(#path, or: $value.path),
    autoTransfer: data.get(#autoTransfer, or: $value.autoTransfer),
    enabled: data.get(#enabled, or: $value.enabled),
    targetDeviceIds: data.get(#targetDeviceIds, or: $value.targetDeviceIds),
    createdAt: data.get(#createdAt, or: $value.createdAt),
  );

  @override
  WatchedFolderCopyWith<$R2, WatchedFolder, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _WatchedFolderCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

