//
//  Generated code. Do not modify.
//  source: dht/find_closest_peers.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'common_kademlia.pb.dart' as $0;

class FindClosestPeersRequest extends $pb.GeneratedMessage {
  factory FindClosestPeersRequest({
    $0.KademliaId? target,
    $core.int? count,
  }) {
    final $result = create();
    if (target != null) {
      $result.target = target;
    }
    if (count != null) {
      $result.count = count;
    }
    return $result;
  }
  FindClosestPeersRequest._() : super();
  factory FindClosestPeersRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory FindClosestPeersRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'FindClosestPeersRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.find_closest_peers'), createEmptyInstance: create)
    ..aOM<$0.KademliaId>(1, _omitFieldNames ? '' : 'target', subBuilder: $0.KademliaId.create)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'count', $pb.PbFieldType.O3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  FindClosestPeersRequest clone() => FindClosestPeersRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  FindClosestPeersRequest copyWith(void Function(FindClosestPeersRequest) updates) => super.copyWith((message) => updates(message as FindClosestPeersRequest)) as FindClosestPeersRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FindClosestPeersRequest create() => FindClosestPeersRequest._();
  FindClosestPeersRequest createEmptyInstance() => create();
  static $pb.PbList<FindClosestPeersRequest> createRepeated() => $pb.PbList<FindClosestPeersRequest>();
  @$core.pragma('dart2js:noInline')
  static FindClosestPeersRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FindClosestPeersRequest>(create);
  static FindClosestPeersRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $0.KademliaId get target => $_getN(0);
  @$pb.TagNumber(1)
  set target($0.KademliaId v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasTarget() => $_has(0);
  @$pb.TagNumber(1)
  void clearTarget() => clearField(1);
  @$pb.TagNumber(1)
  $0.KademliaId ensureTarget() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.int get count => $_getIZ(1);
  @$pb.TagNumber(2)
  set count($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearCount() => clearField(2);
}

class FindClosestPeersResponse extends $pb.GeneratedMessage {
  factory FindClosestPeersResponse({
    $core.Iterable<$0.KademliaId>? peerIds,
  }) {
    final $result = create();
    if (peerIds != null) {
      $result.peerIds.addAll(peerIds);
    }
    return $result;
  }
  FindClosestPeersResponse._() : super();
  factory FindClosestPeersResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory FindClosestPeersResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'FindClosestPeersResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.find_closest_peers'), createEmptyInstance: create)
    ..pc<$0.KademliaId>(1, _omitFieldNames ? '' : 'peerIds', $pb.PbFieldType.PM, subBuilder: $0.KademliaId.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  FindClosestPeersResponse clone() => FindClosestPeersResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  FindClosestPeersResponse copyWith(void Function(FindClosestPeersResponse) updates) => super.copyWith((message) => updates(message as FindClosestPeersResponse)) as FindClosestPeersResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FindClosestPeersResponse create() => FindClosestPeersResponse._();
  FindClosestPeersResponse createEmptyInstance() => create();
  static $pb.PbList<FindClosestPeersResponse> createRepeated() => $pb.PbList<FindClosestPeersResponse>();
  @$core.pragma('dart2js:noInline')
  static FindClosestPeersResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FindClosestPeersResponse>(create);
  static FindClosestPeersResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$0.KademliaId> get peerIds => $_getList(0);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
