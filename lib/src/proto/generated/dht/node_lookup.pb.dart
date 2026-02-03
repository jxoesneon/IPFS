// This is a generated file - do not edit.
//
// Generated from dht/node_lookup.proto.

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

class NodeLookupRequest extends $pb.GeneratedMessage {
  factory NodeLookupRequest({
    $0.KademliaId? target,
  }) {
    final result = create();
    if (target != null) result.target = target;
    return result;
  }

  NodeLookupRequest._();

  factory NodeLookupRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory NodeLookupRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NodeLookupRequest',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'ipfs.dht.node_lookup'),
      createEmptyInstance: create)
    ..aOM<$0.KademliaId>(1, _omitFieldNames ? '' : 'target',
        subBuilder: $0.KademliaId.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeLookupRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeLookupRequest copyWith(void Function(NodeLookupRequest) updates) =>
      super.copyWith((message) => updates(message as NodeLookupRequest))
          as NodeLookupRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NodeLookupRequest create() => NodeLookupRequest._();
  @$core.override
  NodeLookupRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static NodeLookupRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NodeLookupRequest>(create);
  static NodeLookupRequest? _defaultInstance;

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
}

class NodeLookupResponse extends $pb.GeneratedMessage {
  factory NodeLookupResponse({
    $core.Iterable<$0.KademliaId>? closestNodes,
  }) {
    final result = create();
    if (closestNodes != null) result.closestNodes.addAll(closestNodes);
    return result;
  }

  NodeLookupResponse._();

  factory NodeLookupResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory NodeLookupResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NodeLookupResponse',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'ipfs.dht.node_lookup'),
      createEmptyInstance: create)
    ..pPM<$0.KademliaId>(1, _omitFieldNames ? '' : 'closestNodes',
        subBuilder: $0.KademliaId.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeLookupResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeLookupResponse copyWith(void Function(NodeLookupResponse) updates) =>
      super.copyWith((message) => updates(message as NodeLookupResponse))
          as NodeLookupResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NodeLookupResponse create() => NodeLookupResponse._();
  @$core.override
  NodeLookupResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static NodeLookupResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NodeLookupResponse>(create);
  static NodeLookupResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$0.KademliaId> get closestNodes => $_getList(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');

