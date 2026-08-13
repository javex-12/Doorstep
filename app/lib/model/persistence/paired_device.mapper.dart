// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'paired_device.dart';

class PairedDeviceMapper extends ClassMapperBase<PairedDevice> {
  PairedDeviceMapper._();

  static PairedDeviceMapper? _instance;
  static PairedDeviceMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = PairedDeviceMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'PairedDevice';

  static String _$id(PairedDevice v) => v.id;
  static const Field<PairedDevice, String> _f$id = Field('id', _$id);
  static String _$alias(PairedDevice v) => v.alias;
  static const Field<PairedDevice, String> _f$alias = Field('alias', _$alias);
  static String _$fingerprint(PairedDevice v) => v.fingerprint;
  static const Field<PairedDevice, String> _f$fingerprint = Field(
    'fingerprint',
    _$fingerprint,
  );
  static String _$token(PairedDevice v) => v.token;
  static const Field<PairedDevice, String> _f$token = Field('token', _$token);
  static String _$lastKnownIp(PairedDevice v) => v.lastKnownIp;
  static const Field<PairedDevice, String> _f$lastKnownIp = Field(
    'lastKnownIp',
    _$lastKnownIp,
  );
  static int _$port(PairedDevice v) => v.port;
  static const Field<PairedDevice, int> _f$port = Field('port', _$port);
  static DateTime _$lastSeen(PairedDevice v) => v.lastSeen;
  static const Field<PairedDevice, DateTime> _f$lastSeen = Field(
    'lastSeen',
    _$lastSeen,
  );
  static bool _$autoTransfer(PairedDevice v) => v.autoTransfer;
  static const Field<PairedDevice, bool> _f$autoTransfer = Field(
    'autoTransfer',
    _$autoTransfer,
    opt: true,
    def: true,
  );
  static List<String> _$allowedFolderIds(PairedDevice v) => v.allowedFolderIds;
  static const Field<PairedDevice, List<String>> _f$allowedFolderIds = Field(
    'allowedFolderIds',
    _$allowedFolderIds,
    opt: true,
    def: const [],
  );
  static DeviceTrustLevel _$trustLevel(PairedDevice v) => v.trustLevel;
  static const Field<PairedDevice, DeviceTrustLevel> _f$trustLevel = Field(
    'trustLevel',
    _$trustLevel,
    opt: true,
    def: DeviceTrustLevel.persistent,
  );

  @override
  final MappableFields<PairedDevice> fields = const {
    #id: _f$id,
    #alias: _f$alias,
    #fingerprint: _f$fingerprint,
    #token: _f$token,
    #lastKnownIp: _f$lastKnownIp,
    #port: _f$port,
    #lastSeen: _f$lastSeen,
    #autoTransfer: _f$autoTransfer,
    #allowedFolderIds: _f$allowedFolderIds,
    #trustLevel: _f$trustLevel,
  };

  static PairedDevice _instantiate(DecodingData data) {
    return PairedDevice(
      id: data.dec(_f$id),
      alias: data.dec(_f$alias),
      fingerprint: data.dec(_f$fingerprint),
      token: data.dec(_f$token),
      lastKnownIp: data.dec(_f$lastKnownIp),
      port: data.dec(_f$port),
      lastSeen: data.dec(_f$lastSeen),
      autoTransfer: data.dec(_f$autoTransfer),
      allowedFolderIds: data.dec(_f$allowedFolderIds),
      trustLevel: data.dec(_f$trustLevel),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static PairedDevice fromJson(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<PairedDevice>(map);
  }

  static PairedDevice deserialize(String json) {
    return ensureInitialized().decodeJson<PairedDevice>(json);
  }
}

mixin PairedDeviceMappable {
  String serialize() {
    return PairedDeviceMapper.ensureInitialized().encodeJson<PairedDevice>(
      this as PairedDevice,
    );
  }

  Map<String, dynamic> toJson() {
    return PairedDeviceMapper.ensureInitialized().encodeMap<PairedDevice>(
      this as PairedDevice,
    );
  }

  PairedDeviceCopyWith<PairedDevice, PairedDevice, PairedDevice> get copyWith =>
      _PairedDeviceCopyWithImpl<PairedDevice, PairedDevice>(
        this as PairedDevice,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return PairedDeviceMapper.ensureInitialized().stringifyValue(
      this as PairedDevice,
    );
  }

  @override
  bool operator ==(Object other) {
    return PairedDeviceMapper.ensureInitialized().equalsValue(
      this as PairedDevice,
      other,
    );
  }

  @override
  int get hashCode {
    return PairedDeviceMapper.ensureInitialized().hashValue(
      this as PairedDevice,
    );
  }
}

extension PairedDeviceValueCopy<$R, $Out>
    on ObjectCopyWith<$R, PairedDevice, $Out> {
  PairedDeviceCopyWith<$R, PairedDevice, $Out> get $asPairedDevice =>
      $base.as((v, t, t2) => _PairedDeviceCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class PairedDeviceCopyWith<$R, $In extends PairedDevice, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>>
  get allowedFolderIds;
  $R call({
    String? id,
    String? alias,
    String? fingerprint,
    String? token,
    String? lastKnownIp,
    int? port,
    DateTime? lastSeen,
    bool? autoTransfer,
    List<String>? allowedFolderIds,
    DeviceTrustLevel? trustLevel,
  });
  PairedDeviceCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _PairedDeviceCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, PairedDevice, $Out>
    implements PairedDeviceCopyWith<$R, PairedDevice, $Out> {
  _PairedDeviceCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<PairedDevice> $mapper =
      PairedDeviceMapper.ensureInitialized();
  @override
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>>
  get allowedFolderIds => ListCopyWith(
    $value.allowedFolderIds,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(allowedFolderIds: v),
  );
  @override
  $R call({
    String? id,
    String? alias,
    String? fingerprint,
    String? token,
    String? lastKnownIp,
    int? port,
    DateTime? lastSeen,
    bool? autoTransfer,
    List<String>? allowedFolderIds,
    DeviceTrustLevel? trustLevel,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (alias != null) #alias: alias,
      if (fingerprint != null) #fingerprint: fingerprint,
      if (token != null) #token: token,
      if (lastKnownIp != null) #lastKnownIp: lastKnownIp,
      if (port != null) #port: port,
      if (lastSeen != null) #lastSeen: lastSeen,
      if (autoTransfer != null) #autoTransfer: autoTransfer,
      if (allowedFolderIds != null) #allowedFolderIds: allowedFolderIds,
      if (trustLevel != null) #trustLevel: trustLevel,
    }),
  );
  @override
  PairedDevice $make(CopyWithData data) => PairedDevice(
    id: data.get(#id, or: $value.id),
    alias: data.get(#alias, or: $value.alias),
    fingerprint: data.get(#fingerprint, or: $value.fingerprint),
    token: data.get(#token, or: $value.token),
    lastKnownIp: data.get(#lastKnownIp, or: $value.lastKnownIp),
    port: data.get(#port, or: $value.port),
    lastSeen: data.get(#lastSeen, or: $value.lastSeen),
    autoTransfer: data.get(#autoTransfer, or: $value.autoTransfer),
    allowedFolderIds: data.get(#allowedFolderIds, or: $value.allowedFolderIds),
    trustLevel: data.get(#trustLevel, or: $value.trustLevel),
  );

  @override
  PairedDeviceCopyWith<$R2, PairedDevice, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _PairedDeviceCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

