//
//  Generated code. Do not modify.
//  source: metrics.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'google/protobuf/timestamp.pb.dart' as $0;

class NetworkMetrics extends $pb.GeneratedMessage {
  factory NetworkMetrics({
    $0.Timestamp? timestamp,
    $core.Map<$core.String, PeerMetrics>? peerMetrics,
    $core.Map<$core.String, ProtocolMetrics>? protocolMetrics,
  }) {
    final $result = create();
    if (timestamp != null) {
      $result.timestamp = timestamp;
    }
    if (peerMetrics != null) {
      $result.peerMetrics.addAll(peerMetrics);
    }
    if (protocolMetrics != null) {
      $result.protocolMetrics.addAll(protocolMetrics);
    }
    return $result;
  }
  NetworkMetrics._() : super();
  factory NetworkMetrics.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory NetworkMetrics.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'NetworkMetrics', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.metrics'), createEmptyInstance: create)
    ..aOM<$0.Timestamp>(1, _omitFieldNames ? '' : 'timestamp', subBuilder: $0.Timestamp.create)
    ..m<$core.String, PeerMetrics>(2, _omitFieldNames ? '' : 'peerMetrics', entryClassName: 'NetworkMetrics.PeerMetricsEntry', keyFieldType: $pb.PbFieldType.OS, valueFieldType: $pb.PbFieldType.OM, valueCreator: PeerMetrics.create, valueDefaultOrMaker: PeerMetrics.getDefault, packageName: const $pb.PackageName('ipfs.metrics'))
    ..m<$core.String, ProtocolMetrics>(3, _omitFieldNames ? '' : 'protocolMetrics', entryClassName: 'NetworkMetrics.ProtocolMetricsEntry', keyFieldType: $pb.PbFieldType.OS, valueFieldType: $pb.PbFieldType.OM, valueCreator: ProtocolMetrics.create, valueDefaultOrMaker: ProtocolMetrics.getDefault, packageName: const $pb.PackageName('ipfs.metrics'))
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  NetworkMetrics clone() => NetworkMetrics()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  NetworkMetrics copyWith(void Function(NetworkMetrics) updates) => super.copyWith((message) => updates(message as NetworkMetrics)) as NetworkMetrics;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NetworkMetrics create() => NetworkMetrics._();
  NetworkMetrics createEmptyInstance() => create();
  static $pb.PbList<NetworkMetrics> createRepeated() => $pb.PbList<NetworkMetrics>();
  @$core.pragma('dart2js:noInline')
  static NetworkMetrics getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<NetworkMetrics>(create);
  static NetworkMetrics? _defaultInstance;

