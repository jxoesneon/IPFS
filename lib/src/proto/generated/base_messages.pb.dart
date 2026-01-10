//
//  Generated code. Do not modify.
//  source: base_messages.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'base_messages.pbenum.dart';
import 'google/protobuf/timestamp.pb.dart' as $7;

export 'base_messages.pbenum.dart';

/// Base message wrapper for all IPFS messages
class IPFSMessage extends $pb.GeneratedMessage {
  factory IPFSMessage({
    $core.String? protocolId,
    $core.List<$core.int>? payload,
    $7.Timestamp? timestamp,
    $core.String? senderId,
    IPFSMessage_MessageType? type,
    $core.String? requestId,
  }) {
    final $result = create();
    if (protocolId != null) {
      $result.protocolId = protocolId;
    }
    if (payload != null) {
      $result.payload = payload;
    }
    if (timestamp != null) {
      $result.timestamp = timestamp;
    }
    if (senderId != null) {
      $result.senderId = senderId;
    }
    if (type != null) {
      $result.type = type;
    }
    if (requestId != null) {
      $result.requestId = requestId;
    }
    return $result;
  }
  IPFSMessage._() : super();
  factory IPFSMessage.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory IPFSMessage.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'IPFSMessage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.base'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'protocolId')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'payload', $pb.PbFieldType.OY)
    ..aOM<$7.Timestamp>(3, _omitFieldNames ? '' : 'timestamp',
        subBuilder: $7.Timestamp.create)
    ..aOS(4, _omitFieldNames ? '' : 'senderId')
    ..e<IPFSMessage_MessageType>(
        5, _omitFieldNames ? '' : 'type', $pb.PbFieldType.OE,
        defaultOrMaker: IPFSMessage_MessageType.UNKNOWN,
        valueOf: IPFSMessage_MessageType.valueOf,
        enumValues: IPFSMessage_MessageType.values)
    ..aOS(6, _omitFieldNames ? '' : 'requestId')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  IPFSMessage clone() => IPFSMessage()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  IPFSMessage copyWith(void Function(IPFSMessage) updates) =>
      super.copyWith((message) => updates(message as IPFSMessage))
          as IPFSMessage;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static IPFSMessage create() => IPFSMessage._();
  IPFSMessage createEmptyInstance() => create();
  static $pb.PbList<IPFSMessage> createRepeated() => $pb.PbList<IPFSMessage>();
  @$core.pragma('dart2js:noInline')
  static IPFSMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<IPFSMessage>(create);
  static IPFSMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get protocolId => $_getSZ(0);
  @$pb.TagNumber(1)
  set protocolId($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasProtocolId() => $_has(0);
  @$pb.TagNumber(1)
  void clearProtocolId() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get payload => $_getN(1);
  @$pb.TagNumber(2)
  set payload($core.List<$core.int> v) {
    $_setBytes(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasPayload() => $_has(1);
  @$pb.TagNumber(2)
  void clearPayload() => clearField(2);

  @$pb.TagNumber(3)
  $7.Timestamp get timestamp => $_getN(2);
  @$pb.TagNumber(3)
  set timestamp($7.Timestamp v) {
    setField(3, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasTimestamp() => $_has(2);
  @$pb.TagNumber(3)
  void clearTimestamp() => clearField(3);
  @$pb.TagNumber(3)
  $7.Timestamp ensureTimestamp() => $_ensure(2);

  @$pb.TagNumber(4)
  $core.String get senderId => $_getSZ(3);
  @$pb.TagNumber(4)
  set senderId($core.String v) {
    $_setString(3, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasSenderId() => $_has(3);
  @$pb.TagNumber(4)
  void clearSenderId() => clearField(4);

  @$pb.TagNumber(5)
  IPFSMessage_MessageType get type => $_getN(4);
  @$pb.TagNumber(5)
  set type(IPFSMessage_MessageType v) {
    setField(5, v);
  }

  @$pb.TagNumber(5)
  $core.bool hasType() => $_has(4);
  @$pb.TagNumber(5)
  void clearType() => clearField(5);

  @$pb.TagNumber(6)
  $core.String get requestId => $_getSZ(5);
  @$pb.TagNumber(6)
  set requestId($core.String v) {
    $_setString(5, v);
  }

  @$pb.TagNumber(6)
  $core.bool hasRequestId() => $_has(5);
  @$pb.TagNumber(6)
  void clearRequestId() => clearField(6);
}

/// Network events
class NetworkEvent extends $pb.GeneratedMessage {
  factory NetworkEvent({
    $7.Timestamp? timestamp,
    $core.String? eventType,
    $core.String? peerId,
    $core.List<$core.int>? data,
  }) {
    final $result = create();
    if (timestamp != null) {
      $result.timestamp = timestamp;
    }
    if (eventType != null) {
      $result.eventType = eventType;
    }
    if (peerId != null) {
      $result.peerId = peerId;
    }
    if (data != null) {
      $result.data = data;
    }
    return $result;
  }
  NetworkEvent._() : super();
  factory NetworkEvent.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory NetworkEvent.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NetworkEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.base'),
      createEmptyInstance: create)
    ..aOM<$7.Timestamp>(1, _omitFieldNames ? '' : 'timestamp',
        subBuilder: $7.Timestamp.create)
    ..aOS(2, _omitFieldNames ? '' : 'eventType')
    ..aOS(3, _omitFieldNames ? '' : 'peerId')
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  NetworkEvent clone() => NetworkEvent()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  NetworkEvent copyWith(void Function(NetworkEvent) updates) =>
      super.copyWith((message) => updates(message as NetworkEvent))
          as NetworkEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NetworkEvent create() => NetworkEvent._();
  NetworkEvent createEmptyInstance() => create();
  static $pb.PbList<NetworkEvent> createRepeated() =>
      $pb.PbList<NetworkEvent>();
  @$core.pragma('dart2js:noInline')
  static NetworkEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NetworkEvent>(create);
  static NetworkEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $7.Timestamp get timestamp => $_getN(0);
  @$pb.TagNumber(1)
  set timestamp($7.Timestamp v) {
    setField(1, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasTimestamp() => $_has(0);
  @$pb.TagNumber(1)
  void clearTimestamp() => clearField(1);
  @$pb.TagNumber(1)
  $7.Timestamp ensureTimestamp() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get eventType => $_getSZ(1);
  @$pb.TagNumber(2)
  set eventType($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasEventType() => $_has(1);
  @$pb.TagNumber(2)
  void clearEventType() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get peerId => $_getSZ(2);
  @$pb.TagNumber(3)
  set peerId($core.String v) {
    $_setString(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasPeerId() => $_has(2);
  @$pb.TagNumber(3)
  void clearPeerId() => clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get data => $_getN(3);
  @$pb.TagNumber(4)
  set data($core.List<$core.int> v) {
    $_setBytes(3, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasData() => $_has(3);
  @$pb.TagNumber(4)
  void clearData() => clearField(4);
}

const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
