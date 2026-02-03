// This is a generated file - do not edit.
//
// Generated from dht/helpers.proto.

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

class CalculateDistanceRequest extends $pb.GeneratedMessage {
  factory CalculateDistanceRequest({
    $0.KademliaId? id1,
    $0.KademliaId? id2,
  }) {
    final result = create();
    if (id1 != null) result.id1 = id1;
    if (id2 != null) result.id2 = id2;
    return result;
  }

  CalculateDistanceRequest._();

  factory CalculateDistanceRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CalculateDistanceRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CalculateDistanceRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.helpers'),
      createEmptyInstance: create)
    ..aOM<$0.KademliaId>(1, _omitFieldNames ? '' : 'id1',
        subBuilder: $0.KademliaId.create)
    ..aOM<$0.KademliaId>(2, _omitFieldNames ? '' : 'id2',
        subBuilder: $0.KademliaId.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CalculateDistanceRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CalculateDistanceRequest copyWith(
          void Function(CalculateDistanceRequest) updates) =>
      super.copyWith((message) => updates(message as CalculateDistanceRequest))
          as CalculateDistanceRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CalculateDistanceRequest create() => CalculateDistanceRequest._();
  @$core.override
  CalculateDistanceRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CalculateDistanceRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CalculateDistanceRequest>(create);
  static CalculateDistanceRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $0.KademliaId get id1 => $_getN(0);
  @$pb.TagNumber(1)
  set id1($0.KademliaId value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasId1() => $_has(0);
  @$pb.TagNumber(1)
  void clearId1() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.KademliaId ensureId1() => $_ensure(0);

  @$pb.TagNumber(2)
  $0.KademliaId get id2 => $_getN(1);
  @$pb.TagNumber(2)
  set id2($0.KademliaId value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasId2() => $_has(1);
  @$pb.TagNumber(2)
  void clearId2() => $_clearField(2);
  @$pb.TagNumber(2)
  $0.KademliaId ensureId2() => $_ensure(1);
}

class CalculateDistanceResponse extends $pb.GeneratedMessage {
  factory CalculateDistanceResponse({
    $fixnum.Int64? distance,
  }) {
    final result = create();
    if (distance != null) result.distance = distance;
    return result;
  }

  CalculateDistanceResponse._();

  factory CalculateDistanceResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CalculateDistanceResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CalculateDistanceResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.helpers'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'distance')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CalculateDistanceResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CalculateDistanceResponse copyWith(
          void Function(CalculateDistanceResponse) updates) =>
      super.copyWith((message) => updates(message as CalculateDistanceResponse))
          as CalculateDistanceResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CalculateDistanceResponse create() => CalculateDistanceResponse._();
  @$core.override
  CalculateDistanceResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CalculateDistanceResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CalculateDistanceResponse>(create);
  static CalculateDistanceResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get distance => $_getI64(0);
  @$pb.TagNumber(1)
  set distance($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDistance() => $_has(0);
  @$pb.TagNumber(1)
  void clearDistance() => $_clearField(1);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');

