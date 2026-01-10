//
//  Generated code. Do not modify.
//  source: dht/kademlia_tree.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'kademlia_node.pb.dart' as $10;

class KademliaTree extends $pb.GeneratedMessage {
  factory KademliaTree({
    $10.KademliaNode? localNode,
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
    ..aOM<$10.KademliaNode>(1, _omitFieldNames ? '' : 'localNode', subBuilder: $10.KademliaNode.create)
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
  $10.KademliaNode get localNode => $_getN(0);
  @$pb.TagNumber(1)
  set localNode($10.KademliaNode v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasLocalNode() => $_has(0);
  @$pb.TagNumber(1)
  void clearLocalNode() => clearField(1);
  @$pb.TagNumber(1)
  $10.KademliaNode ensureLocalNode() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.List<KademliaBucket> get buckets => $_getList(1);
}

class KademliaBucket extends $pb.GeneratedMessage {
  factory KademliaBucket({
    $core.Iterable<$10.KademliaNode>? nodes,
  }) {
    final $result = create();
    if (nodes != null) {
      $result.nodes.addAll(nodes);
    }
    return $result;
  }
  KademliaBucket._() : super();
  factory KademliaBucket.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory KademliaBucket.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'KademliaBucket', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.kademlia_tree'), createEmptyInstance: create)
    ..pc<$10.KademliaNode>(1, _omitFieldNames ? '' : 'nodes', $pb.PbFieldType.PM, subBuilder: $10.KademliaNode.create)
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

  @$pb.TagNumber(1)
  $core.List<$10.KademliaNode> get nodes => $_getList(0);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
