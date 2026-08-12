// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'doorstep_transfer_state.dart';

class DoorstepTransferStateMapper
    extends ClassMapperBase<DoorstepTransferState> {
  DoorstepTransferStateMapper._();

  static DoorstepTransferStateMapper? _instance;
  static DoorstepTransferStateMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = DoorstepTransferStateMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'DoorstepTransferState';

  static String _$id(DoorstepTransferState v) => v.id;
  static const Field<DoorstepTransferState, String> _f$id = Field('id', _$id);
  static String _$fileName(DoorstepTransferState v) => v.fileName;
  static const Field<DoorstepTransferState, String> _f$fileName = Field(
    'fileName',
    _$fileName,
  );
  static int _$fileSize(DoorstepTransferState v) => v.fileSize;
  static const Field<DoorstepTransferState, int> _f$fileSize = Field(
    'fileSize',
    _$fileSize,
  );
  static String _$sourceDevice(DoorstepTransferState v) => v.sourceDevice;
  static const Field<DoorstepTransferState, String> _f$sourceDevice = Field(
    'sourceDevice',
    _$sourceDevice,
  );
  static String _$targetDevice(DoorstepTransferState v) => v.targetDevice;
  static const Field<DoorstepTransferState, String> _f$targetDevice = Field(
    'targetDevice',
    _$targetDevice,
  );
  static DoorstepTransferStatus _$status(DoorstepTransferState v) => v.status;
  static const Field<DoorstepTransferState, DoorstepTransferStatus> _f$status =
      Field('status', _$status);
  static double _$progress(DoorstepTransferState v) => v.progress;
  static const Field<DoorstepTransferState, double> _f$progress = Field(
    'progress',
    _$progress,
    opt: true,
    def: 0.0,
  );
  static String? _$errorMessage(DoorstepTransferState v) => v.errorMessage;
  static const Field<DoorstepTransferState, String> _f$errorMessage = Field(
    'errorMessage',
    _$errorMessage,
    opt: true,
  );
  static DateTime _$timestamp(DoorstepTransferState v) => v.timestamp;
  static const Field<DoorstepTransferState, DateTime> _f$timestamp = Field(
    'timestamp',
    _$timestamp,
  );

  @override
  final MappableFields<DoorstepTransferState> fields = const {
    #id: _f$id,
    #fileName: _f$fileName,
    #fileSize: _f$fileSize,
    #sourceDevice: _f$sourceDevice,
    #targetDevice: _f$targetDevice,
    #status: _f$status,
    #progress: _f$progress,
    #errorMessage: _f$errorMessage,
    #timestamp: _f$timestamp,
  };

  static DoorstepTransferState _instantiate(DecodingData data) {
    return DoorstepTransferState(
      id: data.dec(_f$id),
      fileName: data.dec(_f$fileName),
      fileSize: data.dec(_f$fileSize),
      sourceDevice: data.dec(_f$sourceDevice),
      targetDevice: data.dec(_f$targetDevice),
      status: data.dec(_f$status),
      progress: data.dec(_f$progress),
      errorMessage: data.dec(_f$errorMessage),
      timestamp: data.dec(_f$timestamp),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static DoorstepTransferState fromJson(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<DoorstepTransferState>(map);
  }

  static DoorstepTransferState deserialize(String json) {
    return ensureInitialized().decodeJson<DoorstepTransferState>(json);
  }
}

mixin DoorstepTransferStateMappable {
  String serialize() {
    return DoorstepTransferStateMapper.ensureInitialized()
        .encodeJson<DoorstepTransferState>(this as DoorstepTransferState);
  }

  Map<String, dynamic> toJson() {
    return DoorstepTransferStateMapper.ensureInitialized()
        .encodeMap<DoorstepTransferState>(this as DoorstepTransferState);
  }

  DoorstepTransferStateCopyWith<
    DoorstepTransferState,
    DoorstepTransferState,
    DoorstepTransferState
  >
  get copyWith =>
      _DoorstepTransferStateCopyWithImpl<
        DoorstepTransferState,
        DoorstepTransferState
      >(this as DoorstepTransferState, $identity, $identity);
  @override
  String toString() {
    return DoorstepTransferStateMapper.ensureInitialized().stringifyValue(
      this as DoorstepTransferState,
    );
  }

  @override
  bool operator ==(Object other) {
    return DoorstepTransferStateMapper.ensureInitialized().equalsValue(
      this as DoorstepTransferState,
      other,
    );
  }

  @override
  int get hashCode {
    return DoorstepTransferStateMapper.ensureInitialized().hashValue(
      this as DoorstepTransferState,
    );
  }
}

extension DoorstepTransferStateValueCopy<$R, $Out>
    on ObjectCopyWith<$R, DoorstepTransferState, $Out> {
  DoorstepTransferStateCopyWith<$R, DoorstepTransferState, $Out>
  get $asDoorstepTransferState => $base.as(
    (v, t, t2) => _DoorstepTransferStateCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class DoorstepTransferStateCopyWith<
  $R,
  $In extends DoorstepTransferState,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    String? id,
    String? fileName,
    int? fileSize,
    String? sourceDevice,
    String? targetDevice,
    DoorstepTransferStatus? status,
    double? progress,
    String? errorMessage,
    DateTime? timestamp,
  });
  DoorstepTransferStateCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _DoorstepTransferStateCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, DoorstepTransferState, $Out>
    implements DoorstepTransferStateCopyWith<$R, DoorstepTransferState, $Out> {
  _DoorstepTransferStateCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<DoorstepTransferState> $mapper =
      DoorstepTransferStateMapper.ensureInitialized();
  @override
  $R call({
    String? id,
    String? fileName,
    int? fileSize,
    String? sourceDevice,
    String? targetDevice,
    DoorstepTransferStatus? status,
    double? progress,
    Object? errorMessage = $none,
    DateTime? timestamp,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (fileName != null) #fileName: fileName,
      if (fileSize != null) #fileSize: fileSize,
      if (sourceDevice != null) #sourceDevice: sourceDevice,
      if (targetDevice != null) #targetDevice: targetDevice,
      if (status != null) #status: status,
      if (progress != null) #progress: progress,
      if (errorMessage != $none) #errorMessage: errorMessage,
      if (timestamp != null) #timestamp: timestamp,
    }),
  );
  @override
  DoorstepTransferState $make(CopyWithData data) => DoorstepTransferState(
    id: data.get(#id, or: $value.id),
    fileName: data.get(#fileName, or: $value.fileName),
    fileSize: data.get(#fileSize, or: $value.fileSize),
    sourceDevice: data.get(#sourceDevice, or: $value.sourceDevice),
    targetDevice: data.get(#targetDevice, or: $value.targetDevice),
    status: data.get(#status, or: $value.status),
    progress: data.get(#progress, or: $value.progress),
    errorMessage: data.get(#errorMessage, or: $value.errorMessage),
    timestamp: data.get(#timestamp, or: $value.timestamp),
  );

  @override
  DoorstepTransferStateCopyWith<$R2, DoorstepTransferState, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _DoorstepTransferStateCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

