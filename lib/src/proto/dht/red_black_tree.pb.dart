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

class RedBlackTreeNode extends $pb.GeneratedMessage {
  factory RedBlackTreeNode({
    $core.int? k,
    $0.Node? v,
    $0.NodeColor? color,
    RedBlackTreeNode? leftChild,
    RedBlackTreeNode? rightChild,
  }) {
    final $result = create();
    if (k != null) {
      $result.k = k;
    }
    if (v != null) {
      $result.v = v;
    }
    if (color != null) {
      $result.color = color;
    }
    if (leftChild != null) {
      $result.leftChild = leftChild;
    }
    if (rightChild != null) {
      $result.rightChild = rightChild;
    }
    return $result;
  }
  RedBlackTreeNode._() : super();
  factory RedBlackTreeNode.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RedBlackTreeNode.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RedBlackTreeNode', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.red_black_tree'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'K', $pb.PbFieldType.O3, protoName: 'K')
    ..aOM<$0.Node>(2, _omitFieldNames ? '' : 'V', protoName: 'V', subBuilder: $0.Node.create)
    ..e<$0.NodeColor>(3, _omitFieldNames ? '' : 'color', $pb.PbFieldType.OE, defaultOrMaker: $0.NodeColor.RED, valueOf: $0.NodeColor.valueOf, enumValues: $0.NodeColor.values)
    ..aOM<RedBlackTreeNode>(4, _omitFieldNames ? '' : 'leftChild', subBuilder: RedBlackTreeNode.create)
    ..aOM<RedBlackTreeNode>(5, _omitFieldNames ? '' : 'rightChild', subBuilder: RedBlackTreeNode.create)
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

  @$pb.TagNumber(1)
  $core.int get k => $_getIZ(0);
  @$pb.TagNumber(1)
  set k($core.int v) { $_setSignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasK() => $_has(0);
  @$pb.TagNumber(1)
  void clearK() => clearField(1);

  @$pb.TagNumber(2)
  $0.Node get v => $_getN(1);
  @$pb.TagNumber(2)
  set v($0.Node v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasV() => $_has(1);
  @$pb.TagNumber(2)
  void clearV() => clearField(2);
  @$pb.TagNumber(2)
  $0.Node ensureV() => $_ensure(1);

  @$pb.TagNumber(3)
  $0.NodeColor get color => $_getN(2);
  @$pb.TagNumber(3)
  set color($0.NodeColor v) { setField(3, v); }
  @$pb.TagNumber(3)
  $core.bool hasColor() => $_has(2);
  @$pb.TagNumber(3)
  void clearColor() => clearField(3);

  @$pb.TagNumber(4)
  RedBlackTreeNode get leftChild => $_getN(3);
  @$pb.TagNumber(4)
  set leftChild(RedBlackTreeNode v) { setField(4, v); }
  @$pb.TagNumber(4)
  $core.bool hasLeftChild() => $_has(3);
  @$pb.TagNumber(4)
  void clearLeftChild() => clearField(4);
  @$pb.TagNumber(4)
  RedBlackTreeNode ensureLeftChild() => $_ensure(3);

  @$pb.TagNumber(5)
  RedBlackTreeNode get rightChild => $_getN(4);
  @$pb.TagNumber(5)
  set rightChild(RedBlackTreeNode v) { setField(5, v); }
  @$pb.TagNumber(5)
  $core.bool hasRightChild() => $_has(4);
  @$pb.TagNumber(5)
  void clearRightChild() => clearField(5);
  @$pb.TagNumber(5)
  RedBlackTreeNode ensureRightChild() => $_ensure(4);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
