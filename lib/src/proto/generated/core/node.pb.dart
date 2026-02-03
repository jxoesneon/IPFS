// This is a generated file - do not edit.
//
// Generated from core/node.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'cid.pb.dart' as $0;
import 'dag.pb.dart' as $1;
import 'node_type.pbenum.dart' as $2;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class NodeProto extends $pb.GeneratedMessage {
  factory NodeProto({
    $0.IPFSCIDProto? cid,
    $core.Iterable<$1.PBLink>? links,
    $core.List<$core.int>? data,
    $2.NodeTypeProto? type,
    $fixnum.Int64? size,
    $fixnum.Int64? timestamp,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? metadata,
  }) {
    final result = create();
    if (cid != null) result.cid = cid;
    if (links != null) result.links.addAll(links);
    if (data != null) result.data = data;
    if (type != null) result.type = type;
    if (size != null) result.size = size;
    if (timestamp != null) result.timestamp = timestamp;
    if (metadata != null) result.metadata.addEntries(metadata);
    return result;
  }

  NodeProto._();

  factory NodeProto.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory NodeProto.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NodeProto',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'ipfs.core.data_structures'),
      createEmptyInstance: create)
    ..aOM<$0.IPFSCIDProto>(1, _omitFieldNames ? '' : 'cid',
        subBuilder: $0.IPFSCIDProto.create)
    ..pPM<$1.PBLink>(2, _omitFieldNames ? '' : 'links',
        subBuilder: $1.PBLink.create)
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..aE<$2.NodeTypeProto>(4, _omitFieldNames ? '' : 'type',
        enumValues: $2.NodeTypeProto.values)
    ..a<$fixnum.Int64>(5, _omitFieldNames ? '' : 'size', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aInt64(6, _omitFieldNames ? '' : 'timestamp')
    ..m<$core.String, $core.String>(7, _omitFieldNames ? '' : 'metadata',
        entryClassName: 'NodeProto.MetadataEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('ipfs.core.data_structures'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeProto clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeProto copyWith(void Function(NodeProto) updates) =>
      super.copyWith((message) => updates(message as NodeProto)) as NodeProto;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NodeProto create() => NodeProto._();
  @$core.override
  NodeProto createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static NodeProto getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<NodeProto>(create);
  static NodeProto? _defaultInstance;

  @$pb.TagNumber(1)
  $0.IPFSCIDProto get cid => $_getN(0);
  @$pb.TagNumber(1)
  set cid($0.IPFSCIDProto value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCid() => $_has(0);
  @$pb.TagNumber(1)
  void clearCid() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.IPFSCIDProto ensureCid() => $_ensure(0);

  @$pb.TagNumber(2)
  $pb.PbList<$1.PBLink> get links => $_getList(1);

  @$pb.TagNumber(3)
  $core.List<$core.int> get data => $_getN(2);
  @$pb.TagNumber(3)
  set data($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasData() => $_has(2);
  @$pb.TagNumber(3)
  void clearData() => $_clearField(3);

  @$pb.TagNumber(4)
  $2.NodeTypeProto get type => $_getN(3);
  @$pb.TagNumber(4)
  set type($2.NodeTypeProto value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasType() => $_has(3);
  @$pb.TagNumber(4)
  void clearType() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get size => $_getI64(4);
  @$pb.TagNumber(5)
  set size($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSize() => $_has(4);
  @$pb.TagNumber(5)
  void clearSize() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get timestamp => $_getI64(5);
  @$pb.TagNumber(6)
  set timestamp($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasTimestamp() => $_has(5);
  @$pb.TagNumber(6)
  void clearTimestamp() => $_clearField(6);

  @$pb.TagNumber(7)
  $pb.PbMap<$core.String, $core.String> get metadata => $_getMap(6);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
