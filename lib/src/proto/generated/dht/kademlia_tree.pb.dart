// This is a generated file - do not edit.
//
// Generated from dht/kademlia_tree.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'kademlia_node.pb.dart' as $0;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class KademliaTree extends $pb.GeneratedMessage {
  factory KademliaTree({
    $0.KademliaNode? localNode,
    $core.Iterable<KademliaBucket>? buckets,
  }) {
    final result = create();
    if (localNode != null) result.localNode = localNode;
    if (buckets != null) result.buckets.addAll(buckets);
    return result;
  }

  KademliaTree._();

  factory KademliaTree.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory KademliaTree.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'KademliaTree',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.kademlia_tree'),
      createEmptyInstance: create)
    ..aOM<$0.KademliaNode>(1, _omitFieldNames ? '' : 'localNode',
        subBuilder: $0.KademliaNode.create)
    ..pPM<KademliaBucket>(2, _omitFieldNames ? '' : 'buckets', subBuilder: KademliaBucket.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KademliaTree clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KademliaTree copyWith(void Function(KademliaTree) updates) =>
      super.copyWith((message) => updates(message as KademliaTree)) as KademliaTree;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static KademliaTree create() => KademliaTree._();
  @$core.override
  KademliaTree createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static KademliaTree getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<KademliaTree>(create);
  static KademliaTree? _defaultInstance;

  @$pb.TagNumber(1)
  $0.KademliaNode get localNode => $_getN(0);
  @$pb.TagNumber(1)
  set localNode($0.KademliaNode value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasLocalNode() => $_has(0);
  @$pb.TagNumber(1)
  void clearLocalNode() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.KademliaNode ensureLocalNode() => $_ensure(0);

  @$pb.TagNumber(2)
  $pb.PbList<KademliaBucket> get buckets => $_getList(1);
}

class KademliaBucket extends $pb.GeneratedMessage {
  factory KademliaBucket({
    $core.Iterable<$0.KademliaNode>? nodes,
  }) {
    final result = create();
    if (nodes != null) result.nodes.addAll(nodes);
    return result;
  }

  KademliaBucket._();

  factory KademliaBucket.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory KademliaBucket.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'KademliaBucket',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.kademlia_tree'),
      createEmptyInstance: create)
    ..pPM<$0.KademliaNode>(1, _omitFieldNames ? '' : 'nodes', subBuilder: $0.KademliaNode.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KademliaBucket clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KademliaBucket copyWith(void Function(KademliaBucket) updates) =>
      super.copyWith((message) => updates(message as KademliaBucket)) as KademliaBucket;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static KademliaBucket create() => KademliaBucket._();
  @$core.override
  KademliaBucket createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static KademliaBucket getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<KademliaBucket>(create);
  static KademliaBucket? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$0.KademliaNode> get nodes => $_getList(0);
}

const $core.bool _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
