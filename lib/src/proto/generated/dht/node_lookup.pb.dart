//
//  Generated code. Do not modify.
//  source: dht/node_lookup.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'common_kademlia.pb.dart' as $9;

class NodeLookupRequest extends $pb.GeneratedMessage {
  factory NodeLookupRequest({
    $9.KademliaId? target,
  }) {
    final $result = create();
    if (target != null) {
      $result.target = target;
    }
    return $result;
  }
  NodeLookupRequest._() : super();
  factory NodeLookupRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory NodeLookupRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'NodeLookupRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.node_lookup'), createEmptyInstance: create)
    ..aOM<$9.KademliaId>(1, _omitFieldNames ? '' : 'target', subBuilder: $9.KademliaId.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  NodeLookupRequest clone() => NodeLookupRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  NodeLookupRequest copyWith(void Function(NodeLookupRequest) updates) => super.copyWith((message) => updates(message as NodeLookupRequest)) as NodeLookupRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NodeLookupRequest create() => NodeLookupRequest._();
  NodeLookupRequest createEmptyInstance() => create();
  static $pb.PbList<NodeLookupRequest> createRepeated() => $pb.PbList<NodeLookupRequest>();
  @$core.pragma('dart2js:noInline')
  static NodeLookupRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<NodeLookupRequest>(create);
  static NodeLookupRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $9.KademliaId get target => $_getN(0);
  @$pb.TagNumber(1)
  set target($9.KademliaId v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasTarget() => $_has(0);
  @$pb.TagNumber(1)
  void clearTarget() => clearField(1);
  @$pb.TagNumber(1)
  $9.KademliaId ensureTarget() => $_ensure(0);
}

class NodeLookupResponse extends $pb.GeneratedMessage {
  factory NodeLookupResponse({
    $core.Iterable<$9.KademliaId>? closestNodes,
  }) {
    final $result = create();
    if (closestNodes != null) {
      $result.closestNodes.addAll(closestNodes);
    }
    return $result;
  }
  NodeLookupResponse._() : super();
  factory NodeLookupResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory NodeLookupResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'NodeLookupResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.node_lookup'), createEmptyInstance: create)
    ..pc<$9.KademliaId>(1, _omitFieldNames ? '' : 'closestNodes', $pb.PbFieldType.PM, subBuilder: $9.KademliaId.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  NodeLookupResponse clone() => NodeLookupResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  NodeLookupResponse copyWith(void Function(NodeLookupResponse) updates) => super.copyWith((message) => updates(message as NodeLookupResponse)) as NodeLookupResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NodeLookupResponse create() => NodeLookupResponse._();
  NodeLookupResponse createEmptyInstance() => create();
  static $pb.PbList<NodeLookupResponse> createRepeated() => $pb.PbList<NodeLookupResponse>();
  @$core.pragma('dart2js:noInline')
  static NodeLookupResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<NodeLookupResponse>(create);
  static NodeLookupResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$9.KademliaId> get closestNodes => $_getList(0);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
