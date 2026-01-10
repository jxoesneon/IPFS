// This is a generated file - do not edit.
//
// Generated from core/node_stats.proto.

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

/// Represents statistics about the IPFS node.
class NodeStats extends $pb.GeneratedMessage {
  factory NodeStats({
    $core.int? numBlocks,
    $fixnum.Int64? datastoreSize,
    $core.int? numConnectedPeers,
    $fixnum.Int64? bandwidthSent,
    $fixnum.Int64? bandwidthReceived,
  }) {
    final result = create();
    if (numBlocks != null) result.numBlocks = numBlocks;
    if (datastoreSize != null) result.datastoreSize = datastoreSize;
    if (numConnectedPeers != null) result.numConnectedPeers = numConnectedPeers;
    if (bandwidthSent != null) result.bandwidthSent = bandwidthSent;
    if (bandwidthReceived != null) result.bandwidthReceived = bandwidthReceived;
    return result;
  }

  NodeStats._();

  factory NodeStats.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory NodeStats.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'NodeStats',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.data_structures'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'numBlocks')
    ..aInt64(2, _omitFieldNames ? '' : 'datastoreSize')
    ..aI(3, _omitFieldNames ? '' : 'numConnectedPeers')
    ..aInt64(4, _omitFieldNames ? '' : 'bandwidthSent')
    ..aInt64(5, _omitFieldNames ? '' : 'bandwidthReceived')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeStats clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeStats copyWith(void Function(NodeStats) updates) =>
      super.copyWith((message) => updates(message as NodeStats)) as NodeStats;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NodeStats create() => NodeStats._();
  @$core.override
  NodeStats createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static NodeStats getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<NodeStats>(create);
  static NodeStats? _defaultInstance;

  /// The number of blocks stored in the datastore.
  @$pb.TagNumber(1)
  $core.int get numBlocks => $_getIZ(0);
  @$pb.TagNumber(1)
  set numBlocks($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNumBlocks() => $_has(0);
  @$pb.TagNumber(1)
  void clearNumBlocks() => $_clearField(1);

  /// The total size of the blocks stored in the datastore (in bytes).
  @$pb.TagNumber(2)
  $fixnum.Int64 get datastoreSize => $_getI64(1);
  @$pb.TagNumber(2)
  set datastoreSize($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDatastoreSize() => $_has(1);
  @$pb.TagNumber(2)
  void clearDatastoreSize() => $_clearField(2);

  /// The number of connected peers.
  @$pb.TagNumber(3)
  $core.int get numConnectedPeers => $_getIZ(2);
  @$pb.TagNumber(3)
  set numConnectedPeers($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasNumConnectedPeers() => $_has(2);
  @$pb.TagNumber(3)
  void clearNumConnectedPeers() => $_clearField(3);

  /// The total bandwidth used for sending data (in bytes).
  @$pb.TagNumber(4)
  $fixnum.Int64 get bandwidthSent => $_getI64(3);
  @$pb.TagNumber(4)
  set bandwidthSent($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBandwidthSent() => $_has(3);
  @$pb.TagNumber(4)
  void clearBandwidthSent() => $_clearField(4);

  /// The total bandwidth used for receiving data (in bytes).
  @$pb.TagNumber(5)
  $fixnum.Int64 get bandwidthReceived => $_getI64(4);
  @$pb.TagNumber(5)
  set bandwidthReceived($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasBandwidthReceived() => $_has(4);
  @$pb.TagNumber(5)
  void clearBandwidthReceived() => $_clearField(5);
}

const $core.bool _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
