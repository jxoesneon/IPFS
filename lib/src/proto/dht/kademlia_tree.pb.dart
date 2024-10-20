//
//  Generated code. Do not modify.
//  source: kademlia_tree.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'common_tree.pb.dart' as $0;
import 'red_black_tree.pb.dart' as $1;

class KademliaNode extends $pb.GeneratedMessage {
  factory KademliaNode({
    $0.PeerId? peerId,
    $core.int? distance,
    $1.RedBlackTreeNode? children,
  }) {
    final $result = create();
    if (peerId != null) {
      $result.peerId = peerId;
    }
    if (distance != null) {
      $result.distance = distance;
    }
    if (children != null) {
      $result.children = children;
    }
    return $result;
  }
  KademliaNode._() : super();
  factory KademliaNode.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory KademliaNode.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'KademliaNode', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.kademlia_tree'), createEmptyInstance: create)
    ..aOM<$0.PeerId>(1, _omitFieldNames ? '' : 'peerId', subBuilder: $0.PeerId.create)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'distance', $pb.PbFieldType.O3)
    ..aOM<$1.RedBlackTreeNode>(3, _omitFieldNames ? '' : 'children', subBuilder: $1.RedBlackTreeNode.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  KademliaNode clone() => KademliaNode()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  KademliaNode copyWith(void Function(KademliaNode) updates) => super.copyWith((message) => updates(message as KademliaNode)) as KademliaNode;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static KademliaNode create() => KademliaNode._();
  KademliaNode createEmptyInstance() => create();
  static $pb.PbList<KademliaNode> createRepeated() => $pb.PbList<KademliaNode>();
  @$core.pragma('dart2js:noInline')
  static KademliaNode getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<KademliaNode>(create);
  static KademliaNode? _defaultInstance;

  @$pb.TagNumber(1)
  $0.PeerId get peerId => $_getN(0);
  @$pb.TagNumber(1)
  set peerId($0.PeerId v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasPeerId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerId() => clearField(1);
  @$pb.TagNumber(1)
  $0.PeerId ensurePeerId() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.int get distance => $_getIZ(1);
  @$pb.TagNumber(2)
  set distance($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasDistance() => $_has(1);
  @$pb.TagNumber(2)
  void clearDistance() => clearField(2);

  /// Using RedBlackTree from red_black_tree.proto to store child nodes
  @$pb.TagNumber(3)
  $1.RedBlackTreeNode get children => $_getN(2);
  @$pb.TagNumber(3)
  set children($1.RedBlackTreeNode v) { setField(3, v); }
  @$pb.TagNumber(3)
  $core.bool hasChildren() => $_has(2);
  @$pb.TagNumber(3)
  void clearChildren() => clearField(3);
  @$pb.TagNumber(3)
  $1.RedBlackTreeNode ensureChildren() => $_ensure(2);
}

class KademliaBucket extends $pb.GeneratedMessage {
  factory KademliaBucket({
    $1.RedBlackTreeNode? tree,
  }) {
    final $result = create();
    if (tree != null) {
      $result.tree = tree;
    }
    return $result;
  }
  KademliaBucket._() : super();
  factory KademliaBucket.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory KademliaBucket.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'KademliaBucket', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.kademlia_tree'), createEmptyInstance: create)
    ..aOM<$1.RedBlackTreeNode>(1, _omitFieldNames ? '' : 'tree', subBuilder: $1.RedBlackTreeNode.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  KademliaBucket clone() => KademliaBucket()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  KademliaBucket copyWith(void Function(KademliaBucket) updates) => super.copyWith((message) => updates(message as KademliaBucket)) as KademliaBucket;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static KademliaBucket create() => KademliaBucket._();
  KademliaBucket createEmptyInstance() => create();
  static $pb.PbList<KademliaBucket> createRepeated() => $pb.PbList<KademliaBucket>();
  @$core.pragma('dart2js:noInline')
  static KademliaBucket getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<KademliaBucket>(create);
  static KademliaBucket? _defaultInstance;

  /// Using RedBlackTree from red_black_tree.proto to represent the bucket
  @$pb.TagNumber(1)
  $1.RedBlackTreeNode get tree => $_getN(0);
  @$pb.TagNumber(1)
  set tree($1.RedBlackTreeNode v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasTree() => $_has(0);
  @$pb.TagNumber(1)
  void clearTree() => clearField(1);
  @$pb.TagNumber(1)
  $1.RedBlackTreeNode ensureTree() => $_ensure(0);
}

class KademliaTree extends $pb.GeneratedMessage {
  factory KademliaTree({
    KademliaNode? localNode,
    $core.Iterable<KademliaBucket>? buckets,
  }) {
    final $result = create();
    if (localNode != null) {
      $result.localNode = localNode;
    }
    if (buckets != null) {
      $result.buckets.addAll(buckets);
    }
    return $result;
  }
  KademliaTree._() : super();
  factory KademliaTree.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory KademliaTree.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'KademliaTree', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.kademlia_tree'), createEmptyInstance: create)
    ..aOM<KademliaNode>(1, _omitFieldNames ? '' : 'localNode', subBuilder: KademliaNode.create)
    ..pc<KademliaBucket>(2, _omitFieldNames ? '' : 'buckets', $pb.PbFieldType.PM, subBuilder: KademliaBucket.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  KademliaTree clone() => KademliaTree()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  KademliaTree copyWith(void Function(KademliaTree) updates) => super.copyWith((message) => updates(message as KademliaTree)) as KademliaTree;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static KademliaTree create() => KademliaTree._();
  KademliaTree createEmptyInstance() => create();
  static $pb.PbList<KademliaTree> createRepeated() => $pb.PbList<KademliaTree>();
  @$core.pragma('dart2js:noInline')
  static KademliaTree getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<KademliaTree>(create);
  static KademliaTree? _defaultInstance;

  @$pb.TagNumber(1)
  KademliaNode get localNode => $_getN(0);
  @$pb.TagNumber(1)
  set localNode(KademliaNode v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasLocalNode() => $_has(0);
  @$pb.TagNumber(1)
  void clearLocalNode() => clearField(1);
  @$pb.TagNumber(1)
  KademliaNode ensureLocalNode() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.List<KademliaBucket> get buckets => $_getList(1);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
