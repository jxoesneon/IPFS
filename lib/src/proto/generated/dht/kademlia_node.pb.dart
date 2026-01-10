//
//  Generated code. Do not modify.
//  source: dht/kademlia_node.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'common_kademlia.pb.dart' as $9;

class KademliaNode extends $pb.GeneratedMessage {
  factory KademliaNode({
    $9.KademliaId? peerId,
    $core.int? distance,
    $9.KademliaId? associatedPeerId,
    $core.Iterable<KademliaNode>? children,
    $fixnum.Int64? lastSeen,
  }) {
    final $result = create();
    if (peerId != null) {
      $result.peerId = peerId;
    }
    if (distance != null) {
      $result.distance = distance;
    }
    if (associatedPeerId != null) {
      $result.associatedPeerId = associatedPeerId;
    }
    if (children != null) {
      $result.children.addAll(children);
    }
    if (lastSeen != null) {
      $result.lastSeen = lastSeen;
    }
    return $result;
  }
  KademliaNode._() : super();
  factory KademliaNode.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory KademliaNode.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'KademliaNode',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'ipfs.dht.kademlia_node'),
      createEmptyInstance: create)
    ..aOM<$9.KademliaId>(1, _omitFieldNames ? '' : 'peerId',
        subBuilder: $9.KademliaId.create)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'distance', $pb.PbFieldType.O3)
    ..aOM<$9.KademliaId>(3, _omitFieldNames ? '' : 'associatedPeerId',
        subBuilder: $9.KademliaId.create)
    ..pc<KademliaNode>(4, _omitFieldNames ? '' : 'children', $pb.PbFieldType.PM,
        subBuilder: KademliaNode.create)
    ..aInt64(5, _omitFieldNames ? '' : 'lastSeen')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  KademliaNode clone() => KademliaNode()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  KademliaNode copyWith(void Function(KademliaNode) updates) =>
      super.copyWith((message) => updates(message as KademliaNode))
          as KademliaNode;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static KademliaNode create() => KademliaNode._();
  KademliaNode createEmptyInstance() => create();
  static $pb.PbList<KademliaNode> createRepeated() =>
      $pb.PbList<KademliaNode>();
  @$core.pragma('dart2js:noInline')
  static KademliaNode getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<KademliaNode>(create);
  static KademliaNode? _defaultInstance;

  @$pb.TagNumber(1)
  $9.KademliaId get peerId => $_getN(0);
  @$pb.TagNumber(1)
  set peerId($9.KademliaId v) {
    setField(1, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasPeerId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerId() => clearField(1);
  @$pb.TagNumber(1)
  $9.KademliaId ensurePeerId() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.int get distance => $_getIZ(1);
  @$pb.TagNumber(2)
  set distance($core.int v) {
    $_setSignedInt32(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasDistance() => $_has(1);
  @$pb.TagNumber(2)
  void clearDistance() => clearField(2);

  @$pb.TagNumber(3)
  $9.KademliaId get associatedPeerId => $_getN(2);
  @$pb.TagNumber(3)
  set associatedPeerId($9.KademliaId v) {
    setField(3, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasAssociatedPeerId() => $_has(2);
  @$pb.TagNumber(3)
  void clearAssociatedPeerId() => clearField(3);
  @$pb.TagNumber(3)
  $9.KademliaId ensureAssociatedPeerId() => $_ensure(2);

  @$pb.TagNumber(4)
  $core.List<KademliaNode> get children => $_getList(3);

  @$pb.TagNumber(5)
  $fixnum.Int64 get lastSeen => $_getI64(4);
  @$pb.TagNumber(5)
  set lastSeen($fixnum.Int64 v) {
    $_setInt64(4, v);
  }

  @$pb.TagNumber(5)
  $core.bool hasLastSeen() => $_has(4);
  @$pb.TagNumber(5)
  void clearLastSeen() => clearField(5);
}

const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
