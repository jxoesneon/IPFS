// This is a generated file - do not edit.
//
// Generated from core/bitfield.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

/// Functionality to set a bit at a specific index
class BitFieldProto_SetBitRequest extends $pb.GeneratedMessage {
  factory BitFieldProto_SetBitRequest({
    $core.int? index,
  }) {
    final result = create();
    if (index != null) result.index = index;
    return result;
  }

  BitFieldProto_SetBitRequest._();

  factory BitFieldProto_SetBitRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BitFieldProto_SetBitRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BitFieldProto.SetBitRequest',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'ipfs.core.data_structures'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'index')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BitFieldProto_SetBitRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BitFieldProto_SetBitRequest copyWith(
          void Function(BitFieldProto_SetBitRequest) updates) =>
      super.copyWith(
              (message) => updates(message as BitFieldProto_SetBitRequest))
          as BitFieldProto_SetBitRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BitFieldProto_SetBitRequest create() =>
      BitFieldProto_SetBitRequest._();
  @$core.override
  BitFieldProto_SetBitRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BitFieldProto_SetBitRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BitFieldProto_SetBitRequest>(create);
  static BitFieldProto_SetBitRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get index => $_getIZ(0);
  @$pb.TagNumber(1)
  set index($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIndex() => $_has(0);
  @$pb.TagNumber(1)
  void clearIndex() => $_clearField(1);
}

/// Functionality to clear a bit at a specific index
class BitFieldProto_ClearBitRequest extends $pb.GeneratedMessage {
  factory BitFieldProto_ClearBitRequest({
    $core.int? index,
  }) {
    final result = create();
    if (index != null) result.index = index;
    return result;
  }

  BitFieldProto_ClearBitRequest._();

  factory BitFieldProto_ClearBitRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BitFieldProto_ClearBitRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BitFieldProto.ClearBitRequest',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'ipfs.core.data_structures'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'index')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BitFieldProto_ClearBitRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BitFieldProto_ClearBitRequest copyWith(
          void Function(BitFieldProto_ClearBitRequest) updates) =>
      super.copyWith(
              (message) => updates(message as BitFieldProto_ClearBitRequest))
          as BitFieldProto_ClearBitRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BitFieldProto_ClearBitRequest create() =>
      BitFieldProto_ClearBitRequest._();
  @$core.override
  BitFieldProto_ClearBitRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BitFieldProto_ClearBitRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BitFieldProto_ClearBitRequest>(create);
  static BitFieldProto_ClearBitRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get index => $_getIZ(0);
  @$pb.TagNumber(1)
  set index($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIndex() => $_has(0);
  @$pb.TagNumber(1)
  void clearIndex() => $_clearField(1);
}

/// Functionality to get a bit at a specific index
class BitFieldProto_GetBitRequest extends $pb.GeneratedMessage {
  factory BitFieldProto_GetBitRequest({
    $core.int? index,
  }) {
    final result = create();
    if (index != null) result.index = index;
    return result;
  }

  BitFieldProto_GetBitRequest._();

  factory BitFieldProto_GetBitRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BitFieldProto_GetBitRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BitFieldProto.GetBitRequest',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'ipfs.core.data_structures'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'index')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BitFieldProto_GetBitRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BitFieldProto_GetBitRequest copyWith(
          void Function(BitFieldProto_GetBitRequest) updates) =>
      super.copyWith(
              (message) => updates(message as BitFieldProto_GetBitRequest))
          as BitFieldProto_GetBitRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BitFieldProto_GetBitRequest create() =>
      BitFieldProto_GetBitRequest._();
  @$core.override
  BitFieldProto_GetBitRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BitFieldProto_GetBitRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BitFieldProto_GetBitRequest>(create);
  static BitFieldProto_GetBitRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get index => $_getIZ(0);
  @$pb.TagNumber(1)
  set index($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIndex() => $_has(0);
  @$pb.TagNumber(1)
  void clearIndex() => $_clearField(1);
}

/// Response message for bit value
class BitFieldProto_BitResponse extends $pb.GeneratedMessage {
  factory BitFieldProto_BitResponse({
    $core.bool? value,
  }) {
    final result = create();
    if (value != null) result.value = value;
    return result;
  }

  BitFieldProto_BitResponse._();

  factory BitFieldProto_BitResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BitFieldProto_BitResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BitFieldProto.BitResponse',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'ipfs.core.data_structures'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'value')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BitFieldProto_BitResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BitFieldProto_BitResponse copyWith(
          void Function(BitFieldProto_BitResponse) updates) =>
      super.copyWith((message) => updates(message as BitFieldProto_BitResponse))
          as BitFieldProto_BitResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BitFieldProto_BitResponse create() => BitFieldProto_BitResponse._();
  @$core.override
  BitFieldProto_BitResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BitFieldProto_BitResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BitFieldProto_BitResponse>(create);
  static BitFieldProto_BitResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get value => $_getBF(0);
  @$pb.TagNumber(1)
  set value($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => $_clearField(1);
}

class BitFieldProto extends $pb.GeneratedMessage {
  factory BitFieldProto({
    $core.List<$core.int>? bits,
    $core.int? size,
  }) {
    final result = create();
    if (bits != null) result.bits = bits;
    if (size != null) result.size = size;
    return result;
  }

  BitFieldProto._();

  factory BitFieldProto.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BitFieldProto.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BitFieldProto',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'ipfs.core.data_structures'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'bits', $pb.PbFieldType.OY)
    ..aI(2, _omitFieldNames ? '' : 'size')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BitFieldProto clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BitFieldProto copyWith(void Function(BitFieldProto) updates) =>
      super.copyWith((message) => updates(message as BitFieldProto))
          as BitFieldProto;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BitFieldProto create() => BitFieldProto._();
  @$core.override
  BitFieldProto createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BitFieldProto getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BitFieldProto>(create);
  static BitFieldProto? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get bits => $_getN(0);
  @$pb.TagNumber(1)
  set bits($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBits() => $_has(0);
  @$pb.TagNumber(1)
  void clearBits() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get size => $_getIZ(1);
  @$pb.TagNumber(2)
  set size($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSize() => $_has(1);
  @$pb.TagNumber(2)
  void clearSize() => $_clearField(2);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');

