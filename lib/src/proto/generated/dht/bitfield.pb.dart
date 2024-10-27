//
//  Generated code. Do not modify.
//  source: bitfield.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

/// Functionality to set a bit at a specific index
class BitFieldProto_SetBitRequest extends $pb.GeneratedMessage {
  factory BitFieldProto_SetBitRequest({
    $core.int? index,
  }) {
    final $result = create();
    if (index != null) {
      $result.index = index;
    }
    return $result;
  }
  BitFieldProto_SetBitRequest._() : super();
  factory BitFieldProto_SetBitRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BitFieldProto_SetBitRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BitFieldProto.SetBitRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.data_structures'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'index', $pb.PbFieldType.O3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BitFieldProto_SetBitRequest clone() => BitFieldProto_SetBitRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BitFieldProto_SetBitRequest copyWith(void Function(BitFieldProto_SetBitRequest) updates) => super.copyWith((message) => updates(message as BitFieldProto_SetBitRequest)) as BitFieldProto_SetBitRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BitFieldProto_SetBitRequest create() => BitFieldProto_SetBitRequest._();
  BitFieldProto_SetBitRequest createEmptyInstance() => create();
  static $pb.PbList<BitFieldProto_SetBitRequest> createRepeated() => $pb.PbList<BitFieldProto_SetBitRequest>();
  @$core.pragma('dart2js:noInline')
  static BitFieldProto_SetBitRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BitFieldProto_SetBitRequest>(create);
  static BitFieldProto_SetBitRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get index => $_getIZ(0);
  @$pb.TagNumber(1)
  set index($core.int v) { $_setSignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasIndex() => $_has(0);
  @$pb.TagNumber(1)
  void clearIndex() => clearField(1);
}

/// Functionality to clear a bit at a specific index
class BitFieldProto_ClearBitRequest extends $pb.GeneratedMessage {
  factory BitFieldProto_ClearBitRequest({
    $core.int? index,
  }) {
    final $result = create();
    if (index != null) {
      $result.index = index;
    }
    return $result;
  }
  BitFieldProto_ClearBitRequest._() : super();
  factory BitFieldProto_ClearBitRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BitFieldProto_ClearBitRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BitFieldProto.ClearBitRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.data_structures'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'index', $pb.PbFieldType.O3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BitFieldProto_ClearBitRequest clone() => BitFieldProto_ClearBitRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BitFieldProto_ClearBitRequest copyWith(void Function(BitFieldProto_ClearBitRequest) updates) => super.copyWith((message) => updates(message as BitFieldProto_ClearBitRequest)) as BitFieldProto_ClearBitRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BitFieldProto_ClearBitRequest create() => BitFieldProto_ClearBitRequest._();
  BitFieldProto_ClearBitRequest createEmptyInstance() => create();
  static $pb.PbList<BitFieldProto_ClearBitRequest> createRepeated() => $pb.PbList<BitFieldProto_ClearBitRequest>();
  @$core.pragma('dart2js:noInline')
  static BitFieldProto_ClearBitRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BitFieldProto_ClearBitRequest>(create);
  static BitFieldProto_ClearBitRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get index => $_getIZ(0);
  @$pb.TagNumber(1)
  set index($core.int v) { $_setSignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasIndex() => $_has(0);
  @$pb.TagNumber(1)
  void clearIndex() => clearField(1);
}

/// Functionality to get a bit at a specific index
class BitFieldProto_GetBitRequest extends $pb.GeneratedMessage {
  factory BitFieldProto_GetBitRequest({
    $core.int? index,
  }) {
    final $result = create();
    if (index != null) {
      $result.index = index;
    }
    return $result;
  }
  BitFieldProto_GetBitRequest._() : super();
  factory BitFieldProto_GetBitRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BitFieldProto_GetBitRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BitFieldProto.GetBitRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.data_structures'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'index', $pb.PbFieldType.O3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BitFieldProto_GetBitRequest clone() => BitFieldProto_GetBitRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BitFieldProto_GetBitRequest copyWith(void Function(BitFieldProto_GetBitRequest) updates) => super.copyWith((message) => updates(message as BitFieldProto_GetBitRequest)) as BitFieldProto_GetBitRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BitFieldProto_GetBitRequest create() => BitFieldProto_GetBitRequest._();
  BitFieldProto_GetBitRequest createEmptyInstance() => create();
  static $pb.PbList<BitFieldProto_GetBitRequest> createRepeated() => $pb.PbList<BitFieldProto_GetBitRequest>();
  @$core.pragma('dart2js:noInline')
  static BitFieldProto_GetBitRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BitFieldProto_GetBitRequest>(create);
  static BitFieldProto_GetBitRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get index => $_getIZ(0);
  @$pb.TagNumber(1)
  set index($core.int v) { $_setSignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasIndex() => $_has(0);
  @$pb.TagNumber(1)
  void clearIndex() => clearField(1);
}

/// Response message for bit value
class BitFieldProto_BitResponse extends $pb.GeneratedMessage {
  factory BitFieldProto_BitResponse({
    $core.bool? value,
  }) {
    final $result = create();
    if (value != null) {
      $result.value = value;
    }
    return $result;
  }
  BitFieldProto_BitResponse._() : super();
  factory BitFieldProto_BitResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BitFieldProto_BitResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BitFieldProto.BitResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.data_structures'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'value')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BitFieldProto_BitResponse clone() => BitFieldProto_BitResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BitFieldProto_BitResponse copyWith(void Function(BitFieldProto_BitResponse) updates) => super.copyWith((message) => updates(message as BitFieldProto_BitResponse)) as BitFieldProto_BitResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BitFieldProto_BitResponse create() => BitFieldProto_BitResponse._();
  BitFieldProto_BitResponse createEmptyInstance() => create();
  static $pb.PbList<BitFieldProto_BitResponse> createRepeated() => $pb.PbList<BitFieldProto_BitResponse>();
  @$core.pragma('dart2js:noInline')
  static BitFieldProto_BitResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BitFieldProto_BitResponse>(create);
  static BitFieldProto_BitResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get value => $_getBF(0);
  @$pb.TagNumber(1)
  set value($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => clearField(1);
}

class BitFieldProto extends $pb.GeneratedMessage {
  factory BitFieldProto({
    $core.List<$core.int>? bits,
    $core.int? size,
  }) {
    final $result = create();
    if (bits != null) {
      $result.bits = bits;
    }
    if (size != null) {
      $result.size = size;
    }
    return $result;
  }
  BitFieldProto._() : super();
  factory BitFieldProto.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BitFieldProto.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BitFieldProto', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.data_structures'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'bits', $pb.PbFieldType.OY)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'size', $pb.PbFieldType.O3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BitFieldProto clone() => BitFieldProto()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BitFieldProto copyWith(void Function(BitFieldProto) updates) => super.copyWith((message) => updates(message as BitFieldProto)) as BitFieldProto;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BitFieldProto create() => BitFieldProto._();
  BitFieldProto createEmptyInstance() => create();
  static $pb.PbList<BitFieldProto> createRepeated() => $pb.PbList<BitFieldProto>();
  @$core.pragma('dart2js:noInline')
  static BitFieldProto getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BitFieldProto>(create);
  static BitFieldProto? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get bits => $_getN(0);
  @$pb.TagNumber(1)
  set bits($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasBits() => $_has(0);
  @$pb.TagNumber(1)
  void clearBits() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get size => $_getIZ(1);
  @$pb.TagNumber(2)
  set size($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasSize() => $_has(1);
  @$pb.TagNumber(2)
  void clearSize() => clearField(2);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