  @$pb.TagNumber(1)
  $0.Timestamp get timestamp => $_getN(0);
  @$pb.TagNumber(1)
  set timestamp($0.Timestamp v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasTimestamp() => $_has(0);
  @$pb.TagNumber(1)
  void clearTimestamp() => clearField(1);
  @$pb.TagNumber(1)
  $0.Timestamp ensureTimestamp() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.Map<$core.String, PeerMetrics> get peerMetrics => $_getMap(1);

  @$pb.TagNumber(3)
  $core.Map<$core.String, ProtocolMetrics> get protocolMetrics => $_getMap(2);
}

class PeerMetrics extends $pb.GeneratedMessage {
  factory PeerMetrics({
    $fixnum.Int64? messagesSent,
    $fixnum.Int64? messagesReceived,
    $fixnum.Int64? bytesSent,
    $fixnum.Int64? bytesReceived,
    $core.int? averageLatencyMs,
    $core.int? errorCount,
  }) {
    final $result = create();
    if (messagesSent != null) {
      $result.messagesSent = messagesSent;
    }
    if (messagesReceived != null) {
      $result.messagesReceived = messagesReceived;
    }
    if (bytesSent != null) {
      $result.bytesSent = bytesSent;
    }
    if (bytesReceived != null) {
      $result.bytesReceived = bytesReceived;
    }
    if (averageLatencyMs != null) {
      $result.averageLatencyMs = averageLatencyMs;
    }
    if (errorCount != null) {
      $result.errorCount = errorCount;
    }
    return $result;
  }
  PeerMetrics._() : super();
  factory PeerMetrics.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PeerMetrics.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PeerMetrics', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.metrics'), createEmptyInstance: create)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'messagesSent', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(2, _omitFieldNames ? '' : 'messagesReceived', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'bytesSent', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(4, _omitFieldNames ? '' : 'bytesReceived', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$core.int>(5, _omitFieldNames ? '' : 'averageLatencyMs', $pb.PbFieldType.OU3)
    ..a<$core.int>(6, _omitFieldNames ? '' : 'errorCount', $pb.PbFieldType.OU3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PeerMetrics clone() => PeerMetrics()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PeerMetrics copyWith(void Function(PeerMetrics) updates) => super.copyWith((message) => updates(message as PeerMetrics)) as PeerMetrics;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PeerMetrics create() => PeerMetrics._();
  PeerMetrics createEmptyInstance() => create();
  static $pb.PbList<PeerMetrics> createRepeated() => $pb.PbList<PeerMetrics>();
  @$core.pragma('dart2js:noInline')
  static PeerMetrics getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PeerMetrics>(create);
  static PeerMetrics? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get messagesSent => $_getI64(0);
  @$pb.TagNumber(1)
  set messagesSent($fixnum.Int64 v) { $_setInt64(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasMessagesSent() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessagesSent() => clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get messagesReceived => $_getI64(1);
  @$pb.TagNumber(2)
  set messagesReceived($fixnum.Int64 v) { $_setInt64(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMessagesReceived() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessagesReceived() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get bytesSent => $_getI64(2);
  @$pb.TagNumber(3)
  set bytesSent($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasBytesSent() => $_has(2);
  @$pb.TagNumber(3)
  void clearBytesSent() => clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get bytesReceived => $_getI64(3);
  @$pb.TagNumber(4)
  set bytesReceived($fixnum.Int64 v) { $_setInt64(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasBytesReceived() => $_has(3);
  @$pb.TagNumber(4)
  void clearBytesReceived() => clearField(4);

  @$pb.TagNumber(5)
  $core.int get averageLatencyMs => $_getIZ(4);
  @$pb.TagNumber(5)
  set averageLatencyMs($core.int v) { $_setUnsignedInt32(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasAverageLatencyMs() => $_has(4);
  @$pb.TagNumber(5)
  void clearAverageLatencyMs() => clearField(5);

  @$pb.TagNumber(6)
  $core.int get errorCount => $_getIZ(5);
  @$pb.TagNumber(6)
  set errorCount($core.int v) { $_setUnsignedInt32(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasErrorCount() => $_has(5);
  @$pb.TagNumber(6)
  void clearErrorCount() => clearField(6);
}

class ProtocolMetrics extends $pb.GeneratedMessage {
  factory ProtocolMetrics({
    $fixnum.Int64? messagesSent,
    $fixnum.Int64? messagesReceived,
    $core.int? activeConnections,
    $core.Map<$core.String, $fixnum.Int64>? errorCounts,
  }) {
    final $result = create();
    if (messagesSent != null) {
      $result.messagesSent = messagesSent;
    }
    if (messagesReceived != null) {
      $result.messagesReceived = messagesReceived;
    }
    if (activeConnections != null) {
      $result.activeConnections = activeConnections;
    }
    if (errorCounts != null) {
      $result.errorCounts.addAll(errorCounts);
    }
    return $result;
  }
  ProtocolMetrics._() : super();
  factory ProtocolMetrics.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ProtocolMetrics.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ProtocolMetrics', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.metrics'), createEmptyInstance: create)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'messagesSent', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(2, _omitFieldNames ? '' : 'messagesReceived', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$core.int>(3, _omitFieldNames ? '' : 'activeConnections', $pb.PbFieldType.OU3)
    ..m<$core.String, $fixnum.Int64>(4, _omitFieldNames ? '' : 'errorCounts', entryClassName: 'ProtocolMetrics.ErrorCountsEntry', keyFieldType: $pb.PbFieldType.OS, valueFieldType: $pb.PbFieldType.OU6, packageName: const $pb.PackageName('ipfs.metrics'))
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ProtocolMetrics clone() => ProtocolMetrics()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ProtocolMetrics copyWith(void Function(ProtocolMetrics) updates) => super.copyWith((message) => updates(message as ProtocolMetrics)) as ProtocolMetrics;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ProtocolMetrics create() => ProtocolMetrics._();
  ProtocolMetrics createEmptyInstance() => create();
  static $pb.PbList<ProtocolMetrics> createRepeated() => $pb.PbList<ProtocolMetrics>();
  @$core.pragma('dart2js:noInline')
  static ProtocolMetrics getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ProtocolMetrics>(create);
  static ProtocolMetrics? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get messagesSent => $_getI64(0);
  @$pb.TagNumber(1)
  set messagesSent($fixnum.Int64 v) { $_setInt64(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasMessagesSent() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessagesSent() => clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get messagesReceived => $_getI64(1);
  @$pb.TagNumber(2)
  set messagesReceived($fixnum.Int64 v) { $_setInt64(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMessagesReceived() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessagesReceived() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get activeConnections => $_getIZ(2);
  @$pb.TagNumber(3)
  set activeConnections($core.int v) { $_setUnsignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasActiveConnections() => $_has(2);
  @$pb.TagNumber(3)
  void clearActiveConnections() => clearField(3);

  @$pb.TagNumber(4)
  $core.Map<$core.String, $fixnum.Int64> get errorCounts => $_getMap(3);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
