//
//  Generated code. Do not modify.
//  source: connection.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'connection.pbenum.dart';
import 'google/protobuf/timestamp.pb.dart' as $7;

export 'connection.pbenum.dart';

class ConnectionState extends $pb.GeneratedMessage {
  factory ConnectionState({
    $core.String? peerId,
    ConnectionState_Status? status,
    $7.Timestamp? connectedAt,
    $core.Map<$core.String, $core.String>? metadata,
  }) {
    final $result = create();
    if (peerId != null) {
      $result.peerId = peerId;
    }
    if (status != null) {
      $result.status = status;
    }
    if (connectedAt != null) {
      $result.connectedAt = connectedAt;
    }
    if (metadata != null) {
      $result.metadata.addAll(metadata);
    }
    return $result;
  }
  ConnectionState._() : super();
  factory ConnectionState.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory ConnectionState.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ConnectionState',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.connection'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'peerId')
    ..e<ConnectionState_Status>(
        2, _omitFieldNames ? '' : 'status', $pb.PbFieldType.OE,
        defaultOrMaker: ConnectionState_Status.UNKNOWN,
        valueOf: ConnectionState_Status.valueOf,
        enumValues: ConnectionState_Status.values)
    ..aOM<$7.Timestamp>(3, _omitFieldNames ? '' : 'connectedAt',
        subBuilder: $7.Timestamp.create)
    ..m<$core.String, $core.String>(4, _omitFieldNames ? '' : 'metadata',
        entryClassName: 'ConnectionState.MetadataEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('ipfs.connection'))
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  ConnectionState clone() => ConnectionState()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  ConnectionState copyWith(void Function(ConnectionState) updates) =>
      super.copyWith((message) => updates(message as ConnectionState))
          as ConnectionState;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ConnectionState create() => ConnectionState._();
  ConnectionState createEmptyInstance() => create();
  static $pb.PbList<ConnectionState> createRepeated() =>
      $pb.PbList<ConnectionState>();
  @$core.pragma('dart2js:noInline')
  static ConnectionState getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ConnectionState>(create);
  static ConnectionState? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get peerId => $_getSZ(0);
  @$pb.TagNumber(1)
  set peerId($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasPeerId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerId() => clearField(1);

  @$pb.TagNumber(2)
  ConnectionState_Status get status => $_getN(1);
  @$pb.TagNumber(2)
  set status(ConnectionState_Status v) {
    setField(2, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearStatus() => clearField(2);

  @$pb.TagNumber(3)
  $7.Timestamp get connectedAt => $_getN(2);
  @$pb.TagNumber(3)
  set connectedAt($7.Timestamp v) {
    setField(3, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasConnectedAt() => $_has(2);
  @$pb.TagNumber(3)
  void clearConnectedAt() => clearField(3);
  @$pb.TagNumber(3)
  $7.Timestamp ensureConnectedAt() => $_ensure(2);

  @$pb.TagNumber(4)
  $core.Map<$core.String, $core.String> get metadata => $_getMap(3);
}

class ConnectionMetrics extends $pb.GeneratedMessage {
  factory ConnectionMetrics({
    $core.String? peerId,
    $fixnum.Int64? messagesSent,
    $fixnum.Int64? messagesReceived,
    $fixnum.Int64? bytesSent,
    $fixnum.Int64? bytesReceived,
    $core.int? averageLatencyMs,
  }) {
    final $result = create();
    if (peerId != null) {
      $result.peerId = peerId;
    }
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
    return $result;
  }
  ConnectionMetrics._() : super();
  factory ConnectionMetrics.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory ConnectionMetrics.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ConnectionMetrics',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.connection'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'peerId')
    ..a<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'messagesSent', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        3, _omitFieldNames ? '' : 'messagesReceived', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        4, _omitFieldNames ? '' : 'bytesSent', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        5, _omitFieldNames ? '' : 'bytesReceived', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$core.int>(
        6, _omitFieldNames ? '' : 'averageLatencyMs', $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  ConnectionMetrics clone() => ConnectionMetrics()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  ConnectionMetrics copyWith(void Function(ConnectionMetrics) updates) =>
      super.copyWith((message) => updates(message as ConnectionMetrics))
          as ConnectionMetrics;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ConnectionMetrics create() => ConnectionMetrics._();
  ConnectionMetrics createEmptyInstance() => create();
  static $pb.PbList<ConnectionMetrics> createRepeated() =>
      $pb.PbList<ConnectionMetrics>();
  @$core.pragma('dart2js:noInline')
  static ConnectionMetrics getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ConnectionMetrics>(create);
  static ConnectionMetrics? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get peerId => $_getSZ(0);
  @$pb.TagNumber(1)
  set peerId($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasPeerId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerId() => clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get messagesSent => $_getI64(1);
  @$pb.TagNumber(2)
  set messagesSent($fixnum.Int64 v) {
    $_setInt64(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasMessagesSent() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessagesSent() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get messagesReceived => $_getI64(2);
  @$pb.TagNumber(3)
  set messagesReceived($fixnum.Int64 v) {
    $_setInt64(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasMessagesReceived() => $_has(2);
  @$pb.TagNumber(3)
  void clearMessagesReceived() => clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get bytesSent => $_getI64(3);
  @$pb.TagNumber(4)
  set bytesSent($fixnum.Int64 v) {
    $_setInt64(3, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasBytesSent() => $_has(3);
  @$pb.TagNumber(4)
  void clearBytesSent() => clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get bytesReceived => $_getI64(4);
  @$pb.TagNumber(5)
  set bytesReceived($fixnum.Int64 v) {
    $_setInt64(4, v);
  }

  @$pb.TagNumber(5)
  $core.bool hasBytesReceived() => $_has(4);
  @$pb.TagNumber(5)
  void clearBytesReceived() => clearField(5);

  @$pb.TagNumber(6)
  $core.int get averageLatencyMs => $_getIZ(5);
  @$pb.TagNumber(6)
  set averageLatencyMs($core.int v) {
    $_setUnsignedInt32(5, v);
  }

  @$pb.TagNumber(6)
  $core.bool hasAverageLatencyMs() => $_has(5);
  @$pb.TagNumber(6)
  void clearAverageLatencyMs() => clearField(6);
}

const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
