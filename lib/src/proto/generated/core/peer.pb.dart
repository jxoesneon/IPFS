//
//  Generated code. Do not modify.
//  source: core/peer.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

/// Represents a peer in the IPFS network.
class PeerProto extends $pb.GeneratedMessage {
  factory PeerProto({
    $core.String? id,
    $core.Iterable<$core.String>? addresses,
    $fixnum.Int64? latency,
    $core.String? agentVersion,
  }) {
    final $result = create();
    if (id != null) {
      $result.id = id;
    }
    if (addresses != null) {
      $result.addresses.addAll(addresses);
    }
    if (latency != null) {
      $result.latency = latency;
    }
    if (agentVersion != null) {
      $result.agentVersion = agentVersion;
    }
    return $result;
  }
  PeerProto._() : super();
  factory PeerProto.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PeerProto.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PeerProto', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.data_structures'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..pPS(2, _omitFieldNames ? '' : 'addresses')
    ..aInt64(3, _omitFieldNames ? '' : 'latency')
    ..aOS(4, _omitFieldNames ? '' : 'agentVersion')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PeerProto clone() => PeerProto()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PeerProto copyWith(void Function(PeerProto) updates) => super.copyWith((message) => updates(message as PeerProto)) as PeerProto;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PeerProto create() => PeerProto._();
  PeerProto createEmptyInstance() => create();
  static $pb.PbList<PeerProto> createRepeated() => $pb.PbList<PeerProto>();
  @$core.pragma('dart2js:noInline')
  static PeerProto getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PeerProto>(create);
  static PeerProto? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.String> get addresses => $_getList(1);

  @$pb.TagNumber(3)
  $fixnum.Int64 get latency => $_getI64(2);
  @$pb.TagNumber(3)
  set latency($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasLatency() => $_has(2);
  @$pb.TagNumber(3)
  void clearLatency() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get agentVersion => $_getSZ(3);
  @$pb.TagNumber(4)
  set agentVersion($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasAgentVersion() => $_has(3);
  @$pb.TagNumber(4)
  void clearAgentVersion() => clearField(4);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
