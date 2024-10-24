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
class BitField_SetBitRequest extends $pb.GeneratedMessage {
  factory BitField_SetBitRequest({
    $core.int? index,
  }) {
    final $result = create();
    if (index != null) {
      $result.index = index;
    }
    return $result;
  }
  BitField_SetBitRequest._() : super();
  factory BitField_SetBitRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BitField_SetBitRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BitField.SetBitRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'index', $pb.PbFieldType.O3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BitField_SetBitRequest clone() => BitField_SetBitRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BitField_SetBitRequest copyWith(void Function(BitField_SetBitRequest) updates) => super.copyWith((message) => updates(message as BitField_SetBitRequest)) as BitField_SetBitRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BitField_SetBitRequest create() => BitField_SetBitRequest._();
  BitField_SetBitRequest createEmptyInstance() => create();
  static $pb.PbList<BitField_SetBitRequest> createRepeated() => $pb.PbList<BitField_SetBitRequest>();
  @$core.pragma('dart2js:noInline')
  static BitField_SetBitRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BitField_SetBitRequest>(create);
  static BitField_SetBitRequest? _defaultInstance;

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
class BitField_GetBitRequest extends $pb.GeneratedMessage {
  factory BitField_GetBitRequest({
    $core.int? index,
  }) {
    final $result = create();
    if (index != null) {
      $result.index = index;
    }
    return $result;
  }
  BitField_GetBitRequest._() : super();
  factory BitField_GetBitRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BitField_GetBitRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BitField.GetBitRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'index', $pb.PbFieldType.O3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BitField_GetBitRequest clone() => BitField_GetBitRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BitField_GetBitRequest copyWith(void Function(BitField_GetBitRequest) updates) => super.copyWith((message) => updates(message as BitField_GetBitRequest)) as BitField_GetBitRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BitField_GetBitRequest create() => BitField_GetBitRequest._();
  BitField_GetBitRequest createEmptyInstance() => create();
  static $pb.PbList<BitField_GetBitRequest> createRepeated() => $pb.PbList<BitField_GetBitRequest>();
  @$core.pragma('dart2js:noInline')
  static BitField_GetBitRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BitField_GetBitRequest>(create);
  static BitField_GetBitRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get index => $_getIZ(0);
  @$pb.TagNumber(1)
  set index($core.int v) { $_setSignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasIndex() => $_has(0);
  @$pb.TagNumber(1)
  void clearIndex() => clearField(1);
}

class BitField_BitResponse extends $pb.GeneratedMessage {
  factory BitField_BitResponse({
    $core.bool? value,
  }) {
    final $result = create();
    if (value != null) {
      $result.value = value;
    }
    return $result;
  }
  BitField_BitResponse._() : super();
  factory BitField_BitResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BitField_BitResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BitField.BitResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'value')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BitField_BitResponse clone() => BitField_BitResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BitField_BitResponse copyWith(void Function(BitField_BitResponse) updates) => super.copyWith((message) => updates(message as BitField_BitResponse)) as BitField_BitResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BitField_BitResponse create() => BitField_BitResponse._();
  BitField_BitResponse createEmptyInstance() => create();
  static $pb.PbList<BitField_BitResponse> createRepeated() => $pb.PbList<BitField_BitResponse>();
  @$core.pragma('dart2js:noInline')
  static BitField_BitResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BitField_BitResponse>(create);
  static BitField_BitResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get value => $_getBF(0);
  @$pb.TagNumber(1)
  set value($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => clearField(1);
}

class BitField extends $pb.GeneratedMessage {
  factory BitField({
    $core.Iterable<$core.bool>? bits,
    $core.int? size,
  }) {
    final $result = create();
    if (bits != null) {
      $result.bits.addAll(bits);
    }
    if (size != null) {
      $result.size = size;
    }
    return $result;
  }
  BitField._() : super();
  factory BitField.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BitField.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BitField', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs'), createEmptyInstance: create)
    ..p<$core.bool>(1, _omitFieldNames ? '' : 'bits', $pb.PbFieldType.KB)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'size', $pb.PbFieldType.O3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BitField clone() => BitField()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BitField copyWith(void Function(BitField) updates) => super.copyWith((message) => updates(message as BitField)) as BitField;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BitField create() => BitField._();
  BitField createEmptyInstance() => create();
  static $pb.PbList<BitField> createRepeated() => $pb.PbList<BitField>();
  @$core.pragma('dart2js:noInline')
  static BitField getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BitField>(create);
  static BitField? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.bool> get bits => $_getList(0);

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
