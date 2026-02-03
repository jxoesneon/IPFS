// This is a generated file - do not edit.
//
// Generated from core/peer.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

/// Represents a peer in the IPFS network.
class PeerProto extends $pb.GeneratedMessage {
  factory PeerProto({
    $core.String? id,
    $core.Iterable<$core.String>? addresses,
    $fixnum.Int64? latency,
    $core.String? agentVersion,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (addresses != null) result.addresses.addAll(addresses);
    if (latency != null) result.latency = latency;
    if (agentVersion != null) result.agentVersion = agentVersion;
    return result;
  }

  PeerProto._();

  factory PeerProto.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PeerProto.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PeerProto',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'ipfs.core.data_structures'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..pPS(2, _omitFieldNames ? '' : 'addresses')
    ..aInt64(3, _omitFieldNames ? '' : 'latency')
    ..aOS(4, _omitFieldNames ? '' : 'agentVersion')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PeerProto clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PeerProto copyWith(void Function(PeerProto) updates) =>
      super.copyWith((message) => updates(message as PeerProto)) as PeerProto;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PeerProto create() => PeerProto._();
  @$core.override
  PeerProto createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PeerProto getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PeerProto>(create);
  static PeerProto? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get addresses => $_getList(1);

  @$pb.TagNumber(3)
  $fixnum.Int64 get latency => $_getI64(2);
  @$pb.TagNumber(3)
  set latency($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLatency() => $_has(2);
  @$pb.TagNumber(3)
  void clearLatency() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get agentVersion => $_getSZ(3);
  @$pb.TagNumber(4)
  set agentVersion($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAgentVersion() => $_has(3);
  @$pb.TagNumber(4)
  void clearAgentVersion() => $_clearField(4);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');

