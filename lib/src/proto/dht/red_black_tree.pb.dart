//
//  Generated code. Do not modify.
//  source: red_black_tree.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'common_tree.pb.dart' as $0;
import 'common_tree.pbenum.dart' as $0;

/// Represents a node in a Red-Black Tree.
class RedBlackTreeNode extends $pb.GeneratedMessage {
  factory RedBlackTreeNode({
    $0.K_PeerId? key,
    $0.V_PeerInfo? value,
    $0.NodeColor? color,
    RedBlackTreeNode? left,
    RedBlackTreeNode? right,
  }) {
    final $result = create();
    if (key != null) {
      $result.key = key;
    }
    if (value != null) {
      $result.value = value;
    }
    if (color != null) {
      $result.color = color;
    }
    if (left != null) {
      $result.left = left;
    }
    if (right != null) {
      $result.right = right;
    }
    return $result;
  }
  RedBlackTreeNode._() : super();
  factory RedBlackTreeNode.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RedBlackTreeNode.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RedBlackTreeNode', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.red_black_tree'), createEmptyInstance: create)
    ..aOM<$0.K_PeerId>(1, _omitFieldNames ? '' : 'key', subBuilder: $0.K_PeerId.create)
    ..aOM<$0.V_PeerInfo>(2, _omitFieldNames ? '' : 'value', subBuilder: $0.V_PeerInfo.create)
    ..e<$0.NodeColor>(3, _omitFieldNames ? '' : 'color', $pb.PbFieldType.OE, defaultOrMaker: $0.NodeColor.RED, valueOf: $0.NodeColor.valueOf, enumValues: $0.NodeColor.values)
    ..aOM<RedBlackTreeNode>(4, _omitFieldNames ? '' : 'left', subBuilder: RedBlackTreeNode.create)
    ..aOM<RedBlackTreeNode>(5, _omitFieldNames ? '' : 'right', subBuilder: RedBlackTreeNode.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RedBlackTreeNode clone() => RedBlackTreeNode()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RedBlackTreeNode copyWith(void Function(RedBlackTreeNode) updates) => super.copyWith((message) => updates(message as RedBlackTreeNode)) as RedBlackTreeNode;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RedBlackTreeNode create() => RedBlackTreeNode._();
  RedBlackTreeNode createEmptyInstance() => create();
  static $pb.PbList<RedBlackTreeNode> createRepeated() => $pb.PbList<RedBlackTreeNode>();
  @$core.pragma('dart2js:noInline')
  static RedBlackTreeNode getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RedBlackTreeNode>(create);
  static RedBlackTreeNode? _defaultInstance;

  /// The key associated with this node.
  @$pb.TagNumber(1)
  $0.K_PeerId get key => $_getN(0);
  @$pb.TagNumber(1)
  set key($0.K_PeerId v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => clearField(1);
  @$pb.TagNumber(1)
  $0.K_PeerId ensureKey() => $_ensure(0);

  /// The value associated with this node.
  @$pb.TagNumber(2)
  $0.V_PeerInfo get value => $_getN(1);
  @$pb.TagNumber(2)
  set value($0.V_PeerInfo v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearValue() => clearField(2);
  @$pb.TagNumber(2)
  $0.V_PeerInfo ensureValue() => $_ensure(1);

  /// The color of this node (RED or BLACK).
  @$pb.TagNumber(3)
  $0.NodeColor get color => $_getN(2);
  @$pb.TagNumber(3)
  set color($0.NodeColor v) { setField(3, v); }
  @$pb.TagNumber(3)
  $core.bool hasColor() => $_has(2);
  @$pb.TagNumber(3)
  void clearColor() => clearField(3);

  /// The left child of this node.
  @$pb.TagNumber(4)
  RedBlackTreeNode get left => $_getN(3);
  @$pb.TagNumber(4)
  set left(RedBlackTreeNode v) { setField(4, v); }
  @$pb.TagNumber(4)
  $core.bool hasLeft() => $_has(3);
  @$pb.TagNumber(4)
  void clearLeft() => clearField(4);
  @$pb.TagNumber(4)
  RedBlackTreeNode ensureLeft() => $_ensure(3);

  /// The right child of this node.
  @$pb.TagNumber(5)
  RedBlackTreeNode get right => $_getN(4);
  @$pb.TagNumber(5)
  set right(RedBlackTreeNode v) { setField(5, v); }
  @$pb.TagNumber(5)
  $core.bool hasRight() => $_has(4);
  @$pb.TagNumber(5)
  void clearRight() => clearField(5);
  @$pb.TagNumber(5)
  RedBlackTreeNode ensureRight() => $_ensure(4);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
