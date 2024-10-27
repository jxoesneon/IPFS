//
//  Generated code. Do not modify.
//  source: node.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'cid.pb.dart' as $0;
import 'link.pb.dart' as $1;
import 'node_type.pbenum.dart' as $2;

/// Represents a node in the IPFS Merkle DAG.
class Node extends $pb.GeneratedMessage {
  factory Node({
    $0.CIDProto? cid,
    $core.Iterable<$1.PBLink>? links,
    $core.List<$core.int>? data,
    $2.NodeTypeProto? type,
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
  Node._() : super();
  factory Node.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Node.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Node', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.data_structures'), createEmptyInstance: create)
    ..aOM<$0.CIDProto>(1, _omitFieldNames ? '' : 'cid', subBuilder: $0.CIDProto.create)
    ..pc<$1.PBLink>(2, _omitFieldNames ? '' : 'links', $pb.PbFieldType.PM, subBuilder: $1.PBLink.create)
    ..a<$core.List<$core.int>>(3, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..e<$2.NodeTypeProto>(4, _omitFieldNames ? '' : 'type', $pb.PbFieldType.OE, defaultOrMaker: $2.NodeTypeProto.REGULAR, valueOf: $2.NodeTypeProto.valueOf, enumValues: $2.NodeTypeProto.values)
    ..a<$fixnum.Int64>(5, _omitFieldNames ? '' : 'size', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
    ..aInt64(6, _omitFieldNames ? '' : 'timestamp')
    ..m<$core.String, $core.String>(7, _omitFieldNames ? '' : 'metadata', entryClassName: 'Node.MetadataEntry', keyFieldType: $pb.PbFieldType.OS, valueFieldType: $pb.PbFieldType.OS, packageName: const $pb.PackageName('ipfs.core.data_structures'))
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  Node clone() => Node()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  Node copyWith(void Function(Node) updates) => super.copyWith((message) => updates(message as Node)) as Node;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Node create() => Node._();
  Node createEmptyInstance() => create();
  static $pb.PbList<Node> createRepeated() => $pb.PbList<Node>();
  @$core.pragma('dart2js:noInline')
  static Node getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Node>(create);
  static Node? _defaultInstance;

  /// The CID (Content Identifier) of the node.
  @$pb.TagNumber(1)
  $0.CIDProto get cid => $_getN(0);
  @$pb.TagNumber(1)
  set cid($0.CIDProto v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasCid() => $_has(0);
  @$pb.TagNumber(1)
  void clearCid() => clearField(1);
  @$pb.TagNumber(1)
  $0.CIDProto ensureCid() => $_ensure(0);

  /// Links to other nodes in the DAG.
  @$pb.TagNumber(2)
  $core.List<$1.PBLink> get links => $_getList(1);

  /// The data stored in the node (optional).
  @$pb.TagNumber(3)
  $core.List<$core.int> get data => $_getN(2);
  @$pb.TagNumber(3)
  set data($core.List<$core.int> v) { $_setBytes(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasData() => $_has(2);
  @$pb.TagNumber(3)
  void clearData() => clearField(3);

  /// The type of the node (e.g., regular, bootstrap, etc.).
  @$pb.TagNumber(4)
  $2.NodeTypeProto get type => $_getN(3);
  @$pb.TagNumber(4)
  set type($2.NodeTypeProto v) { setField(4, v); }
  @$pb.TagNumber(4)
  $core.bool hasType() => $_has(3);
  @$pb.TagNumber(4)
  void clearType() => clearField(4);

  /// The size of the node's data.
  @$pb.TagNumber(5)
  $fixnum.Int64 get size => $_getI64(4);
  @$pb.TagNumber(5)
  set size($fixnum.Int64 v) { $_setInt64(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasSize() => $_has(4);
  @$pb.TagNumber(5)
  void clearSize() => clearField(5);

  /// The timestamp of when the node was created or last modified.
  @$pb.TagNumber(6)
  $fixnum.Int64 get timestamp => $_getI64(5);
  @$pb.TagNumber(6)
  set timestamp($fixnum.Int64 v) { $_setInt64(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasTimestamp() => $_has(5);
  @$pb.TagNumber(6)
  void clearTimestamp() => clearField(6);

  /// Optional metadata associated with the node.
  @$pb.TagNumber(7)
  $core.Map<$core.String, $core.String> get metadata => $_getMap(6);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
