// This is a generated file - do not edit.
//
// Generated from dht/kademlia_node.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'common_kademlia.pb.dart' as $0;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class KademliaNode extends $pb.GeneratedMessage {
  factory KademliaNode({
    $0.KademliaId? peerId,
    $core.int? distance,
    $0.KademliaId? associatedPeerId,
    $core.Iterable<KademliaNode>? children,
    $fixnum.Int64? lastSeen,
  }) {
    final result = create();
    if (peerId != null) result.peerId = peerId;
    if (distance != null) result.distance = distance;
    if (associatedPeerId != null) result.associatedPeerId = associatedPeerId;
    if (children != null) result.children.addAll(children);
    if (lastSeen != null) result.lastSeen = lastSeen;
    return result;
  }

  KademliaNode._();

  factory KademliaNode.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory KademliaNode.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'KademliaNode',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'ipfs.dht.kademlia_node'),
      createEmptyInstance: create)
    ..aOM<$0.KademliaId>(1, _omitFieldNames ? '' : 'peerId',
        subBuilder: $0.KademliaId.create)
    ..aI(2, _omitFieldNames ? '' : 'distance')
    ..aOM<$0.KademliaId>(3, _omitFieldNames ? '' : 'associatedPeerId',
        subBuilder: $0.KademliaId.create)
    ..pPM<KademliaNode>(4, _omitFieldNames ? '' : 'children',
        subBuilder: KademliaNode.create)
    ..aInt64(5, _omitFieldNames ? '' : 'lastSeen')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KademliaNode clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KademliaNode copyWith(void Function(KademliaNode) updates) =>
      super.copyWith((message) => updates(message as KademliaNode))
          as KademliaNode;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static KademliaNode create() => KademliaNode._();
  @$core.override
  KademliaNode createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static KademliaNode getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<KademliaNode>(create);
  static KademliaNode? _defaultInstance;

  @$pb.TagNumber(1)
  $0.KademliaId get peerId => $_getN(0);
  @$pb.TagNumber(1)
  set peerId($0.KademliaId value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPeerId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerId() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.KademliaId ensurePeerId() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.int get distance => $_getIZ(1);
  @$pb.TagNumber(2)
  set distance($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDistance() => $_has(1);
  @$pb.TagNumber(2)
  void clearDistance() => $_clearField(2);

  @$pb.TagNumber(3)
  $0.KademliaId get associatedPeerId => $_getN(2);
  @$pb.TagNumber(3)
  set associatedPeerId($0.KademliaId value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasAssociatedPeerId() => $_has(2);
  @$pb.TagNumber(3)
  void clearAssociatedPeerId() => $_clearField(3);
  @$pb.TagNumber(3)
  $0.KademliaId ensureAssociatedPeerId() => $_ensure(2);

  @$pb.TagNumber(4)
  $pb.PbList<KademliaNode> get children => $_getList(3);

  @$pb.TagNumber(5)
  $fixnum.Int64 get lastSeen => $_getI64(4);
  @$pb.TagNumber(5)
  set lastSeen($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasLastSeen() => $_has(4);
  @$pb.TagNumber(5)
  void clearLastSeen() => $_clearField(5);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
