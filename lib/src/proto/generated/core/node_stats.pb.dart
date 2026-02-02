//
//  Generated code. Do not modify.
//  source: core/node_stats.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

/// Represents statistics about the IPFS node.
class NodeStats extends $pb.GeneratedMessage {
  factory NodeStats({
    $core.int? numBlocks,
    $fixnum.Int64? datastoreSize,
    $core.int? numConnectedPeers,
    $fixnum.Int64? bandwidthSent,
    $fixnum.Int64? bandwidthReceived,
  }) {
    final $result = create();
    if (numBlocks != null) {
      $result.numBlocks = numBlocks;
    }
    if (datastoreSize != null) {
      $result.datastoreSize = datastoreSize;
    }
    if (numConnectedPeers != null) {
      $result.numConnectedPeers = numConnectedPeers;
    }
    if (bandwidthSent != null) {
      $result.bandwidthSent = bandwidthSent;
    }
    if (bandwidthReceived != null) {
      $result.bandwidthReceived = bandwidthReceived;
    }
    return $result;
  }
  NodeStats._() : super();
  factory NodeStats.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory NodeStats.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'NodeStats', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.data_structures'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'numBlocks', $pb.PbFieldType.O3)
    ..aInt64(2, _omitFieldNames ? '' : 'datastoreSize')
    ..a<$core.int>(3, _omitFieldNames ? '' : 'numConnectedPeers', $pb.PbFieldType.O3)
    ..aInt64(4, _omitFieldNames ? '' : 'bandwidthSent')
    ..aInt64(5, _omitFieldNames ? '' : 'bandwidthReceived')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  NodeStats clone() => NodeStats()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  NodeStats copyWith(void Function(NodeStats) updates) => super.copyWith((message) => updates(message as NodeStats)) as NodeStats;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NodeStats create() => NodeStats._();
  NodeStats createEmptyInstance() => create();
  static $pb.PbList<NodeStats> createRepeated() => $pb.PbList<NodeStats>();
  @$core.pragma('dart2js:noInline')
  static NodeStats getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<NodeStats>(create);
  static NodeStats? _defaultInstance;

  /// The number of blocks stored in the datastore.
  @$pb.TagNumber(1)
  $core.int get numBlocks => $_getIZ(0);
  @$pb.TagNumber(1)
  set numBlocks($core.int v) { $_setSignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasNumBlocks() => $_has(0);
  @$pb.TagNumber(1)
  void clearNumBlocks() => clearField(1);

  /// The total size of the blocks stored in the datastore (in bytes).
  @$pb.TagNumber(2)
  $fixnum.Int64 get datastoreSize => $_getI64(1);
  @$pb.TagNumber(2)
  set datastoreSize($fixnum.Int64 v) { $_setInt64(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasDatastoreSize() => $_has(1);
  @$pb.TagNumber(2)
  void clearDatastoreSize() => clearField(2);

  /// The number of connected peers.
  @$pb.TagNumber(3)
  $core.int get numConnectedPeers => $_getIZ(2);
  @$pb.TagNumber(3)
  set numConnectedPeers($core.int v) { $_setSignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasNumConnectedPeers() => $_has(2);
  @$pb.TagNumber(3)
  void clearNumConnectedPeers() => clearField(3);

  /// The total bandwidth used for sending data (in bytes).
  @$pb.TagNumber(4)
  $fixnum.Int64 get bandwidthSent => $_getI64(3);
  @$pb.TagNumber(4)
  set bandwidthSent($fixnum.Int64 v) { $_setInt64(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasBandwidthSent() => $_has(3);
  @$pb.TagNumber(4)
  void clearBandwidthSent() => clearField(4);

  /// The total bandwidth used for receiving data (in bytes).
  @$pb.TagNumber(5)
  $fixnum.Int64 get bandwidthReceived => $_getI64(4);
  @$pb.TagNumber(5)
  set bandwidthReceived($fixnum.Int64 v) { $_setInt64(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasBandwidthReceived() => $_has(4);
  @$pb.TagNumber(5)
  void clearBandwidthReceived() => clearField(5);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
