// This is a generated file - do not edit.
//
// Generated from core/blockstore.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'block.pb.dart' as $0;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

/// Response message for adding a block
class AddBlockResponse extends $pb.GeneratedMessage {
  factory AddBlockResponse({
    $core.bool? success,
    $core.String? message,
  }) {
    final result = create();
    if (success != null) result.success = success;
    if (message != null) result.message = message;
    return result;
  }

  AddBlockResponse._();

  factory AddBlockResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AddBlockResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AddBlockResponse',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'ipfs.core.data_structures'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddBlockResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddBlockResponse copyWith(void Function(AddBlockResponse) updates) =>
      super.copyWith((message) => updates(message as AddBlockResponse))
          as AddBlockResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AddBlockResponse create() => AddBlockResponse._();
  @$core.override
  AddBlockResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AddBlockResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AddBlockResponse>(create);
  static AddBlockResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => $_clearField(2);
}

/// Response message for retrieving a block
class GetBlockResponse extends $pb.GeneratedMessage {
  factory GetBlockResponse({
    $0.BlockProto? block,
    $core.bool? found,
  }) {
    final result = create();
    if (block != null) result.block = block;
    if (found != null) result.found = found;
    return result;
  }

  GetBlockResponse._();

  factory GetBlockResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetBlockResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetBlockResponse',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'ipfs.core.data_structures'),
      createEmptyInstance: create)
    ..aOM<$0.BlockProto>(1, _omitFieldNames ? '' : 'block',
        subBuilder: $0.BlockProto.create)
    ..aOB(2, _omitFieldNames ? '' : 'found')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetBlockResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetBlockResponse copyWith(void Function(GetBlockResponse) updates) =>
      super.copyWith((message) => updates(message as GetBlockResponse))
          as GetBlockResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetBlockResponse create() => GetBlockResponse._();
  @$core.override
  GetBlockResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetBlockResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetBlockResponse>(create);
  static GetBlockResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $0.BlockProto get block => $_getN(0);
  @$pb.TagNumber(1)
  set block($0.BlockProto value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasBlock() => $_has(0);
  @$pb.TagNumber(1)
  void clearBlock() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.BlockProto ensureBlock() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.bool get found => $_getBF(1);
  @$pb.TagNumber(2)
  set found($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFound() => $_has(1);
  @$pb.TagNumber(2)
  void clearFound() => $_clearField(2);
}

/// Response message for removing a block
class RemoveBlockResponse extends $pb.GeneratedMessage {
  factory RemoveBlockResponse({
    $core.bool? success,
    $core.String? message,
  }) {
    final result = create();
    if (success != null) result.success = success;
    if (message != null) result.message = message;
    return result;
  }

  RemoveBlockResponse._();

  factory RemoveBlockResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RemoveBlockResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RemoveBlockResponse',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'ipfs.core.data_structures'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveBlockResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveBlockResponse copyWith(void Function(RemoveBlockResponse) updates) =>
      super.copyWith((message) => updates(message as RemoveBlockResponse))
          as RemoveBlockResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RemoveBlockResponse create() => RemoveBlockResponse._();
  @$core.override
  RemoveBlockResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RemoveBlockResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoveBlockResponse>(create);
  static RemoveBlockResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => $_clearField(2);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
