//
//  Generated code. Do not modify.
//  source: ipfs_node_network_events.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

enum NetworkEvent_Event {
  peerConnected, 
  peerDisconnected, 
  connectionAttempted, 
  connectionFailed, 
  messageReceived, 
  messageSent, 
  blockReceived, 
  blockSent, 
  dhtQueryStarted, 
  dhtQueryCompleted, 
  dhtValueFound, 
  dhtValueProvided, 
  pubsubMessagePublished, 
  pubsubMessageReceived, 
  pubsubSubscriptionCreated, 
  pubsubSubscriptionCancelled, 
  circuitRelayCreated, 
  circuitRelayClosed, 
  circuitRelayTraffic, 
  nodeStarted, 
  nodeStopped, 
  error, 
  networkChanged, 
  notSet
}

/// NetworkEvent represents different network events related to the IPFS node.
class NetworkEvent extends $pb.GeneratedMessage {
  factory NetworkEvent({
    PeerConnectedEvent? peerConnected,
    PeerDisconnectedEvent? peerDisconnected,
    ConnectionAttemptedEvent? connectionAttempted,
    ConnectionFailedEvent? connectionFailed,
    MessageReceivedEvent? messageReceived,
    MessageSentEvent? messageSent,
    BlockReceivedEvent? blockReceived,
    BlockSentEvent? blockSent,
    DhtQueryStartedEvent? dhtQueryStarted,
    DhtQueryCompletedEvent? dhtQueryCompleted,
    DhtValueFoundEvent? dhtValueFound,
    DhtValueProvidedEvent? dhtValueProvided,
    PubsubMessagePublishedEvent? pubsubMessagePublished,
    PubsubMessageReceivedEvent? pubsubMessageReceived,
    PubsubSubscriptionCreatedEvent? pubsubSubscriptionCreated,
    PubsubSubscriptionCancelledEvent? pubsubSubscriptionCancelled,
    CircuitRelayCreatedEvent? circuitRelayCreated,
    CircuitRelayClosedEvent? circuitRelayClosed,
    CircuitRelayTrafficEvent? circuitRelayTraffic,
    NodeStartedEvent? nodeStarted,
    NodeStoppedEvent? nodeStopped,
    ErrorEvent? error,
    NetworkChangedEvent? networkChanged,
  }) {
    final result = create();
    if (peerConnected != null) {
      result.peerConnected = peerConnected;
    }
    if (peerDisconnected != null) {
      result.peerDisconnected = peerDisconnected;
    }
    if (connectionAttempted != null) {
      result.connectionAttempted = connectionAttempted;
    }
    if (connectionFailed != null) {
      result.connectionFailed = connectionFailed;
    }
    if (messageReceived != null) {
      result.messageReceived = messageReceived;
    }
    if (messageSent != null) {
      result.messageSent = messageSent;
    }
    if (blockReceived != null) {
      result.blockReceived = blockReceived;
    }
    if (blockSent != null) {
      result.blockSent = blockSent;
    }
    if (dhtQueryStarted != null) {
      result.dhtQueryStarted = dhtQueryStarted;
    }
    if (dhtQueryCompleted != null) {
      result.dhtQueryCompleted = dhtQueryCompleted;
    }
    if (dhtValueFound != null) {
      result.dhtValueFound = dhtValueFound;
    }
    if (dhtValueProvided != null) {
      result.dhtValueProvided = dhtValueProvided;
    }
    if (pubsubMessagePublished != null) {
      result.pubsubMessagePublished = pubsubMessagePublished;
    }
    if (pubsubMessageReceived != null) {
      result.pubsubMessageReceived = pubsubMessageReceived;
    }
    if (pubsubSubscriptionCreated != null) {
      result.pubsubSubscriptionCreated = pubsubSubscriptionCreated;
    }
    if (pubsubSubscriptionCancelled != null) {
      result.pubsubSubscriptionCancelled = pubsubSubscriptionCancelled;
    }
    if (circuitRelayCreated != null) {
      result.circuitRelayCreated = circuitRelayCreated;
    }
    if (circuitRelayClosed != null) {
      result.circuitRelayClosed = circuitRelayClosed;
    }
    if (circuitRelayTraffic != null) {
      result.circuitRelayTraffic = circuitRelayTraffic;
    }
    if (nodeStarted != null) {
      result.nodeStarted = nodeStarted;
    }
    if (nodeStopped != null) {
      result.nodeStopped = nodeStopped;
    }
    if (error != null) {
      result.error = error;
    }
    if (networkChanged != null) {
      result.networkChanged = networkChanged;
    }
    return result;
  }
  NetworkEvent._() : super();
  factory NetworkEvent.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory NetworkEvent.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static const $core.Map<$core.int, NetworkEvent_Event> _NetworkEvent_EventByTag = {
    1 : NetworkEvent_Event.peerConnected,
    2 : NetworkEvent_Event.peerDisconnected,
    3 : NetworkEvent_Event.connectionAttempted,
    4 : NetworkEvent_Event.connectionFailed,
    5 : NetworkEvent_Event.messageReceived,
    6 : NetworkEvent_Event.messageSent,
    7 : NetworkEvent_Event.blockReceived,
    8 : NetworkEvent_Event.blockSent,
    9 : NetworkEvent_Event.dhtQueryStarted,
    10 : NetworkEvent_Event.dhtQueryCompleted,
    11 : NetworkEvent_Event.dhtValueFound,
    12 : NetworkEvent_Event.dhtValueProvided,
    13 : NetworkEvent_Event.pubsubMessagePublished,
    14 : NetworkEvent_Event.pubsubMessageReceived,
    15 : NetworkEvent_Event.pubsubSubscriptionCreated,
    16 : NetworkEvent_Event.pubsubSubscriptionCancelled,
    17 : NetworkEvent_Event.circuitRelayCreated,
    18 : NetworkEvent_Event.circuitRelayClosed,
    19 : NetworkEvent_Event.circuitRelayTraffic,
    20 : NetworkEvent_Event.nodeStarted,
    21 : NetworkEvent_Event.nodeStopped,
    22 : NetworkEvent_Event.error,
    23 : NetworkEvent_Event.networkChanged,
    0 : NetworkEvent_Event.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'NetworkEvent', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'), createEmptyInstance: create)
    ..oo(0, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23])
    ..aOM<PeerConnectedEvent>(1, _omitFieldNames ? '' : 'peerConnected', subBuilder: PeerConnectedEvent.create)
    ..aOM<PeerDisconnectedEvent>(2, _omitFieldNames ? '' : 'peerDisconnected', subBuilder: PeerDisconnectedEvent.create)
    ..aOM<ConnectionAttemptedEvent>(3, _omitFieldNames ? '' : 'connectionAttempted', subBuilder: ConnectionAttemptedEvent.create)
    ..aOM<ConnectionFailedEvent>(4, _omitFieldNames ? '' : 'connectionFailed', subBuilder: ConnectionFailedEvent.create)
    ..aOM<MessageReceivedEvent>(5, _omitFieldNames ? '' : 'messageReceived', subBuilder: MessageReceivedEvent.create)
    ..aOM<MessageSentEvent>(6, _omitFieldNames ? '' : 'messageSent', subBuilder: MessageSentEvent.create)
    ..aOM<BlockReceivedEvent>(7, _omitFieldNames ? '' : 'blockReceived', subBuilder: BlockReceivedEvent.create)
    ..aOM<BlockSentEvent>(8, _omitFieldNames ? '' : 'blockSent', subBuilder: BlockSentEvent.create)
    ..aOM<DhtQueryStartedEvent>(9, _omitFieldNames ? '' : 'dhtQueryStarted', subBuilder: DhtQueryStartedEvent.create)
    ..aOM<DhtQueryCompletedEvent>(10, _omitFieldNames ? '' : 'dhtQueryCompleted', subBuilder: DhtQueryCompletedEvent.create)
    ..aOM<DhtValueFoundEvent>(11, _omitFieldNames ? '' : 'dhtValueFound', subBuilder: DhtValueFoundEvent.create)
    ..aOM<DhtValueProvidedEvent>(12, _omitFieldNames ? '' : 'dhtValueProvided', subBuilder: DhtValueProvidedEvent.create)
    ..aOM<PubsubMessagePublishedEvent>(13, _omitFieldNames ? '' : 'pubsubMessagePublished', subBuilder: PubsubMessagePublishedEvent.create)
    ..aOM<PubsubMessageReceivedEvent>(14, _omitFieldNames ? '' : 'pubsubMessageReceived', subBuilder: PubsubMessageReceivedEvent.create)
    ..aOM<PubsubSubscriptionCreatedEvent>(15, _omitFieldNames ? '' : 'pubsubSubscriptionCreated', subBuilder: PubsubSubscriptionCreatedEvent.create)
    ..aOM<PubsubSubscriptionCancelledEvent>(16, _omitFieldNames ? '' : 'pubsubSubscriptionCancelled', subBuilder: PubsubSubscriptionCancelledEvent.create)
    ..aOM<CircuitRelayCreatedEvent>(17, _omitFieldNames ? '' : 'circuitRelayCreated', subBuilder: CircuitRelayCreatedEvent.create)
    ..aOM<CircuitRelayClosedEvent>(18, _omitFieldNames ? '' : 'circuitRelayClosed', subBuilder: CircuitRelayClosedEvent.create)
    ..aOM<CircuitRelayTrafficEvent>(19, _omitFieldNames ? '' : 'circuitRelayTraffic', subBuilder: CircuitRelayTrafficEvent.create)
    ..aOM<NodeStartedEvent>(20, _omitFieldNames ? '' : 'nodeStarted', subBuilder: NodeStartedEvent.create)
    ..aOM<NodeStoppedEvent>(21, _omitFieldNames ? '' : 'nodeStopped', subBuilder: NodeStoppedEvent.create)
    ..aOM<ErrorEvent>(22, _omitFieldNames ? '' : 'error', subBuilder: ErrorEvent.create)
    ..aOM<NetworkChangedEvent>(23, _omitFieldNames ? '' : 'networkChanged', subBuilder: NetworkChangedEvent.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  NetworkEvent clone() => NetworkEvent()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  NetworkEvent copyWith(void Function(NetworkEvent) updates) => super.copyWith((message) => updates(message as NetworkEvent)) as NetworkEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NetworkEvent create() => NetworkEvent._();
  NetworkEvent createEmptyInstance() => create();
  static $pb.PbList<NetworkEvent> createRepeated() => $pb.PbList<NetworkEvent>();
  @$core.pragma('dart2js:noInline')
  static NetworkEvent getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<NetworkEvent>(create);
  static NetworkEvent? _defaultInstance;

  NetworkEvent_Event whichEvent() => _NetworkEvent_EventByTag[$_whichOneof(0)]!;
  void clearEvent() => clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  PeerConnectedEvent get peerConnected => $_getN(0);
  @$pb.TagNumber(1)
  set peerConnected(PeerConnectedEvent v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasPeerConnected() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerConnected() => clearField(1);
  @$pb.TagNumber(1)
  PeerConnectedEvent ensurePeerConnected() => $_ensure(0);

  @$pb.TagNumber(2)
  PeerDisconnectedEvent get peerDisconnected => $_getN(1);
  @$pb.TagNumber(2)
  set peerDisconnected(PeerDisconnectedEvent v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasPeerDisconnected() => $_has(1);
  @$pb.TagNumber(2)
  void clearPeerDisconnected() => clearField(2);
  @$pb.TagNumber(2)
  PeerDisconnectedEvent ensurePeerDisconnected() => $_ensure(1);

  @$pb.TagNumber(3)
  ConnectionAttemptedEvent get connectionAttempted => $_getN(2);
  @$pb.TagNumber(3)
  set connectionAttempted(ConnectionAttemptedEvent v) { setField(3, v); }
  @$pb.TagNumber(3)
  $core.bool hasConnectionAttempted() => $_has(2);
  @$pb.TagNumber(3)
  void clearConnectionAttempted() => clearField(3);
  @$pb.TagNumber(3)
  ConnectionAttemptedEvent ensureConnectionAttempted() => $_ensure(2);

  @$pb.TagNumber(4)
  ConnectionFailedEvent get connectionFailed => $_getN(3);
  @$pb.TagNumber(4)
  set connectionFailed(ConnectionFailedEvent v) { setField(4, v); }
  @$pb.TagNumber(4)
  $core.bool hasConnectionFailed() => $_has(3);
  @$pb.TagNumber(4)
  void clearConnectionFailed() => clearField(4);
  @$pb.TagNumber(4)
  ConnectionFailedEvent ensureConnectionFailed() => $_ensure(3);

  @$pb.TagNumber(5)
  MessageReceivedEvent get messageReceived => $_getN(4);
  @$pb.TagNumber(5)
  set messageReceived(MessageReceivedEvent v) { setField(5, v); }
  @$pb.TagNumber(5)
  $core.bool hasMessageReceived() => $_has(4);
  @$pb.TagNumber(5)
  void clearMessageReceived() => clearField(5);
  @$pb.TagNumber(5)
  MessageReceivedEvent ensureMessageReceived() => $_ensure(4);

  @$pb.TagNumber(6)
  MessageSentEvent get messageSent => $_getN(5);
  @$pb.TagNumber(6)
  set messageSent(MessageSentEvent v) { setField(6, v); }
  @$pb.TagNumber(6)
  $core.bool hasMessageSent() => $_has(5);
  @$pb.TagNumber(6)
  void clearMessageSent() => clearField(6);
  @$pb.TagNumber(6)
  MessageSentEvent ensureMessageSent() => $_ensure(5);

  @$pb.TagNumber(7)
  BlockReceivedEvent get blockReceived => $_getN(6);
  @$pb.TagNumber(7)
  set blockReceived(BlockReceivedEvent v) { setField(7, v); }
  @$pb.TagNumber(7)
  $core.bool hasBlockReceived() => $_has(6);
  @$pb.TagNumber(7)
  void clearBlockReceived() => clearField(7);
  @$pb.TagNumber(7)
  BlockReceivedEvent ensureBlockReceived() => $_ensure(6);

  @$pb.TagNumber(8)
  BlockSentEvent get blockSent => $_getN(7);
  @$pb.TagNumber(8)
  set blockSent(BlockSentEvent v) { setField(8, v); }
  @$pb.TagNumber(8)
  $core.bool hasBlockSent() => $_has(7);
  @$pb.TagNumber(8)
  void clearBlockSent() => clearField(8);
  @$pb.TagNumber(8)
  BlockSentEvent ensureBlockSent() => $_ensure(7);

  @$pb.TagNumber(9)
  DhtQueryStartedEvent get dhtQueryStarted => $_getN(8);
  @$pb.TagNumber(9)
  set dhtQueryStarted(DhtQueryStartedEvent v) { setField(9, v); }
  @$pb.TagNumber(9)
  $core.bool hasDhtQueryStarted() => $_has(8);
  @$pb.TagNumber(9)
  void clearDhtQueryStarted() => clearField(9);
  @$pb.TagNumber(9)
  DhtQueryStartedEvent ensureDhtQueryStarted() => $_ensure(8);

  @$pb.TagNumber(10)
  DhtQueryCompletedEvent get dhtQueryCompleted => $_getN(9);
  @$pb.TagNumber(10)
  set dhtQueryCompleted(DhtQueryCompletedEvent v) { setField(10, v); }
  @$pb.TagNumber(10)
  $core.bool hasDhtQueryCompleted() => $_has(9);
  @$pb.TagNumber(10)
  void clearDhtQueryCompleted() => clearField(10);
  @$pb.TagNumber(10)
  DhtQueryCompletedEvent ensureDhtQueryCompleted() => $_ensure(9);

  @$pb.TagNumber(11)
  DhtValueFoundEvent get dhtValueFound => $_getN(10);
  @$pb.TagNumber(11)
  set dhtValueFound(DhtValueFoundEvent v) { setField(11, v); }
  @$pb.TagNumber(11)
  $core.bool hasDhtValueFound() => $_has(10);
  @$pb.TagNumber(11)
  void clearDhtValueFound() => clearField(11);
  @$pb.TagNumber(11)
  DhtValueFoundEvent ensureDhtValueFound() => $_ensure(10);

  @$pb.TagNumber(12)
  DhtValueProvidedEvent get dhtValueProvided => $_getN(11);
  @$pb.TagNumber(12)
  set dhtValueProvided(DhtValueProvidedEvent v) { setField(12, v); }
  @$pb.TagNumber(12)
  $core.bool hasDhtValueProvided() => $_has(11);
  @$pb.TagNumber(12)
  void clearDhtValueProvided() => clearField(12);
  @$pb.TagNumber(12)
  DhtValueProvidedEvent ensureDhtValueProvided() => $_ensure(11);

  @$pb.TagNumber(13)
  PubsubMessagePublishedEvent get pubsubMessagePublished => $_getN(12);
  @$pb.TagNumber(13)
  set pubsubMessagePublished(PubsubMessagePublishedEvent v) { setField(13, v); }
  @$pb.TagNumber(13)
  $core.bool hasPubsubMessagePublished() => $_has(12);
  @$pb.TagNumber(13)
  void clearPubsubMessagePublished() => clearField(13);
  @$pb.TagNumber(13)
  PubsubMessagePublishedEvent ensurePubsubMessagePublished() => $_ensure(12);

  @$pb.TagNumber(14)
  PubsubMessageReceivedEvent get pubsubMessageReceived => $_getN(13);
  @$pb.TagNumber(14)
  set pubsubMessageReceived(PubsubMessageReceivedEvent v) { setField(14, v); }
  @$pb.TagNumber(14)
  $core.bool hasPubsubMessageReceived() => $_has(13);
  @$pb.TagNumber(14)
  void clearPubsubMessageReceived() => clearField(14);
  @$pb.TagNumber(14)
  PubsubMessageReceivedEvent ensurePubsubMessageReceived() => $_ensure(13);

  @$pb.TagNumber(15)
  PubsubSubscriptionCreatedEvent get pubsubSubscriptionCreated => $_getN(14);
  @$pb.TagNumber(15)
  set pubsubSubscriptionCreated(PubsubSubscriptionCreatedEvent v) { setField(15, v); }
  @$pb.TagNumber(15)
  $core.bool hasPubsubSubscriptionCreated() => $_has(14);
  @$pb.TagNumber(15)
  void clearPubsubSubscriptionCreated() => clearField(15);
  @$pb.TagNumber(15)
  PubsubSubscriptionCreatedEvent ensurePubsubSubscriptionCreated() => $_ensure(14);

  @$pb.TagNumber(16)
  PubsubSubscriptionCancelledEvent get pubsubSubscriptionCancelled => $_getN(15);
  @$pb.TagNumber(16)
  set pubsubSubscriptionCancelled(PubsubSubscriptionCancelledEvent v) { setField(16, v); }
  @$pb.TagNumber(16)
  $core.bool hasPubsubSubscriptionCancelled() => $_has(15);
  @$pb.TagNumber(16)
  void clearPubsubSubscriptionCancelled() => clearField(16);
  @$pb.TagNumber(16)
  PubsubSubscriptionCancelledEvent ensurePubsubSubscriptionCancelled() => $_ensure(15);

  @$pb.TagNumber(17)
  CircuitRelayCreatedEvent get circuitRelayCreated => $_getN(16);
  @$pb.TagNumber(17)
  set circuitRelayCreated(CircuitRelayCreatedEvent v) { setField(17, v); }
  @$pb.TagNumber(17)
  $core.bool hasCircuitRelayCreated() => $_has(16);
  @$pb.TagNumber(17)
  void clearCircuitRelayCreated() => clearField(17);
  @$pb.TagNumber(17)
  CircuitRelayCreatedEvent ensureCircuitRelayCreated() => $_ensure(16);

  @$pb.TagNumber(18)
  CircuitRelayClosedEvent get circuitRelayClosed => $_getN(17);
  @$pb.TagNumber(18)
  set circuitRelayClosed(CircuitRelayClosedEvent v) { setField(18, v); }
  @$pb.TagNumber(18)
  $core.bool hasCircuitRelayClosed() => $_has(17);
  @$pb.TagNumber(18)
  void clearCircuitRelayClosed() => clearField(18);
  @$pb.TagNumber(18)
  CircuitRelayClosedEvent ensureCircuitRelayClosed() => $_ensure(17);

  @$pb.TagNumber(19)
  CircuitRelayTrafficEvent get circuitRelayTraffic => $_getN(18);
  @$pb.TagNumber(19)
  set circuitRelayTraffic(CircuitRelayTrafficEvent v) { setField(19, v); }
  @$pb.TagNumber(19)
  $core.bool hasCircuitRelayTraffic() => $_has(18);
  @$pb.TagNumber(19)
  void clearCircuitRelayTraffic() => clearField(19);
  @$pb.TagNumber(19)
  CircuitRelayTrafficEvent ensureCircuitRelayTraffic() => $_ensure(18);

  @$pb.TagNumber(20)
  NodeStartedEvent get nodeStarted => $_getN(19);
  @$pb.TagNumber(20)
  set nodeStarted(NodeStartedEvent v) { setField(20, v); }
  @$pb.TagNumber(20)
  $core.bool hasNodeStarted() => $_has(19);
  @$pb.TagNumber(20)
  void clearNodeStarted() => clearField(20);
  @$pb.TagNumber(20)
  NodeStartedEvent ensureNodeStarted() => $_ensure(19);

  @$pb.TagNumber(21)
  NodeStoppedEvent get nodeStopped => $_getN(20);
  @$pb.TagNumber(21)
  set nodeStopped(NodeStoppedEvent v) { setField(21, v); }
  @$pb.TagNumber(21)
  $core.bool hasNodeStopped() => $_has(20);
  @$pb.TagNumber(21)
  void clearNodeStopped() => clearField(21);
  @$pb.TagNumber(21)
  NodeStoppedEvent ensureNodeStopped() => $_ensure(20);

  @$pb.TagNumber(22)
  ErrorEvent get error => $_getN(21);
  @$pb.TagNumber(22)
  set error(ErrorEvent v) { setField(22, v); }
  @$pb.TagNumber(22)
  $core.bool hasError() => $_has(21);
  @$pb.TagNumber(22)
  void clearError() => clearField(22);
  @$pb.TagNumber(22)
  ErrorEvent ensureError() => $_ensure(21);

  @$pb.TagNumber(23)
  NetworkChangedEvent get networkChanged => $_getN(22);
  @$pb.TagNumber(23)
  set networkChanged(NetworkChangedEvent v) { setField(23, v); }
  @$pb.TagNumber(23)
  $core.bool hasNetworkChanged() => $_has(22);
  @$pb.TagNumber(23)
  void clearNetworkChanged() => clearField(23);
  @$pb.TagNumber(23)
  NetworkChangedEvent ensureNetworkChanged() => $_ensure(22);
}

class PeerConnectedEvent extends $pb.GeneratedMessage {
  factory PeerConnectedEvent({
    $core.String? peerId,
    $core.String? multiaddress,
  }) {
    final result = create();
    if (peerId != null) {
      result.peerId = peerId;
    }
    if (multiaddress != null) {
      result.multiaddress = multiaddress;
    }
    return result;
  }
  PeerConnectedEvent._() : super();
  factory PeerConnectedEvent.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PeerConnectedEvent.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PeerConnectedEvent', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'peerId')
    ..aOS(2, _omitFieldNames ? '' : 'multiaddress')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PeerConnectedEvent clone() => PeerConnectedEvent()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PeerConnectedEvent copyWith(void Function(PeerConnectedEvent) updates) => super.copyWith((message) => updates(message as PeerConnectedEvent)) as PeerConnectedEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PeerConnectedEvent create() => PeerConnectedEvent._();
  PeerConnectedEvent createEmptyInstance() => create();
  static $pb.PbList<PeerConnectedEvent> createRepeated() => $pb.PbList<PeerConnectedEvent>();
  @$core.pragma('dart2js:noInline')
  static PeerConnectedEvent getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PeerConnectedEvent>(create);
  static PeerConnectedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get peerId => $_getSZ(0);
  @$pb.TagNumber(1)
  set peerId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasPeerId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get multiaddress => $_getSZ(1);
  @$pb.TagNumber(2)
  set multiaddress($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMultiaddress() => $_has(1);
  @$pb.TagNumber(2)
  void clearMultiaddress() => clearField(2);
}

class PeerDisconnectedEvent extends $pb.GeneratedMessage {
  factory PeerDisconnectedEvent({
    $core.String? peerId,
    $core.String? reason,
  }) {
    final result = create();
    if (peerId != null) {
      result.peerId = peerId;
    }
    if (reason != null) {
      result.reason = reason;
    }
    return result;
  }
  PeerDisconnectedEvent._() : super();
  factory PeerDisconnectedEvent.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PeerDisconnectedEvent.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PeerDisconnectedEvent', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'peerId')
    ..aOS(2, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PeerDisconnectedEvent clone() => PeerDisconnectedEvent()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PeerDisconnectedEvent copyWith(void Function(PeerDisconnectedEvent) updates) => super.copyWith((message) => updates(message as PeerDisconnectedEvent)) as PeerDisconnectedEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PeerDisconnectedEvent create() => PeerDisconnectedEvent._();
  PeerDisconnectedEvent createEmptyInstance() => create();
  static $pb.PbList<PeerDisconnectedEvent> createRepeated() => $pb.PbList<PeerDisconnectedEvent>();
  @$core.pragma('dart2js:noInline')
  static PeerDisconnectedEvent getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PeerDisconnectedEvent>(create);
  static PeerDisconnectedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get peerId => $_getSZ(0);
  @$pb.TagNumber(1)
  set peerId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasPeerId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get reason => $_getSZ(1);
  @$pb.TagNumber(2)
  set reason($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasReason() => $_has(1);
  @$pb.TagNumber(2)
  void clearReason() => clearField(2);
}

class ConnectionAttemptedEvent extends $pb.GeneratedMessage {
  factory ConnectionAttemptedEvent({
    $core.String? peerId,
    $core.bool? success,
  }) {
    final result = create();
    if (peerId != null) {
      result.peerId = peerId;
    }
    if (success != null) {
      result.success = success;
    }
    return result;
  }
  ConnectionAttemptedEvent._() : super();
  factory ConnectionAttemptedEvent.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ConnectionAttemptedEvent.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ConnectionAttemptedEvent', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'peerId')
    ..aOB(2, _omitFieldNames ? '' : 'success')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ConnectionAttemptedEvent clone() => ConnectionAttemptedEvent()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ConnectionAttemptedEvent copyWith(void Function(ConnectionAttemptedEvent) updates) => super.copyWith((message) => updates(message as ConnectionAttemptedEvent)) as ConnectionAttemptedEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ConnectionAttemptedEvent create() => ConnectionAttemptedEvent._();
  ConnectionAttemptedEvent createEmptyInstance() => create();
  static $pb.PbList<ConnectionAttemptedEvent> createRepeated() => $pb.PbList<ConnectionAttemptedEvent>();
  @$core.pragma('dart2js:noInline')
  static ConnectionAttemptedEvent getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ConnectionAttemptedEvent>(create);
  static ConnectionAttemptedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get peerId => $_getSZ(0);
  @$pb.TagNumber(1)
  set peerId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasPeerId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerId() => clearField(1);

  @$pb.TagNumber(2)
  $core.bool get success => $_getBF(1);
  @$pb.TagNumber(2)
  set success($core.bool v) { $_setBool(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasSuccess() => $_has(1);
  @$pb.TagNumber(2)
  void clearSuccess() => clearField(2);
}

class ConnectionFailedEvent extends $pb.GeneratedMessage {
  factory ConnectionFailedEvent({
    $core.String? peerId,
    $core.String? reason,
  }) {
    final result = create();
    if (peerId != null) {
      result.peerId = peerId;
    }
    if (reason != null) {
      result.reason = reason;
    }
    return result;
  }
  ConnectionFailedEvent._() : super();
  factory ConnectionFailedEvent.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ConnectionFailedEvent.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ConnectionFailedEvent', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'peerId')
    ..aOS(2, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ConnectionFailedEvent clone() => ConnectionFailedEvent()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ConnectionFailedEvent copyWith(void Function(ConnectionFailedEvent) updates) => super.copyWith((message) => updates(message as ConnectionFailedEvent)) as ConnectionFailedEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ConnectionFailedEvent create() => ConnectionFailedEvent._();
  ConnectionFailedEvent createEmptyInstance() => create();
  static $pb.PbList<ConnectionFailedEvent> createRepeated() => $pb.PbList<ConnectionFailedEvent>();
  @$core.pragma('dart2js:noInline')
  static ConnectionFailedEvent getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ConnectionFailedEvent>(create);
  static ConnectionFailedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get peerId => $_getSZ(0);
  @$pb.TagNumber(1)
  set peerId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasPeerId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get reason => $_getSZ(1);
  @$pb.TagNumber(2)
  set reason($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasReason() => $_has(1);
  @$pb.TagNumber(2)
  void clearReason() => clearField(2);
}

class MessageReceivedEvent extends $pb.GeneratedMessage {
  factory MessageReceivedEvent({
    $core.String? peerId,
    $core.List<$core.int>? messageContent,
  }) {
    final result = create();
    if (peerId != null) {
      result.peerId = peerId;
    }
    if (messageContent != null) {
      result.messageContent = messageContent;
    }
    return result;
  }
  MessageReceivedEvent._() : super();
  factory MessageReceivedEvent.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory MessageReceivedEvent.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'MessageReceivedEvent', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'peerId')
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'messageContent', $pb.PbFieldType.OY)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  MessageReceivedEvent clone() => MessageReceivedEvent()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  MessageReceivedEvent copyWith(void Function(MessageReceivedEvent) updates) => super.copyWith((message) => updates(message as MessageReceivedEvent)) as MessageReceivedEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MessageReceivedEvent create() => MessageReceivedEvent._();
  MessageReceivedEvent createEmptyInstance() => create();
  static $pb.PbList<MessageReceivedEvent> createRepeated() => $pb.PbList<MessageReceivedEvent>();
  @$core.pragma('dart2js:noInline')
  static MessageReceivedEvent getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MessageReceivedEvent>(create);
  static MessageReceivedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get peerId => $_getSZ(0);
  @$pb.TagNumber(1)
  set peerId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasPeerId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerId() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get messageContent => $_getN(1);
  @$pb.TagNumber(2)
  set messageContent($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMessageContent() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessageContent() => clearField(2);
}

class MessageSentEvent extends $pb.GeneratedMessage {
  factory MessageSentEvent({
    $core.String? peerId,
    $core.List<$core.int>? messageContent,
  }) {
    final result = create();
    if (peerId != null) {
      result.peerId = peerId;
    }
    if (messageContent != null) {
      result.messageContent = messageContent;
    }
    return result;
  }
  MessageSentEvent._() : super();
  factory MessageSentEvent.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory MessageSentEvent.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'MessageSentEvent', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'peerId')
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'messageContent', $pb.PbFieldType.OY)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  MessageSentEvent clone() => MessageSentEvent()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  MessageSentEvent copyWith(void Function(MessageSentEvent) updates) => super.copyWith((message) => updates(message as MessageSentEvent)) as MessageSentEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MessageSentEvent create() => MessageSentEvent._();
  MessageSentEvent createEmptyInstance() => create();
  static $pb.PbList<MessageSentEvent> createRepeated() => $pb.PbList<MessageSentEvent>();
  @$core.pragma('dart2js:noInline')
  static MessageSentEvent getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MessageSentEvent>(create);
  static MessageSentEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get peerId => $_getSZ(0);
  @$pb.TagNumber(1)
  set peerId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasPeerId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerId() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get messageContent => $_getN(1);
  @$pb.TagNumber(2)
  set messageContent($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMessageContent() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessageContent() => clearField(2);
}

class BlockReceivedEvent extends $pb.GeneratedMessage {
  factory BlockReceivedEvent({
    $core.String? cid,
    $core.String? peerId,
  }) {
    final result = create();
    if (cid != null) {
      result.cid = cid;
    }
    if (peerId != null) {
      result.peerId = peerId;
    }
    return result;
  }
  BlockReceivedEvent._() : super();
  factory BlockReceivedEvent.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BlockReceivedEvent.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BlockReceivedEvent', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'cid')
    ..aOS(2, _omitFieldNames ? '' : 'peerId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BlockReceivedEvent clone() => BlockReceivedEvent()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BlockReceivedEvent copyWith(void Function(BlockReceivedEvent) updates) => super.copyWith((message) => updates(message as BlockReceivedEvent)) as BlockReceivedEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BlockReceivedEvent create() => BlockReceivedEvent._();
  BlockReceivedEvent createEmptyInstance() => create();
  static $pb.PbList<BlockReceivedEvent> createRepeated() => $pb.PbList<BlockReceivedEvent>();
  @$core.pragma('dart2js:noInline')
  static BlockReceivedEvent getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BlockReceivedEvent>(create);
  static BlockReceivedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get cid => $_getSZ(0);
  @$pb.TagNumber(1)
  set cid($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasCid() => $_has(0);
  @$pb.TagNumber(1)
  void clearCid() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get peerId => $_getSZ(1);
  @$pb.TagNumber(2)
  set peerId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasPeerId() => $_has(1);
  @$pb.TagNumber(2)
  void clearPeerId() => clearField(2);
}

class BlockSentEvent extends $pb.GeneratedMessage {
  factory BlockSentEvent({
    $core.String? cid,
    $core.String? peerId,
  }) {
    final result = create();
    if (cid != null) {
      result.cid = cid;
    }
    if (peerId != null) {
      result.peerId = peerId;
    }
    return result;
  }
  BlockSentEvent._() : super();
  factory BlockSentEvent.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BlockSentEvent.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BlockSentEvent', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'cid')
    ..aOS(2, _omitFieldNames ? '' : 'peerId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BlockSentEvent clone() => BlockSentEvent()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BlockSentEvent copyWith(void Function(BlockSentEvent) updates) => super.copyWith((message) => updates(message as BlockSentEvent)) as BlockSentEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BlockSentEvent create() => BlockSentEvent._();
  BlockSentEvent createEmptyInstance() => create();
  static $pb.PbList<BlockSentEvent> createRepeated() => $pb.PbList<BlockSentEvent>();
  @$core.pragma('dart2js:noInline')
  static BlockSentEvent getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BlockSentEvent>(create);
  static BlockSentEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get cid => $_getSZ(0);
  @$pb.TagNumber(1)
  set cid($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasCid() => $_has(0);
  @$pb.TagNumber(1)
  void clearCid() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get peerId => $_getSZ(1);
  @$pb.TagNumber(2)
  set peerId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasPeerId() => $_has(1);
  @$pb.TagNumber(2)
  void clearPeerId() => clearField(2);
}

class DhtQueryStartedEvent extends $pb.GeneratedMessage {
  factory DhtQueryStartedEvent({
    $core.String? queryType,
    $core.String? targetKey,
  }) {
    final result = create();
    if (queryType != null) {
      result.queryType = queryType;
    }
    if (targetKey != null) {
      result.targetKey = targetKey;
    }
    return result;
  }
  DhtQueryStartedEvent._() : super();
  factory DhtQueryStartedEvent.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DhtQueryStartedEvent.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DhtQueryStartedEvent', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'queryType')
    ..aOS(2, _omitFieldNames ? '' : 'targetKey')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DhtQueryStartedEvent clone() => DhtQueryStartedEvent()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DhtQueryStartedEvent copyWith(void Function(DhtQueryStartedEvent) updates) => super.copyWith((message) => updates(message as DhtQueryStartedEvent)) as DhtQueryStartedEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DhtQueryStartedEvent create() => DhtQueryStartedEvent._();
  DhtQueryStartedEvent createEmptyInstance() => create();
  static $pb.PbList<DhtQueryStartedEvent> createRepeated() => $pb.PbList<DhtQueryStartedEvent>();
  @$core.pragma('dart2js:noInline')
  static DhtQueryStartedEvent getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DhtQueryStartedEvent>(create);
  static DhtQueryStartedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get queryType => $_getSZ(0);
  @$pb.TagNumber(1)
  set queryType($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasQueryType() => $_has(0);
  @$pb.TagNumber(1)
  void clearQueryType() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get targetKey => $_getSZ(1);
  @$pb.TagNumber(2)
  set targetKey($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasTargetKey() => $_has(1);
  @$pb.TagNumber(2)
  void clearTargetKey() => clearField(2);
}

class DhtQueryCompletedEvent extends $pb.GeneratedMessage {
  factory DhtQueryCompletedEvent({
    $core.String? queryType,
    $core.String? targetKey,
    $core.Iterable<$core.String>? results,
  }) {
    final result = create();
    if (queryType != null) {
      result.queryType = queryType;
    }
    if (targetKey != null) {
      result.targetKey = targetKey;
    }
    if (results != null) {
      result.results.addAll(results);
    }
    return result;
  }
  DhtQueryCompletedEvent._() : super();
  factory DhtQueryCompletedEvent.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DhtQueryCompletedEvent.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DhtQueryCompletedEvent', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'queryType')
    ..aOS(2, _omitFieldNames ? '' : 'targetKey')
    ..pPS(3, _omitFieldNames ? '' : 'results')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DhtQueryCompletedEvent clone() => DhtQueryCompletedEvent()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DhtQueryCompletedEvent copyWith(void Function(DhtQueryCompletedEvent) updates) => super.copyWith((message) => updates(message as DhtQueryCompletedEvent)) as DhtQueryCompletedEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DhtQueryCompletedEvent create() => DhtQueryCompletedEvent._();
  DhtQueryCompletedEvent createEmptyInstance() => create();
  static $pb.PbList<DhtQueryCompletedEvent> createRepeated() => $pb.PbList<DhtQueryCompletedEvent>();
  @$core.pragma('dart2js:noInline')
  static DhtQueryCompletedEvent getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DhtQueryCompletedEvent>(create);
  static DhtQueryCompletedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get queryType => $_getSZ(0);
  @$pb.TagNumber(1)
  set queryType($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasQueryType() => $_has(0);
  @$pb.TagNumber(1)
  void clearQueryType() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get targetKey => $_getSZ(1);
  @$pb.TagNumber(2)
  set targetKey($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasTargetKey() => $_has(1);
  @$pb.TagNumber(2)
  void clearTargetKey() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.String> get results => $_getList(2);
}

class DhtValueFoundEvent extends $pb.GeneratedMessage {
  factory DhtValueFoundEvent({
    $core.String? key,
    $core.List<$core.int>? value,
    $core.String? peerId,
  }) {
    final result = create();
    if (key != null) {
      result.key = key;
    }
    if (value != null) {
      result.value = value;
    }
    if (peerId != null) {
      result.peerId = peerId;
    }
    return result;
  }
  DhtValueFoundEvent._() : super();
  factory DhtValueFoundEvent.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DhtValueFoundEvent.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DhtValueFoundEvent', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'key')
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'value', $pb.PbFieldType.OY)
    ..aOS(3, _omitFieldNames ? '' : 'peerId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DhtValueFoundEvent clone() => DhtValueFoundEvent()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DhtValueFoundEvent copyWith(void Function(DhtValueFoundEvent) updates) => super.copyWith((message) => updates(message as DhtValueFoundEvent)) as DhtValueFoundEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DhtValueFoundEvent create() => DhtValueFoundEvent._();
  DhtValueFoundEvent createEmptyInstance() => create();
  static $pb.PbList<DhtValueFoundEvent> createRepeated() => $pb.PbList<DhtValueFoundEvent>();
  @$core.pragma('dart2js:noInline')
  static DhtValueFoundEvent getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DhtValueFoundEvent>(create);
  static DhtValueFoundEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get key => $_getSZ(0);
  @$pb.TagNumber(1)
  set key($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get value => $_getN(1);
  @$pb.TagNumber(2)
  set value($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearValue() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get peerId => $_getSZ(2);
  @$pb.TagNumber(3)
  set peerId($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasPeerId() => $_has(2);
  @$pb.TagNumber(3)
  void clearPeerId() => clearField(3);
}

class DhtValueProvidedEvent extends $pb.GeneratedMessage {
  factory DhtValueProvidedEvent({
    $core.String? key,
    $core.List<$core.int>? value,
  }) {
    final result = create();
    if (key != null) {
      result.key = key;
    }
    if (value != null) {
      result.value = value;
    }
    return result;
  }
  DhtValueProvidedEvent._() : super();
  factory DhtValueProvidedEvent.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DhtValueProvidedEvent.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DhtValueProvidedEvent', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'key')
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'value', $pb.PbFieldType.OY)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DhtValueProvidedEvent clone() => DhtValueProvidedEvent()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DhtValueProvidedEvent copyWith(void Function(DhtValueProvidedEvent) updates) => super.copyWith((message) => updates(message as DhtValueProvidedEvent)) as DhtValueProvidedEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DhtValueProvidedEvent create() => DhtValueProvidedEvent._();
  DhtValueProvidedEvent createEmptyInstance() => create();
  static $pb.PbList<DhtValueProvidedEvent> createRepeated() => $pb.PbList<DhtValueProvidedEvent>();
  @$core.pragma('dart2js:noInline')
  static DhtValueProvidedEvent getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DhtValueProvidedEvent>(create);
  static DhtValueProvidedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get key => $_getSZ(0);
  @$pb.TagNumber(1)
  set key($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get value => $_getN(1);
  @$pb.TagNumber(2)
  set value($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearValue() => clearField(2);
}

class PubsubMessagePublishedEvent extends $pb.GeneratedMessage {
  factory PubsubMessagePublishedEvent({
    $core.String? topic,
    $core.List<$core.int>? messageContent,
  }) {
    final result = create();
    if (topic != null) {
      result.topic = topic;
    }
    if (messageContent != null) {
      result.messageContent = messageContent;
    }
    return result;
  }
  PubsubMessagePublishedEvent._() : super();
  factory PubsubMessagePublishedEvent.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PubsubMessagePublishedEvent.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PubsubMessagePublishedEvent', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'topic')
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'messageContent', $pb.PbFieldType.OY)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PubsubMessagePublishedEvent clone() => PubsubMessagePublishedEvent()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PubsubMessagePublishedEvent copyWith(void Function(PubsubMessagePublishedEvent) updates) => super.copyWith((message) => updates(message as PubsubMessagePublishedEvent)) as PubsubMessagePublishedEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PubsubMessagePublishedEvent create() => PubsubMessagePublishedEvent._();
  PubsubMessagePublishedEvent createEmptyInstance() => create();
  static $pb.PbList<PubsubMessagePublishedEvent> createRepeated() => $pb.PbList<PubsubMessagePublishedEvent>();
  @$core.pragma('dart2js:noInline')
  static PubsubMessagePublishedEvent getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PubsubMessagePublishedEvent>(create);
  static PubsubMessagePublishedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get topic => $_getSZ(0);
  @$pb.TagNumber(1)
  set topic($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasTopic() => $_has(0);
  @$pb.TagNumber(1)
  void clearTopic() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get messageContent => $_getN(1);
  @$pb.TagNumber(2)
  set messageContent($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMessageContent() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessageContent() => clearField(2);
}

class PubsubMessageReceivedEvent extends $pb.GeneratedMessage {
  factory PubsubMessageReceivedEvent({
    $core.String? topic,
    $core.List<$core.int>? messageContent,
    $core.String? peerId,
  }) {
    final result = create();
    if (topic != null) {
      result.topic = topic;
    }
    if (messageContent != null) {
      result.messageContent = messageContent;
    }
    if (peerId != null) {
      result.peerId = peerId;
    }
    return result;
  }
  PubsubMessageReceivedEvent._() : super();
  factory PubsubMessageReceivedEvent.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PubsubMessageReceivedEvent.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PubsubMessageReceivedEvent', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'topic')
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'messageContent', $pb.PbFieldType.OY)
    ..aOS(3, _omitFieldNames ? '' : 'peerId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PubsubMessageReceivedEvent clone() => PubsubMessageReceivedEvent()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PubsubMessageReceivedEvent copyWith(void Function(PubsubMessageReceivedEvent) updates) => super.copyWith((message) => updates(message as PubsubMessageReceivedEvent)) as PubsubMessageReceivedEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PubsubMessageReceivedEvent create() => PubsubMessageReceivedEvent._();
  PubsubMessageReceivedEvent createEmptyInstance() => create();
  static $pb.PbList<PubsubMessageReceivedEvent> createRepeated() => $pb.PbList<PubsubMessageReceivedEvent>();
  @$core.pragma('dart2js:noInline')
  static PubsubMessageReceivedEvent getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PubsubMessageReceivedEvent>(create);
  static PubsubMessageReceivedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get topic => $_getSZ(0);
  @$pb.TagNumber(1)
  set topic($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasTopic() => $_has(0);
  @$pb.TagNumber(1)
  void clearTopic() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get messageContent => $_getN(1);
  @$pb.TagNumber(2)
  set messageContent($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMessageContent() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessageContent() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get peerId => $_getSZ(2);
  @$pb.TagNumber(3)
  set peerId($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasPeerId() => $_has(2);
  @$pb.TagNumber(3)
  void clearPeerId() => clearField(3);
}

class PubsubSubscriptionCreatedEvent extends $pb.GeneratedMessage {
  factory PubsubSubscriptionCreatedEvent({
    $core.String? topic,
  }) {
    final result = create();
    if (topic != null) {
      result.topic = topic;
    }
    return result;
  }
  PubsubSubscriptionCreatedEvent._() : super();
  factory PubsubSubscriptionCreatedEvent.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PubsubSubscriptionCreatedEvent.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PubsubSubscriptionCreatedEvent', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'topic')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PubsubSubscriptionCreatedEvent clone() => PubsubSubscriptionCreatedEvent()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PubsubSubscriptionCreatedEvent copyWith(void Function(PubsubSubscriptionCreatedEvent) updates) => super.copyWith((message) => updates(message as PubsubSubscriptionCreatedEvent)) as PubsubSubscriptionCreatedEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PubsubSubscriptionCreatedEvent create() => PubsubSubscriptionCreatedEvent._();
  PubsubSubscriptionCreatedEvent createEmptyInstance() => create();
  static $pb.PbList<PubsubSubscriptionCreatedEvent> createRepeated() => $pb.PbList<PubsubSubscriptionCreatedEvent>();
  @$core.pragma('dart2js:noInline')
  static PubsubSubscriptionCreatedEvent getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PubsubSubscriptionCreatedEvent>(create);
  static PubsubSubscriptionCreatedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get topic => $_getSZ(0);
  @$pb.TagNumber(1)
  set topic($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasTopic() => $_has(0);
  @$pb.TagNumber(1)
  void clearTopic() => clearField(1);
}

class PubsubSubscriptionCancelledEvent extends $pb.GeneratedMessage {
  factory PubsubSubscriptionCancelledEvent({
    $core.String? topic,
  }) {
    final result = create();
    if (topic != null) {
      result.topic = topic;
    }
    return result;
  }
  PubsubSubscriptionCancelledEvent._() : super();
  factory PubsubSubscriptionCancelledEvent.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PubsubSubscriptionCancelledEvent.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PubsubSubscriptionCancelledEvent', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'topic')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PubsubSubscriptionCancelledEvent clone() => PubsubSubscriptionCancelledEvent()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PubsubSubscriptionCancelledEvent copyWith(void Function(PubsubSubscriptionCancelledEvent) updates) => super.copyWith((message) => updates(message as PubsubSubscriptionCancelledEvent)) as PubsubSubscriptionCancelledEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PubsubSubscriptionCancelledEvent create() => PubsubSubscriptionCancelledEvent._();
  PubsubSubscriptionCancelledEvent createEmptyInstance() => create();
  static $pb.PbList<PubsubSubscriptionCancelledEvent> createRepeated() => $pb.PbList<PubsubSubscriptionCancelledEvent>();
  @$core.pragma('dart2js:noInline')
  static PubsubSubscriptionCancelledEvent getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PubsubSubscriptionCancelledEvent>(create);
  static PubsubSubscriptionCancelledEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get topic => $_getSZ(0);
  @$pb.TagNumber(1)
  set topic($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasTopic() => $_has(0);
  @$pb.TagNumber(1)
  void clearTopic() => clearField(1);
}

class CircuitRelayCreatedEvent extends $pb.GeneratedMessage {
  factory CircuitRelayCreatedEvent({
    $core.String? relayAddress,
  }) {
    final result = create();
    if (relayAddress != null) {
      result.relayAddress = relayAddress;
    }
    return result;
  }
  CircuitRelayCreatedEvent._() : super();
  factory CircuitRelayCreatedEvent.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CircuitRelayCreatedEvent.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CircuitRelayCreatedEvent', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'relayAddress')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  CircuitRelayCreatedEvent clone() => CircuitRelayCreatedEvent()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  CircuitRelayCreatedEvent copyWith(void Function(CircuitRelayCreatedEvent) updates) => super.copyWith((message) => updates(message as CircuitRelayCreatedEvent)) as CircuitRelayCreatedEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CircuitRelayCreatedEvent create() => CircuitRelayCreatedEvent._();
  CircuitRelayCreatedEvent createEmptyInstance() => create();
  static $pb.PbList<CircuitRelayCreatedEvent> createRepeated() => $pb.PbList<CircuitRelayCreatedEvent>();
  @$core.pragma('dart2js:noInline')
  static CircuitRelayCreatedEvent getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CircuitRelayCreatedEvent>(create);
  static CircuitRelayCreatedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get relayAddress => $_getSZ(0);
  @$pb.TagNumber(1)
  set relayAddress($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasRelayAddress() => $_has(0);
  @$pb.TagNumber(1)
  void clearRelayAddress() => clearField(1);
}

class CircuitRelayClosedEvent extends $pb.GeneratedMessage {
  factory CircuitRelayClosedEvent({
    $core.String? relayAddress,
    $core.String? reason,
  }) {
    final result = create();
    if (relayAddress != null) {
      result.relayAddress = relayAddress;
    }
    if (reason != null) {
      result.reason = reason;
    }
    return result;
  }
  CircuitRelayClosedEvent._() : super();
  factory CircuitRelayClosedEvent.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CircuitRelayClosedEvent.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CircuitRelayClosedEvent', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'relayAddress')
    ..aOS(2, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  CircuitRelayClosedEvent clone() => CircuitRelayClosedEvent()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  CircuitRelayClosedEvent copyWith(void Function(CircuitRelayClosedEvent) updates) => super.copyWith((message) => updates(message as CircuitRelayClosedEvent)) as CircuitRelayClosedEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CircuitRelayClosedEvent create() => CircuitRelayClosedEvent._();
  CircuitRelayClosedEvent createEmptyInstance() => create();
  static $pb.PbList<CircuitRelayClosedEvent> createRepeated() => $pb.PbList<CircuitRelayClosedEvent>();
  @$core.pragma('dart2js:noInline')
  static CircuitRelayClosedEvent getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CircuitRelayClosedEvent>(create);
  static CircuitRelayClosedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get relayAddress => $_getSZ(0);
  @$pb.TagNumber(1)
  set relayAddress($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasRelayAddress() => $_has(0);
  @$pb.TagNumber(1)
  void clearRelayAddress() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get reason => $_getSZ(1);
  @$pb.TagNumber(2)
  set reason($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasReason() => $_has(1);
  @$pb.TagNumber(2)
  void clearReason() => clearField(2);
}

class CircuitRelayTrafficEvent extends $pb.GeneratedMessage {
  factory CircuitRelayTrafficEvent({
    $core.String? relayAddress,
    $fixnum.Int64? dataSize,
  }) {
    final result = create();
    if (relayAddress != null) {
      result.relayAddress = relayAddress;
    }
    if (dataSize != null) {
      result.dataSize = dataSize;
    }
    return result;
  }
  CircuitRelayTrafficEvent._() : super();
  factory CircuitRelayTrafficEvent.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CircuitRelayTrafficEvent.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CircuitRelayTrafficEvent', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'relayAddress')
    ..aInt64(2, _omitFieldNames ? '' : 'dataSize')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  CircuitRelayTrafficEvent clone() => CircuitRelayTrafficEvent()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  CircuitRelayTrafficEvent copyWith(void Function(CircuitRelayTrafficEvent) updates) => super.copyWith((message) => updates(message as CircuitRelayTrafficEvent)) as CircuitRelayTrafficEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CircuitRelayTrafficEvent create() => CircuitRelayTrafficEvent._();
  CircuitRelayTrafficEvent createEmptyInstance() => create();
  static $pb.PbList<CircuitRelayTrafficEvent> createRepeated() => $pb.PbList<CircuitRelayTrafficEvent>();
  @$core.pragma('dart2js:noInline')
  static CircuitRelayTrafficEvent getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CircuitRelayTrafficEvent>(create);
  static CircuitRelayTrafficEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get relayAddress => $_getSZ(0);
  @$pb.TagNumber(1)
  set relayAddress($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasRelayAddress() => $_has(0);
  @$pb.TagNumber(1)
  void clearRelayAddress() => clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get dataSize => $_getI64(1);
  @$pb.TagNumber(2)
  set dataSize($fixnum.Int64 v) { $_setInt64(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasDataSize() => $_has(1);
  @$pb.TagNumber(2)
  void clearDataSize() => clearField(2);
}

class NodeStartedEvent extends $pb.GeneratedMessage {
  factory NodeStartedEvent() => create();
  NodeStartedEvent._() : super();
  factory NodeStartedEvent.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory NodeStartedEvent.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'NodeStartedEvent', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'), createEmptyInstance: create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  NodeStartedEvent clone() => NodeStartedEvent()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  NodeStartedEvent copyWith(void Function(NodeStartedEvent) updates) => super.copyWith((message) => updates(message as NodeStartedEvent)) as NodeStartedEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NodeStartedEvent create() => NodeStartedEvent._();
  NodeStartedEvent createEmptyInstance() => create();
  static $pb.PbList<NodeStartedEvent> createRepeated() => $pb.PbList<NodeStartedEvent>();
  @$core.pragma('dart2js:noInline')
  static NodeStartedEvent getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<NodeStartedEvent>(create);
  static NodeStartedEvent? _defaultInstance;
}

class NodeStoppedEvent extends $pb.GeneratedMessage {
  factory NodeStoppedEvent() => create();
  NodeStoppedEvent._() : super();
  factory NodeStoppedEvent.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory NodeStoppedEvent.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'NodeStoppedEvent', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'), createEmptyInstance: create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  NodeStoppedEvent clone() => NodeStoppedEvent()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  NodeStoppedEvent copyWith(void Function(NodeStoppedEvent) updates) => super.copyWith((message) => updates(message as NodeStoppedEvent)) as NodeStoppedEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NodeStoppedEvent create() => NodeStoppedEvent._();
  NodeStoppedEvent createEmptyInstance() => create();
  static $pb.PbList<NodeStoppedEvent> createRepeated() => $pb.PbList<NodeStoppedEvent>();
  @$core.pragma('dart2js:noInline')
  static NodeStoppedEvent getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<NodeStoppedEvent>(create);
  static NodeStoppedEvent? _defaultInstance;
}

class ErrorEvent extends $pb.GeneratedMessage {
  factory ErrorEvent({
    $core.String? errorType,
    $core.String? message,
    $core.String? stackTrace,
  }) {
    final result = create();
    if (errorType != null) {
      result.errorType = errorType;
    }
    if (message != null) {
      result.message = message;
    }
    if (stackTrace != null) {
      result.stackTrace = stackTrace;
    }
    return result;
  }
  ErrorEvent._() : super();
  factory ErrorEvent.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ErrorEvent.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ErrorEvent', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'errorType')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..aOS(3, _omitFieldNames ? '' : 'stackTrace')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ErrorEvent clone() => ErrorEvent()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ErrorEvent copyWith(void Function(ErrorEvent) updates) => super.copyWith((message) => updates(message as ErrorEvent)) as ErrorEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ErrorEvent create() => ErrorEvent._();
  ErrorEvent createEmptyInstance() => create();
  static $pb.PbList<ErrorEvent> createRepeated() => $pb.PbList<ErrorEvent>();
  @$core.pragma('dart2js:noInline')
  static ErrorEvent getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ErrorEvent>(create);
  static ErrorEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get errorType => $_getSZ(0);
  @$pb.TagNumber(1)
  set errorType($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasErrorType() => $_has(0);
  @$pb.TagNumber(1)
  void clearErrorType() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get stackTrace => $_getSZ(2);
  @$pb.TagNumber(3)
  set stackTrace($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasStackTrace() => $_has(2);
  @$pb.TagNumber(3)
  void clearStackTrace() => clearField(3);
}

class NetworkChangedEvent extends $pb.GeneratedMessage {
  factory NetworkChangedEvent() => create();
  NetworkChangedEvent._() : super();
  factory NetworkChangedEvent.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory NetworkChangedEvent.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'NetworkChangedEvent', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'), createEmptyInstance: create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  NetworkChangedEvent clone() => NetworkChangedEvent()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  NetworkChangedEvent copyWith(void Function(NetworkChangedEvent) updates) => super.copyWith((message) => updates(message as NetworkChangedEvent)) as NetworkChangedEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NetworkChangedEvent create() => NetworkChangedEvent._();
  NetworkChangedEvent createEmptyInstance() => create();
  static $pb.PbList<NetworkChangedEvent> createRepeated() => $pb.PbList<NetworkChangedEvent>();
  @$core.pragma('dart2js:noInline')
  static NetworkChangedEvent getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<NetworkChangedEvent>(create);
  static NetworkChangedEvent? _defaultInstance;
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');