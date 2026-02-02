// This is a generated file - do not edit.
//
// Generated from core/block.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'cid.pb.dart' as $0;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class BlockProto extends $pb.GeneratedMessage {
  factory BlockProto({
    $core.List<$core.int>? data,
    $0.IPFSCIDProto? cid,
    $core.String? format,
  }) {
    final result = create();
    if (data != null) result.data = data;
    if (cid != null) result.cid = cid;
    if (format != null) result.format = format;
    return result;
  }

  BlockProto._();

  factory BlockProto.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BlockProto.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BlockProto',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'ipfs.core.data_structures'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..aOM<$0.IPFSCIDProto>(2, _omitFieldNames ? '' : 'cid',
        subBuilder: $0.IPFSCIDProto.create)
    ..aOS(3, _omitFieldNames ? '' : 'format')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BlockProto clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BlockProto copyWith(void Function(BlockProto) updates) =>
      super.copyWith((message) => updates(message as BlockProto)) as BlockProto;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BlockProto create() => BlockProto._();
  @$core.override
  BlockProto createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BlockProto getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BlockProto>(create);
  static BlockProto? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get data => $_getN(0);
  @$pb.TagNumber(1)
  set data($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasData() => $_has(0);
  @$pb.TagNumber(1)
  void clearData() => $_clearField(1);

  @$pb.TagNumber(2)
  $0.IPFSCIDProto get cid => $_getN(1);
  @$pb.TagNumber(2)
  set cid($0.IPFSCIDProto value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasCid() => $_has(1);
  @$pb.TagNumber(2)
  void clearCid() => $_clearField(2);
  @$pb.TagNumber(2)
  $0.IPFSCIDProto ensureCid() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.String get format => $_getSZ(2);
  @$pb.TagNumber(3)
  set format($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFormat() => $_has(2);
  @$pb.TagNumber(3)
  void clearFormat() => $_clearField(3);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
