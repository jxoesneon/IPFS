// This is a generated file - do not edit.
//
// Generated from connection.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart'
    as $0;

import 'connection.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'connection.pbenum.dart';

class ConnectionState extends $pb.GeneratedMessage {
  factory ConnectionState({
    $core.String? peerId,
    ConnectionState_Status? status,
    $0.Timestamp? connectedAt,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? metadata,
  }) {
    final result = create();
    if (peerId != null) result.peerId = peerId;
    if (status != null) result.status = status;
    if (connectedAt != null) result.connectedAt = connectedAt;
    if (metadata != null) result.metadata.addEntries(metadata);
    return result;
  }

  ConnectionState._();

  factory ConnectionState.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ConnectionState.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ConnectionState',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.connection'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'peerId')
    ..aE<ConnectionState_Status>(2, _omitFieldNames ? '' : 'status',
        enumValues: ConnectionState_Status.values)
    ..aOM<$0.Timestamp>(3, _omitFieldNames ? '' : 'connectedAt',
        subBuilder: $0.Timestamp.create)
    ..m<$core.String, $core.String>(4, _omitFieldNames ? '' : 'metadata',
        entryClassName: 'ConnectionState.MetadataEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('ipfs.connection'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConnectionState clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConnectionState copyWith(void Function(ConnectionState) updates) =>
      super.copyWith((message) => updates(message as ConnectionState))
          as ConnectionState;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ConnectionState create() => ConnectionState._();
  @$core.override
  ConnectionState createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ConnectionState getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ConnectionState>(create);
  static ConnectionState? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get peerId => $_getSZ(0);
  @$pb.TagNumber(1)
  set peerId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPeerId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerId() => $_clearField(1);

  @$pb.TagNumber(2)
  ConnectionState_Status get status => $_getN(1);
  @$pb.TagNumber(2)
  set status(ConnectionState_Status value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearStatus() => $_clearField(2);

  @$pb.TagNumber(3)
  $0.Timestamp get connectedAt => $_getN(2);
  @$pb.TagNumber(3)
  set connectedAt($0.Timestamp value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasConnectedAt() => $_has(2);
  @$pb.TagNumber(3)
  void clearConnectedAt() => $_clearField(3);
  @$pb.TagNumber(3)
  $0.Timestamp ensureConnectedAt() => $_ensure(2);

  @$pb.TagNumber(4)
  $pb.PbMap<$core.String, $core.String> get metadata => $_getMap(3);
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
    final result = create();
    if (peerId != null) result.peerId = peerId;
    if (messagesSent != null) result.messagesSent = messagesSent;
    if (messagesReceived != null) result.messagesReceived = messagesReceived;
    if (bytesSent != null) result.bytesSent = bytesSent;
    if (bytesReceived != null) result.bytesReceived = bytesReceived;
    if (averageLatencyMs != null) result.averageLatencyMs = averageLatencyMs;
    return result;
  }

  ConnectionMetrics._();

  factory ConnectionMetrics.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ConnectionMetrics.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

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
    ..aI(6, _omitFieldNames ? '' : 'averageLatencyMs',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConnectionMetrics clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConnectionMetrics copyWith(void Function(ConnectionMetrics) updates) =>
      super.copyWith((message) => updates(message as ConnectionMetrics))
          as ConnectionMetrics;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ConnectionMetrics create() => ConnectionMetrics._();
  @$core.override
  ConnectionMetrics createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ConnectionMetrics getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ConnectionMetrics>(create);
  static ConnectionMetrics? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get peerId => $_getSZ(0);
  @$pb.TagNumber(1)
  set peerId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPeerId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get messagesSent => $_getI64(1);
  @$pb.TagNumber(2)
  set messagesSent($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessagesSent() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessagesSent() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get messagesReceived => $_getI64(2);
  @$pb.TagNumber(3)
  set messagesReceived($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMessagesReceived() => $_has(2);
  @$pb.TagNumber(3)
  void clearMessagesReceived() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get bytesSent => $_getI64(3);
  @$pb.TagNumber(4)
  set bytesSent($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBytesSent() => $_has(3);
  @$pb.TagNumber(4)
  void clearBytesSent() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get bytesReceived => $_getI64(4);
  @$pb.TagNumber(5)
  set bytesReceived($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasBytesReceived() => $_has(4);
  @$pb.TagNumber(5)
  void clearBytesReceived() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get averageLatencyMs => $_getIZ(5);
  @$pb.TagNumber(6)
  set averageLatencyMs($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasAverageLatencyMs() => $_has(5);
  @$pb.TagNumber(6)
  void clearAverageLatencyMs() => $_clearField(6);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
