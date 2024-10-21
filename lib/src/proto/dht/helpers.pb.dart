//
//  Generated code. Do not modify.
//  source: helpers.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'common_kademlia.pb.dart' as $0;

class CalculateDistanceRequest extends $pb.GeneratedMessage {
  factory CalculateDistanceRequest({
    $0.KademliaId? id1,
    $0.KademliaId? id2,
  }) {
    final $result = create();
    if (id1 != null) {
      $result.id1 = id1;
    }
    if (id2 != null) {
      $result.id2 = id2;
    }
    return $result;
  }
  CalculateDistanceRequest._() : super();
  factory CalculateDistanceRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CalculateDistanceRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CalculateDistanceRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.helpers'), createEmptyInstance: create)
    ..aOM<$0.KademliaId>(1, _omitFieldNames ? '' : 'id1', subBuilder: $0.KademliaId.create)
    ..aOM<$0.KademliaId>(2, _omitFieldNames ? '' : 'id2', subBuilder: $0.KademliaId.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  CalculateDistanceRequest clone() => CalculateDistanceRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  CalculateDistanceRequest copyWith(void Function(CalculateDistanceRequest) updates) => super.copyWith((message) => updates(message as CalculateDistanceRequest)) as CalculateDistanceRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CalculateDistanceRequest create() => CalculateDistanceRequest._();
  CalculateDistanceRequest createEmptyInstance() => create();
  static $pb.PbList<CalculateDistanceRequest> createRepeated() => $pb.PbList<CalculateDistanceRequest>();
  @$core.pragma('dart2js:noInline')
  static CalculateDistanceRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CalculateDistanceRequest>(create);
  static CalculateDistanceRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $0.KademliaId get id1 => $_getN(0);
  @$pb.TagNumber(1)
  set id1($0.KademliaId v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasId1() => $_has(0);
  @$pb.TagNumber(1)
  void clearId1() => clearField(1);
  @$pb.TagNumber(1)
  $0.KademliaId ensureId1() => $_ensure(0);

  @$pb.TagNumber(2)
  $0.KademliaId get id2 => $_getN(1);
  @$pb.TagNumber(2)
  set id2($0.KademliaId v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasId2() => $_has(1);
  @$pb.TagNumber(2)
  void clearId2() => clearField(2);
  @$pb.TagNumber(2)
  $0.KademliaId ensureId2() => $_ensure(1);
}

class CalculateDistanceResponse extends $pb.GeneratedMessage {
  factory CalculateDistanceResponse({
    $fixnum.Int64? distance,
  }) {
    final $result = create();
    if (distance != null) {
      $result.distance = distance;
    }
    return $result;
  }
  CalculateDistanceResponse._() : super();
  factory CalculateDistanceResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CalculateDistanceResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CalculateDistanceResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.helpers'), createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'distance')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  CalculateDistanceResponse clone() => CalculateDistanceResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  CalculateDistanceResponse copyWith(void Function(CalculateDistanceResponse) updates) => super.copyWith((message) => updates(message as CalculateDistanceResponse)) as CalculateDistanceResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CalculateDistanceResponse create() => CalculateDistanceResponse._();
  CalculateDistanceResponse createEmptyInstance() => create();
  static $pb.PbList<CalculateDistanceResponse> createRepeated() => $pb.PbList<CalculateDistanceResponse>();
  @$core.pragma('dart2js:noInline')
  static CalculateDistanceResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CalculateDistanceResponse>(create);
  static CalculateDistanceResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get distance => $_getI64(0);
  @$pb.TagNumber(1)
  set distance($fixnum.Int64 v) { $_setInt64(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasDistance() => $_has(0);
  @$pb.TagNumber(1)
  void clearDistance() => clearField(1);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
