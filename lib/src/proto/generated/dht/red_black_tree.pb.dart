// This is a generated file - do not edit.
//
// Generated from dht/red_black_tree.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'common_red_black_tree.pb.dart' as $0;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

/// Represents a node in a Red-Black Tree.
class RedBlackTreeNode extends $pb.GeneratedMessage {
  factory RedBlackTreeNode({
    $0.K_PeerId? key,
    $0.V_PeerInfo? value,
    $0.NodeColor? color,
    RedBlackTreeNode? left,
    RedBlackTreeNode? right,
  }) {
    final result = create();
    if (key != null) result.key = key;
    if (value != null) result.value = value;
    if (color != null) result.color = color;
    if (left != null) result.left = left;
    if (right != null) result.right = right;
    return result;
  }

  RedBlackTreeNode._();

  factory RedBlackTreeNode.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RedBlackTreeNode.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RedBlackTreeNode',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.red_black_tree'),
      createEmptyInstance: create)
    ..aOM<$0.K_PeerId>(1, _omitFieldNames ? '' : 'key', subBuilder: $0.K_PeerId.create)
    ..aOM<$0.V_PeerInfo>(2, _omitFieldNames ? '' : 'value', subBuilder: $0.V_PeerInfo.create)
    ..aE<$0.NodeColor>(3, _omitFieldNames ? '' : 'color', enumValues: $0.NodeColor.values)
    ..aOM<RedBlackTreeNode>(4, _omitFieldNames ? '' : 'left', subBuilder: RedBlackTreeNode.create)
    ..aOM<RedBlackTreeNode>(5, _omitFieldNames ? '' : 'right', subBuilder: RedBlackTreeNode.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RedBlackTreeNode clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RedBlackTreeNode copyWith(void Function(RedBlackTreeNode) updates) =>
      super.copyWith((message) => updates(message as RedBlackTreeNode)) as RedBlackTreeNode;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RedBlackTreeNode create() => RedBlackTreeNode._();
  @$core.override
  RedBlackTreeNode createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RedBlackTreeNode getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RedBlackTreeNode>(create);
  static RedBlackTreeNode? _defaultInstance;

  /// The key associated with this node.
  @$pb.TagNumber(1)
  $0.K_PeerId get key => $_getN(0);
  @$pb.TagNumber(1)
  set key($0.K_PeerId value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.K_PeerId ensureKey() => $_ensure(0);

  /// The value associated with this node.
  @$pb.TagNumber(2)
  $0.V_PeerInfo get value => $_getN(1);
  @$pb.TagNumber(2)
  set value($0.V_PeerInfo value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearValue() => $_clearField(2);
  @$pb.TagNumber(2)
  $0.V_PeerInfo ensureValue() => $_ensure(1);

  /// The color of this node (RED or BLACK).
  @$pb.TagNumber(3)
  $0.NodeColor get color => $_getN(2);
  @$pb.TagNumber(3)
  set color($0.NodeColor value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasColor() => $_has(2);
  @$pb.TagNumber(3)
  void clearColor() => $_clearField(3);

  /// The left child of this node.
  @$pb.TagNumber(4)
  RedBlackTreeNode get left => $_getN(3);
  @$pb.TagNumber(4)
  set left(RedBlackTreeNode value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasLeft() => $_has(3);
  @$pb.TagNumber(4)
  void clearLeft() => $_clearField(4);
  @$pb.TagNumber(4)
  RedBlackTreeNode ensureLeft() => $_ensure(3);

  /// The right child of this node.
  @$pb.TagNumber(5)
  RedBlackTreeNode get right => $_getN(4);
  @$pb.TagNumber(5)
  set right(RedBlackTreeNode value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasRight() => $_has(4);
  @$pb.TagNumber(5)
  void clearRight() => $_clearField(5);
  @$pb.TagNumber(5)
  RedBlackTreeNode ensureRight() => $_ensure(4);
}

const $core.bool _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
