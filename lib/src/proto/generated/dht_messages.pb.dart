//
//  Generated code. Do not modify.
//  source: dht_messages.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'dht_messages.pbenum.dart';
import 'google/protobuf/timestamp.pb.dart' as $0;

export 'dht_messages.pbenum.dart';

class DHTMessage extends $pb.GeneratedMessage {
  factory DHTMessage({
    $core.String? messageId,
    DHTMessage_MessageType? type,
    $core.List<$core.int>? key,
    $core.List<$core.int>? value,
    $core.Iterable<$core.String>? closerPeers,
    $0.Timestamp? timestamp,
  }) {
    final $result = create();
    if (messageId != null) {
      $result.messageId = messageId;
    }
    if (type != null) {
      $result.type = type;
    }
    if (key != null) {
      $result.key = key;
    }
    if (value != null) {
      $result.value = value;
    }
    if (closerPeers != null) {
      $result.closerPeers.addAll(closerPeers);
    }
    if (timestamp != null) {
      $result.timestamp = timestamp;
    }
    return $result;
  }
  DHTMessage._() : super();
  factory DHTMessage.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DHTMessage.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DHTMessage', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'messageId')
    ..e<DHTMessage_MessageType>(2, _omitFieldNames ? '' : 'type', $pb.PbFieldType.OE, defaultOrMaker: DHTMessage_MessageType.UNKNOWN, valueOf: DHTMessage_MessageType.valueOf, enumValues: DHTMessage_MessageType.values)
    ..a<$core.List<$core.int>>(3, _omitFieldNames ? '' : 'key', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(4, _omitFieldNames ? '' : 'value', $pb.PbFieldType.OY)
    ..pPS(5, _omitFieldNames ? '' : 'closerPeers')
    ..aOM<$0.Timestamp>(6, _omitFieldNames ? '' : 'timestamp', subBuilder: $0.Timestamp.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DHTMessage clone() => DHTMessage()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DHTMessage copyWith(void Function(DHTMessage) updates) => super.copyWith((message) => updates(message as DHTMessage)) as DHTMessage;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DHTMessage create() => DHTMessage._();
  DHTMessage createEmptyInstance() => create();
  static $pb.PbList<DHTMessage> createRepeated() => $pb.PbList<DHTMessage>();
  @$core.pragma('dart2js:noInline')
  static DHTMessage getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DHTMessage>(create);
  static DHTMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get messageId => $_getSZ(0);
  @$pb.TagNumber(1)
  set messageId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasMessageId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessageId() => clearField(1);

  @$pb.TagNumber(2)
  DHTMessage_MessageType get type => $_getN(1);
  @$pb.TagNumber(2)
  set type(DHTMessage_MessageType v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasType() => $_has(1);
  @$pb.TagNumber(2)
  void clearType() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get key => $_getN(2);
  @$pb.TagNumber(3)
  set key($core.List<$core.int> v) { $_setBytes(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasKey() => $_has(2);
  @$pb.TagNumber(3)
  void clearKey() => clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get value => $_getN(3);
  @$pb.TagNumber(4)
  set value($core.List<$core.int> v) { $_setBytes(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasValue() => $_has(3);
  @$pb.TagNumber(4)
  void clearValue() => clearField(4);

  @$pb.TagNumber(5)
  $core.List<$core.String> get closerPeers => $_getList(4);

  @$pb.TagNumber(6)
  $0.Timestamp get timestamp => $_getN(5);
  @$pb.TagNumber(6)
  set timestamp($0.Timestamp v) { setField(6, v); }
  @$pb.TagNumber(6)
  $core.bool hasTimestamp() => $_has(5);
  @$pb.TagNumber(6)
  void clearTimestamp() => clearField(6);
  @$pb.TagNumber(6)
  $0.Timestamp ensureTimestamp() => $_ensure(5);
}

class FindNodeRequest extends $pb.GeneratedMessage {
  factory FindNodeRequest({
    $core.List<$core.int>? targetId,
    $core.int? numClosestPeers,
  }) {
    final $result = create();
    if (targetId != null) {
      $result.targetId = targetId;
    }
    if (numClosestPeers != null) {
      $result.numClosestPeers = numClosestPeers;
    }
    return $result;
  }
  FindNodeRequest._() : super();
  factory FindNodeRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory FindNodeRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'FindNodeRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'targetId', $pb.PbFieldType.OY)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'numClosestPeers', $pb.PbFieldType.OU3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  FindNodeRequest clone() => FindNodeRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  FindNodeRequest copyWith(void Function(FindNodeRequest) updates) => super.copyWith((message) => updates(message as FindNodeRequest)) as FindNodeRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FindNodeRequest create() => FindNodeRequest._();
  FindNodeRequest createEmptyInstance() => create();
  static $pb.PbList<FindNodeRequest> createRepeated() => $pb.PbList<FindNodeRequest>();
  @$core.pragma('dart2js:noInline')
  static FindNodeRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FindNodeRequest>(create);
  static FindNodeRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get targetId => $_getN(0);
  @$pb.TagNumber(1)
  set targetId($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasTargetId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTargetId() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get numClosestPeers => $_getIZ(1);
  @$pb.TagNumber(2)
  set numClosestPeers($core.int v) { $_setUnsignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasNumClosestPeers() => $_has(1);
  @$pb.TagNumber(2)
  void clearNumClosestPeers() => clearField(2);
}

class FindNodeResponse extends $pb.GeneratedMessage {
  factory FindNodeResponse({
    $core.Iterable<Peer>? closerPeers,
  }) {
    final $result = create();
    if (closerPeers != null) {
      $result.closerPeers.addAll(closerPeers);
    }
    return $result;
  }
  FindNodeResponse._() : super();
  factory FindNodeResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory FindNodeResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'FindNodeResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht'), createEmptyInstance: create)
    ..pc<Peer>(1, _omitFieldNames ? '' : 'closerPeers', $pb.PbFieldType.PM, subBuilder: Peer.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  FindNodeResponse clone() => FindNodeResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  FindNodeResponse copyWith(void Function(FindNodeResponse) updates) => super.copyWith((message) => updates(message as FindNodeResponse)) as FindNodeResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FindNodeResponse create() => FindNodeResponse._();
  FindNodeResponse createEmptyInstance() => create();
  static $pb.PbList<FindNodeResponse> createRepeated() => $pb.PbList<FindNodeResponse>();
  @$core.pragma('dart2js:noInline')
  static FindNodeResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FindNodeResponse>(create);
  static FindNodeResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<Peer> get closerPeers => $_getList(0);
}

class Peer extends $pb.GeneratedMessage {
  factory Peer({
    $core.List<$core.int>? peerId,
    $core.Iterable<$core.String>? addresses,
    $core.Map<$core.String, $core.String>? metadata,
  }) {
    final $result = create();
    if (peerId != null) {
      $result.peerId = peerId;
    }
    if (addresses != null) {
      $result.addresses.addAll(addresses);
    }
    if (metadata != null) {
      $result.metadata.addAll(metadata);
    }
    return $result;
  }
  Peer._() : super();
  factory Peer.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Peer.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Peer', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'peerId', $pb.PbFieldType.OY)
    ..pPS(2, _omitFieldNames ? '' : 'addresses')
    ..m<$core.String, $core.String>(3, _omitFieldNames ? '' : 'metadata', entryClassName: 'Peer.MetadataEntry', keyFieldType: $pb.PbFieldType.OS, valueFieldType: $pb.PbFieldType.OS, packageName: const $pb.PackageName('ipfs.dht'))
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  Peer clone() => Peer()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  Peer copyWith(void Function(Peer) updates) => super.copyWith((message) => updates(message as Peer)) as Peer;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Peer create() => Peer._();
  Peer createEmptyInstance() => create();
  static $pb.PbList<Peer> createRepeated() => $pb.PbList<Peer>();
  @$core.pragma('dart2js:noInline')
  static Peer getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Peer>(create);
  static Peer? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get peerId => $_getN(0);
  @$pb.TagNumber(1)
  set peerId($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasPeerId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerId() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.String> get addresses => $_getList(1);

  @$pb.TagNumber(3)
  $core.Map<$core.String, $core.String> get metadata => $_getMap(2);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
