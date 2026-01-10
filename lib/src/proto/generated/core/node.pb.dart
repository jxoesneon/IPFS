//
//  Generated code. Do not modify.
//  source: core/node.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'cid.pb.dart' as $2;
import 'dag.pb.dart' as $5;
import 'node_type.pbenum.dart' as $4;

class NodeProto extends $pb.GeneratedMessage {
  factory NodeProto({
    $2.IPFSCIDProto? cid,
    $core.Iterable<$5.PBLink>? links,
    $core.List<$core.int>? data,
    $4.NodeTypeProto? type,
    $fixnum.Int64? size,
    $fixnum.Int64? timestamp,
    $core.Map<$core.String, $core.String>? metadata,
  }) {
    final $result = create();
    if (cid != null) {
      $result.cid = cid;
    }
    if (links != null) {
      $result.links.addAll(links);
    }
    if (data != null) {
      $result.data = data;
    }
    if (type != null) {
      $result.type = type;
    }
    if (size != null) {
      $result.size = size;
    }
    if (timestamp != null) {
      $result.timestamp = timestamp;
    }
    if (metadata != null) {
      $result.metadata.addAll(metadata);
    }
    return $result;
  }
  NodeProto._() : super();
  factory NodeProto.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory NodeProto.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'NodeProto', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.data_structures'), createEmptyInstance: create)
    ..aOM<$2.IPFSCIDProto>(1, _omitFieldNames ? '' : 'cid', subBuilder: $2.IPFSCIDProto.create)
    ..pc<$5.PBLink>(2, _omitFieldNames ? '' : 'links', $pb.PbFieldType.PM, subBuilder: $5.PBLink.create)
    ..a<$core.List<$core.int>>(3, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..e<$4.NodeTypeProto>(4, _omitFieldNames ? '' : 'type', $pb.PbFieldType.OE, defaultOrMaker: $4.NodeTypeProto.NODE_TYPE_UNSPECIFIED, valueOf: $4.NodeTypeProto.valueOf, enumValues: $4.NodeTypeProto.values)
    ..a<$fixnum.Int64>(5, _omitFieldNames ? '' : 'size', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
    ..aInt64(6, _omitFieldNames ? '' : 'timestamp')
    ..m<$core.String, $core.String>(7, _omitFieldNames ? '' : 'metadata', entryClassName: 'NodeProto.MetadataEntry', keyFieldType: $pb.PbFieldType.OS, valueFieldType: $pb.PbFieldType.OS, packageName: const $pb.PackageName('ipfs.core.data_structures'))
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  NodeProto clone() => NodeProto()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  NodeProto copyWith(void Function(NodeProto) updates) => super.copyWith((message) => updates(message as NodeProto)) as NodeProto;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NodeProto create() => NodeProto._();
  NodeProto createEmptyInstance() => create();
  static $pb.PbList<NodeProto> createRepeated() => $pb.PbList<NodeProto>();
  @$core.pragma('dart2js:noInline')
  static NodeProto getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<NodeProto>(create);
  static NodeProto? _defaultInstance;

  @$pb.TagNumber(1)
  $2.IPFSCIDProto get cid => $_getN(0);
  @$pb.TagNumber(1)
  set cid($2.IPFSCIDProto v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasCid() => $_has(0);
  @$pb.TagNumber(1)
  void clearCid() => clearField(1);
  @$pb.TagNumber(1)
  $2.IPFSCIDProto ensureCid() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.List<$5.PBLink> get links => $_getList(1);

  @$pb.TagNumber(3)
  $core.List<$core.int> get data => $_getN(2);
  @$pb.TagNumber(3)
  set data($core.List<$core.int> v) { $_setBytes(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasData() => $_has(2);
  @$pb.TagNumber(3)
  void clearData() => clearField(3);

  @$pb.TagNumber(4)
  $4.NodeTypeProto get type => $_getN(3);
  @$pb.TagNumber(4)
  set type($4.NodeTypeProto v) { setField(4, v); }
  @$pb.TagNumber(4)
  $core.bool hasType() => $_has(3);
  @$pb.TagNumber(4)
  void clearType() => clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get size => $_getI64(4);
  @$pb.TagNumber(5)
  set size($fixnum.Int64 v) { $_setInt64(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasSize() => $_has(4);
  @$pb.TagNumber(5)
  void clearSize() => clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get timestamp => $_getI64(5);
  @$pb.TagNumber(6)
  set timestamp($fixnum.Int64 v) { $_setInt64(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasTimestamp() => $_has(5);
  @$pb.TagNumber(6)
  void clearTimestamp() => clearField(6);

  @$pb.TagNumber(7)
  $core.Map<$core.String, $core.String> get metadata => $_getMap(6);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
