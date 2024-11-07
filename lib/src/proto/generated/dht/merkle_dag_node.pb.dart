//
//  Generated code. Do not modify.
//  source: dht/merkle_dag_node.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import '../core/cid.pb.dart' as $3;
import '../core/link.pb.dart' as $4;

/// Represents a Merkle DAG node.
class MerkleDAGNode extends $pb.GeneratedMessage {
  factory MerkleDAGNode({
    $3.IPFSCIDProto? cid,
    $core.Iterable<$4.PBLink>? links,
    $core.List<$core.int>? data,
    $fixnum.Int64? size,
    $fixnum.Int64? timestamp,
    $core.Map<$core.String, $core.String>? metadata,
    $core.bool? isDirectory,
    $3.IPFSCIDProto? parentCid,
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
    if (size != null) {
      $result.size = size;
    }
    if (timestamp != null) {
      $result.timestamp = timestamp;
    }
    if (metadata != null) {
      $result.metadata.addAll(metadata);
    }
    if (isDirectory != null) {
      $result.isDirectory = isDirectory;
    }
    if (parentCid != null) {
      $result.parentCid = parentCid;
    }
    return $result;
  }
  MerkleDAGNode._() : super();
  factory MerkleDAGNode.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory MerkleDAGNode.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MerkleDAGNode',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'ipfs.core.data_structures'),
      createEmptyInstance: create)
    ..aOM<$3.IPFSCIDProto>(1, _omitFieldNames ? '' : 'cid',
        subBuilder: $3.IPFSCIDProto.create)
    ..pc<$4.PBLink>(2, _omitFieldNames ? '' : 'links', $pb.PbFieldType.PM,
        subBuilder: $4.PBLink.create)
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..a<$fixnum.Int64>(4, _omitFieldNames ? '' : 'size', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aInt64(5, _omitFieldNames ? '' : 'timestamp')
    ..m<$core.String, $core.String>(6, _omitFieldNames ? '' : 'metadata',
        entryClassName: 'MerkleDAGNode.MetadataEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('ipfs.core.data_structures'))
    ..aOB(7, _omitFieldNames ? '' : 'isDirectory')
    ..aOM<$3.IPFSCIDProto>(8, _omitFieldNames ? '' : 'parentCid',
        subBuilder: $3.IPFSCIDProto.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  MerkleDAGNode clone() => MerkleDAGNode()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  MerkleDAGNode copyWith(void Function(MerkleDAGNode) updates) =>
      super.copyWith((message) => updates(message as MerkleDAGNode))
          as MerkleDAGNode;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MerkleDAGNode create() => MerkleDAGNode._();
  MerkleDAGNode createEmptyInstance() => create();
  static $pb.PbList<MerkleDAGNode> createRepeated() =>
      $pb.PbList<MerkleDAGNode>();
  @$core.pragma('dart2js:noInline')
  static MerkleDAGNode getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MerkleDAGNode>(create);
  static MerkleDAGNode? _defaultInstance;

  /// The CID (Content Identifier) of the node.
  @$pb.TagNumber(1)
  $3.IPFSCIDProto get cid => $_getN(0);
  @$pb.TagNumber(1)
  set cid($3.IPFSCIDProto v) {
    setField(1, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasCid() => $_has(0);
  @$pb.TagNumber(1)
  void clearCid() => clearField(1);
  @$pb.TagNumber(1)
  $3.IPFSCIDProto ensureCid() => $_ensure(0);

  /// Links to other nodes in the DAG.
  @$pb.TagNumber(2)
  $core.List<$4.PBLink> get links => $_getList(1);

  /// The data stored in the node (optional).
  @$pb.TagNumber(3)
  $core.List<$core.int> get data => $_getN(2);
  @$pb.TagNumber(3)
  set data($core.List<$core.int> v) {
    $_setBytes(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasData() => $_has(2);
  @$pb.TagNumber(3)
  void clearData() => clearField(3);

  /// The size of the node's data.
  @$pb.TagNumber(4)
  $fixnum.Int64 get size => $_getI64(3);
  @$pb.TagNumber(4)
  set size($fixnum.Int64 v) {
    $_setInt64(3, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasSize() => $_has(3);
  @$pb.TagNumber(4)
  void clearSize() => clearField(4);

  /// The timestamp of when the node was created or last modified.
  @$pb.TagNumber(5)
  $fixnum.Int64 get timestamp => $_getI64(4);
  @$pb.TagNumber(5)
  set timestamp($fixnum.Int64 v) {
    $_setInt64(4, v);
  }

  @$pb.TagNumber(5)
  $core.bool hasTimestamp() => $_has(4);
  @$pb.TagNumber(5)
  void clearTimestamp() => clearField(5);

  /// Optional metadata associated with the node.
  @$pb.TagNumber(6)
  $core.Map<$core.String, $core.String> get metadata => $_getMap(5);

  /// Indicates if the node is a directory.
  @$pb.TagNumber(7)
  $core.bool get isDirectory => $_getBF(6);
  @$pb.TagNumber(7)
  set isDirectory($core.bool v) {
    $_setBool(6, v);
  }

  @$pb.TagNumber(7)
  $core.bool hasIsDirectory() => $_has(6);
  @$pb.TagNumber(7)
  void clearIsDirectory() => clearField(7);

  /// Optional parent CID to represent the relationship in DAG.
  @$pb.TagNumber(8)
  $3.IPFSCIDProto get parentCid => $_getN(7);
  @$pb.TagNumber(8)
  set parentCid($3.IPFSCIDProto v) {
    setField(8, v);
  }

  @$pb.TagNumber(8)
  $core.bool hasParentCid() => $_has(7);
  @$pb.TagNumber(8)
  void clearParentCid() => clearField(8);
  @$pb.TagNumber(8)
  $3.IPFSCIDProto ensureParentCid() => $_ensure(7);
}

const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
