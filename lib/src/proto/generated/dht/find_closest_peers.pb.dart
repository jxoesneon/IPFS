// This is a generated file - do not edit.
//
// Generated from dht/find_closest_peers.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'common_kademlia.pb.dart' as $0;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class FindClosestPeersRequest extends $pb.GeneratedMessage {
  factory FindClosestPeersRequest({
    $0.KademliaId? target,
    $core.int? count,
  }) {
    final result = create();
    if (target != null) result.target = target;
    if (count != null) result.count = count;
    return result;
  }

  FindClosestPeersRequest._();

  factory FindClosestPeersRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FindClosestPeersRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FindClosestPeersRequest',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'ipfs.dht.find_closest_peers'),
      createEmptyInstance: create)
    ..aOM<$0.KademliaId>(1, _omitFieldNames ? '' : 'target',
        subBuilder: $0.KademliaId.create)
    ..aI(2, _omitFieldNames ? '' : 'count')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FindClosestPeersRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FindClosestPeersRequest copyWith(
          void Function(FindClosestPeersRequest) updates) =>
      super.copyWith((message) => updates(message as FindClosestPeersRequest))
          as FindClosestPeersRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FindClosestPeersRequest create() => FindClosestPeersRequest._();
  @$core.override
  FindClosestPeersRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FindClosestPeersRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FindClosestPeersRequest>(create);
  static FindClosestPeersRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $0.KademliaId get target => $_getN(0);
  @$pb.TagNumber(1)
  set target($0.KademliaId value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasTarget() => $_has(0);
  @$pb.TagNumber(1)
  void clearTarget() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.KademliaId ensureTarget() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.int get count => $_getIZ(1);
  @$pb.TagNumber(2)
  set count($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearCount() => $_clearField(2);
}

class FindClosestPeersResponse extends $pb.GeneratedMessage {
  factory FindClosestPeersResponse({
    $core.Iterable<$0.KademliaId>? peerIds,
  }) {
    final result = create();
    if (peerIds != null) result.peerIds.addAll(peerIds);
    return result;
  }

  FindClosestPeersResponse._();

  factory FindClosestPeersResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FindClosestPeersResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FindClosestPeersResponse',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'ipfs.dht.find_closest_peers'),
      createEmptyInstance: create)
    ..pPM<$0.KademliaId>(1, _omitFieldNames ? '' : 'peerIds',
        subBuilder: $0.KademliaId.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FindClosestPeersResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FindClosestPeersResponse copyWith(
          void Function(FindClosestPeersResponse) updates) =>
      super.copyWith((message) => updates(message as FindClosestPeersResponse))
          as FindClosestPeersResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FindClosestPeersResponse create() => FindClosestPeersResponse._();
  @$core.override
  FindClosestPeersResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FindClosestPeersResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FindClosestPeersResponse>(create);
  static FindClosestPeersResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$0.KademliaId> get peerIds => $_getList(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');

