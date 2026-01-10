// This is a generated file - do not edit.
//
// Generated from dht/ipfs_node_network_events.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'ipfs_node_network_events.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'ipfs_node_network_events.pbenum.dart';

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
  dhtValueNotFound,
  pubsubMessagePublished,
  pubsubMessageReceived,
  pubsubSubscriptionCreated,
  pubsubSubscriptionCancelled,
  circuitRelayCreated,
  circuitRelayClosed,
  circuitRelayTraffic,
  circuitRelayFailed,
  nodeStarted,
  nodeStopped,
  error,
  networkChanged,
  dhtProviderAdded,
  dhtProviderQueried,
  streamStarted,
  streamEnded,
  peerDiscovered,
  circuitRelayDataReceived,
  circuitRelayDataSent,
  resourceLimitExceeded,
  systemAlert,
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
    DHTQueryStartedEvent? dhtQueryStarted,
    DHTQueryCompletedEvent? dhtQueryCompleted,
    DHTValueFoundEvent? dhtValueFound,
    DHTValueProvidedEvent? dhtValueProvided,
    DHTValueNotFoundEvent? dhtValueNotFound,
    PubsubMessagePublishedEvent? pubsubMessagePublished,
    PubsubMessageReceivedEvent? pubsubMessageReceived,
    PubsubSubscriptionCreatedEvent? pubsubSubscriptionCreated,
    PubsubSubscriptionCancelledEvent? pubsubSubscriptionCancelled,
    CircuitRelayCreatedEvent? circuitRelayCreated,
    CircuitRelayClosedEvent? circuitRelayClosed,
    CircuitRelayTrafficEvent? circuitRelayTraffic,
    CircuitRelayFailedEvent? circuitRelayFailed,
    NodeStartedEvent? nodeStarted,
    NodeStoppedEvent? nodeStopped,
    NodeErrorEvent? error,
    NetworkStatusChangedEvent? networkChanged,
    DHTProviderAddedEvent? dhtProviderAdded,
    DHTProviderQueriedEvent? dhtProviderQueried,
    StreamStartedEvent? streamStarted,
    StreamEndedEvent? streamEnded,
    PeerDiscoveredEvent? peerDiscovered,
    CircuitRelayDataReceivedEvent? circuitRelayDataReceived,
    CircuitRelayDataSentEvent? circuitRelayDataSent,
    ResourceLimitExceededEvent? resourceLimitExceeded,
    SystemAlertEvent? systemAlert,
  }) {
    final result = create();
    if (peerConnected != null) result.peerConnected = peerConnected;
    if (peerDisconnected != null) result.peerDisconnected = peerDisconnected;
    if (connectionAttempted != null)
      result.connectionAttempted = connectionAttempted;
    if (connectionFailed != null) result.connectionFailed = connectionFailed;
    if (messageReceived != null) result.messageReceived = messageReceived;
    if (messageSent != null) result.messageSent = messageSent;
    if (blockReceived != null) result.blockReceived = blockReceived;
    if (blockSent != null) result.blockSent = blockSent;
    if (dhtQueryStarted != null) result.dhtQueryStarted = dhtQueryStarted;
    if (dhtQueryCompleted != null) result.dhtQueryCompleted = dhtQueryCompleted;
    if (dhtValueFound != null) result.dhtValueFound = dhtValueFound;
    if (dhtValueProvided != null) result.dhtValueProvided = dhtValueProvided;
    if (dhtValueNotFound != null) result.dhtValueNotFound = dhtValueNotFound;
    if (pubsubMessagePublished != null)
      result.pubsubMessagePublished = pubsubMessagePublished;
    if (pubsubMessageReceived != null)
      result.pubsubMessageReceived = pubsubMessageReceived;
    if (pubsubSubscriptionCreated != null)
      result.pubsubSubscriptionCreated = pubsubSubscriptionCreated;
    if (pubsubSubscriptionCancelled != null)
      result.pubsubSubscriptionCancelled = pubsubSubscriptionCancelled;
    if (circuitRelayCreated != null)
      result.circuitRelayCreated = circuitRelayCreated;
    if (circuitRelayClosed != null)
      result.circuitRelayClosed = circuitRelayClosed;
    if (circuitRelayTraffic != null)
      result.circuitRelayTraffic = circuitRelayTraffic;
    if (circuitRelayFailed != null)
      result.circuitRelayFailed = circuitRelayFailed;
    if (nodeStarted != null) result.nodeStarted = nodeStarted;
    if (nodeStopped != null) result.nodeStopped = nodeStopped;
    if (error != null) result.error = error;
    if (networkChanged != null) result.networkChanged = networkChanged;
    if (dhtProviderAdded != null) result.dhtProviderAdded = dhtProviderAdded;
    if (dhtProviderQueried != null)
      result.dhtProviderQueried = dhtProviderQueried;
    if (streamStarted != null) result.streamStarted = streamStarted;
    if (streamEnded != null) result.streamEnded = streamEnded;
    if (peerDiscovered != null) result.peerDiscovered = peerDiscovered;
    if (circuitRelayDataReceived != null)
      result.circuitRelayDataReceived = circuitRelayDataReceived;
    if (circuitRelayDataSent != null)
      result.circuitRelayDataSent = circuitRelayDataSent;
    if (resourceLimitExceeded != null)
      result.resourceLimitExceeded = resourceLimitExceeded;
    if (systemAlert != null) result.systemAlert = systemAlert;
    return result;
  }

  NetworkEvent._();

  factory NetworkEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory NetworkEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, NetworkEvent_Event>
      _NetworkEvent_EventByTag = {
    1: NetworkEvent_Event.peerConnected,
    2: NetworkEvent_Event.peerDisconnected,
    3: NetworkEvent_Event.connectionAttempted,
    4: NetworkEvent_Event.connectionFailed,
    5: NetworkEvent_Event.messageReceived,
    6: NetworkEvent_Event.messageSent,
    7: NetworkEvent_Event.blockReceived,
    8: NetworkEvent_Event.blockSent,
    9: NetworkEvent_Event.dhtQueryStarted,
    10: NetworkEvent_Event.dhtQueryCompleted,
    11: NetworkEvent_Event.dhtValueFound,
    12: NetworkEvent_Event.dhtValueProvided,
    13: NetworkEvent_Event.dhtValueNotFound,
    14: NetworkEvent_Event.pubsubMessagePublished,
    15: NetworkEvent_Event.pubsubMessageReceived,
    16: NetworkEvent_Event.pubsubSubscriptionCreated,
    17: NetworkEvent_Event.pubsubSubscriptionCancelled,
    18: NetworkEvent_Event.circuitRelayCreated,
    19: NetworkEvent_Event.circuitRelayClosed,
    20: NetworkEvent_Event.circuitRelayTraffic,
    21: NetworkEvent_Event.circuitRelayFailed,
    22: NetworkEvent_Event.nodeStarted,
    23: NetworkEvent_Event.nodeStopped,
    24: NetworkEvent_Event.error,
    25: NetworkEvent_Event.networkChanged,
    26: NetworkEvent_Event.dhtProviderAdded,
    27: NetworkEvent_Event.dhtProviderQueried,
    28: NetworkEvent_Event.streamStarted,
    29: NetworkEvent_Event.streamEnded,
    30: NetworkEvent_Event.peerDiscovered,
    31: NetworkEvent_Event.circuitRelayDataReceived,
    32: NetworkEvent_Event.circuitRelayDataSent,
    33: NetworkEvent_Event.resourceLimitExceeded,
    34: NetworkEvent_Event.systemAlert,
    0: NetworkEvent_Event.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NetworkEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..oo(0, [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12,
      13,
      14,
      15,
      16,
      17,
      18,
      19,
      20,
      21,
      22,
      23,
      24,
      25,
      26,
      27,
      28,
      29,
      30,
      31,
      32,
      33,
      34
    ])
    ..aOM<PeerConnectedEvent>(1, _omitFieldNames ? '' : 'peerConnected',
        subBuilder: PeerConnectedEvent.create)
    ..aOM<PeerDisconnectedEvent>(2, _omitFieldNames ? '' : 'peerDisconnected',
        subBuilder: PeerDisconnectedEvent.create)
    ..aOM<ConnectionAttemptedEvent>(
        3, _omitFieldNames ? '' : 'connectionAttempted',
        subBuilder: ConnectionAttemptedEvent.create)
    ..aOM<ConnectionFailedEvent>(4, _omitFieldNames ? '' : 'connectionFailed',
        subBuilder: ConnectionFailedEvent.create)
    ..aOM<MessageReceivedEvent>(5, _omitFieldNames ? '' : 'messageReceived',
        subBuilder: MessageReceivedEvent.create)
    ..aOM<MessageSentEvent>(6, _omitFieldNames ? '' : 'messageSent',
        subBuilder: MessageSentEvent.create)
    ..aOM<BlockReceivedEvent>(7, _omitFieldNames ? '' : 'blockReceived',
        subBuilder: BlockReceivedEvent.create)
    ..aOM<BlockSentEvent>(8, _omitFieldNames ? '' : 'blockSent',
        subBuilder: BlockSentEvent.create)
    ..aOM<DHTQueryStartedEvent>(9, _omitFieldNames ? '' : 'dhtQueryStarted',
        subBuilder: DHTQueryStartedEvent.create)
    ..aOM<DHTQueryCompletedEvent>(
        10, _omitFieldNames ? '' : 'dhtQueryCompleted',
        subBuilder: DHTQueryCompletedEvent.create)
    ..aOM<DHTValueFoundEvent>(11, _omitFieldNames ? '' : 'dhtValueFound',
        subBuilder: DHTValueFoundEvent.create)
    ..aOM<DHTValueProvidedEvent>(12, _omitFieldNames ? '' : 'dhtValueProvided',
        subBuilder: DHTValueProvidedEvent.create)
    ..aOM<DHTValueNotFoundEvent>(13, _omitFieldNames ? '' : 'dhtValueNotFound',
        subBuilder: DHTValueNotFoundEvent.create)
    ..aOM<PubsubMessagePublishedEvent>(
        14, _omitFieldNames ? '' : 'pubsubMessagePublished',
        subBuilder: PubsubMessagePublishedEvent.create)
    ..aOM<PubsubMessageReceivedEvent>(
        15, _omitFieldNames ? '' : 'pubsubMessageReceived',
        subBuilder: PubsubMessageReceivedEvent.create)
    ..aOM<PubsubSubscriptionCreatedEvent>(
        16, _omitFieldNames ? '' : 'pubsubSubscriptionCreated',
        subBuilder: PubsubSubscriptionCreatedEvent.create)
    ..aOM<PubsubSubscriptionCancelledEvent>(
        17, _omitFieldNames ? '' : 'pubsubSubscriptionCancelled',
        subBuilder: PubsubSubscriptionCancelledEvent.create)
    ..aOM<CircuitRelayCreatedEvent>(
        18, _omitFieldNames ? '' : 'circuitRelayCreated',
        subBuilder: CircuitRelayCreatedEvent.create)
    ..aOM<CircuitRelayClosedEvent>(
        19, _omitFieldNames ? '' : 'circuitRelayClosed',
        subBuilder: CircuitRelayClosedEvent.create)
    ..aOM<CircuitRelayTrafficEvent>(
        20, _omitFieldNames ? '' : 'circuitRelayTraffic',
        subBuilder: CircuitRelayTrafficEvent.create)
    ..aOM<CircuitRelayFailedEvent>(
        21, _omitFieldNames ? '' : 'circuitRelayFailed',
        subBuilder: CircuitRelayFailedEvent.create)
    ..aOM<NodeStartedEvent>(22, _omitFieldNames ? '' : 'nodeStarted',
        subBuilder: NodeStartedEvent.create)
    ..aOM<NodeStoppedEvent>(23, _omitFieldNames ? '' : 'nodeStopped',
        subBuilder: NodeStoppedEvent.create)
    ..aOM<NodeErrorEvent>(24, _omitFieldNames ? '' : 'error',
        subBuilder: NodeErrorEvent.create)
    ..aOM<NetworkStatusChangedEvent>(
        25, _omitFieldNames ? '' : 'networkChanged',
        subBuilder: NetworkStatusChangedEvent.create)
    ..aOM<DHTProviderAddedEvent>(26, _omitFieldNames ? '' : 'dhtProviderAdded',
        subBuilder: DHTProviderAddedEvent.create)
    ..aOM<DHTProviderQueriedEvent>(
        27, _omitFieldNames ? '' : 'dhtProviderQueried',
        subBuilder: DHTProviderQueriedEvent.create)
    ..aOM<StreamStartedEvent>(28, _omitFieldNames ? '' : 'streamStarted',
        subBuilder: StreamStartedEvent.create)
    ..aOM<StreamEndedEvent>(29, _omitFieldNames ? '' : 'streamEnded',
        subBuilder: StreamEndedEvent.create)
    ..aOM<PeerDiscoveredEvent>(30, _omitFieldNames ? '' : 'peerDiscovered',
        subBuilder: PeerDiscoveredEvent.create)
    ..aOM<CircuitRelayDataReceivedEvent>(
        31, _omitFieldNames ? '' : 'circuitRelayDataReceived',
        subBuilder: CircuitRelayDataReceivedEvent.create)
    ..aOM<CircuitRelayDataSentEvent>(
        32, _omitFieldNames ? '' : 'circuitRelayDataSent',
        subBuilder: CircuitRelayDataSentEvent.create)
    ..aOM<ResourceLimitExceededEvent>(
        33, _omitFieldNames ? '' : 'resourceLimitExceeded',
        subBuilder: ResourceLimitExceededEvent.create)
    ..aOM<SystemAlertEvent>(34, _omitFieldNames ? '' : 'systemAlert',
        subBuilder: SystemAlertEvent.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NetworkEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NetworkEvent copyWith(void Function(NetworkEvent) updates) =>
      super.copyWith((message) => updates(message as NetworkEvent))
          as NetworkEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NetworkEvent create() => NetworkEvent._();
  @$core.override
  NetworkEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static NetworkEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NetworkEvent>(create);
  static NetworkEvent? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  @$pb.TagNumber(15)
  @$pb.TagNumber(16)
  @$pb.TagNumber(17)
  @$pb.TagNumber(18)
  @$pb.TagNumber(19)
  @$pb.TagNumber(20)
  @$pb.TagNumber(21)
  @$pb.TagNumber(22)
  @$pb.TagNumber(23)
  @$pb.TagNumber(24)
  @$pb.TagNumber(25)
  @$pb.TagNumber(26)
  @$pb.TagNumber(27)
  @$pb.TagNumber(28)
  @$pb.TagNumber(29)
  @$pb.TagNumber(30)
  @$pb.TagNumber(31)
  @$pb.TagNumber(32)
  @$pb.TagNumber(33)
  @$pb.TagNumber(34)
  NetworkEvent_Event whichEvent() => _NetworkEvent_EventByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  @$pb.TagNumber(15)
  @$pb.TagNumber(16)
  @$pb.TagNumber(17)
  @$pb.TagNumber(18)
  @$pb.TagNumber(19)
  @$pb.TagNumber(20)
  @$pb.TagNumber(21)
  @$pb.TagNumber(22)
  @$pb.TagNumber(23)
  @$pb.TagNumber(24)
  @$pb.TagNumber(25)
  @$pb.TagNumber(26)
  @$pb.TagNumber(27)
  @$pb.TagNumber(28)
  @$pb.TagNumber(29)
  @$pb.TagNumber(30)
  @$pb.TagNumber(31)
  @$pb.TagNumber(32)
  @$pb.TagNumber(33)
  @$pb.TagNumber(34)
  void clearEvent() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  PeerConnectedEvent get peerConnected => $_getN(0);
  @$pb.TagNumber(1)
  set peerConnected(PeerConnectedEvent value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPeerConnected() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerConnected() => $_clearField(1);
  @$pb.TagNumber(1)
  PeerConnectedEvent ensurePeerConnected() => $_ensure(0);

  @$pb.TagNumber(2)
  PeerDisconnectedEvent get peerDisconnected => $_getN(1);
  @$pb.TagNumber(2)
  set peerDisconnected(PeerDisconnectedEvent value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasPeerDisconnected() => $_has(1);
  @$pb.TagNumber(2)
  void clearPeerDisconnected() => $_clearField(2);
  @$pb.TagNumber(2)
  PeerDisconnectedEvent ensurePeerDisconnected() => $_ensure(1);

  @$pb.TagNumber(3)
  ConnectionAttemptedEvent get connectionAttempted => $_getN(2);
  @$pb.TagNumber(3)
  set connectionAttempted(ConnectionAttemptedEvent value) =>
      $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasConnectionAttempted() => $_has(2);
  @$pb.TagNumber(3)
  void clearConnectionAttempted() => $_clearField(3);
  @$pb.TagNumber(3)
  ConnectionAttemptedEvent ensureConnectionAttempted() => $_ensure(2);

  @$pb.TagNumber(4)
  ConnectionFailedEvent get connectionFailed => $_getN(3);
  @$pb.TagNumber(4)
  set connectionFailed(ConnectionFailedEvent value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasConnectionFailed() => $_has(3);
  @$pb.TagNumber(4)
  void clearConnectionFailed() => $_clearField(4);
  @$pb.TagNumber(4)
  ConnectionFailedEvent ensureConnectionFailed() => $_ensure(3);

  @$pb.TagNumber(5)
  MessageReceivedEvent get messageReceived => $_getN(4);
  @$pb.TagNumber(5)
  set messageReceived(MessageReceivedEvent value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasMessageReceived() => $_has(4);
  @$pb.TagNumber(5)
  void clearMessageReceived() => $_clearField(5);
  @$pb.TagNumber(5)
  MessageReceivedEvent ensureMessageReceived() => $_ensure(4);

  @$pb.TagNumber(6)
  MessageSentEvent get messageSent => $_getN(5);
  @$pb.TagNumber(6)
  set messageSent(MessageSentEvent value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasMessageSent() => $_has(5);
  @$pb.TagNumber(6)
  void clearMessageSent() => $_clearField(6);
  @$pb.TagNumber(6)
  MessageSentEvent ensureMessageSent() => $_ensure(5);

  @$pb.TagNumber(7)
  BlockReceivedEvent get blockReceived => $_getN(6);
  @$pb.TagNumber(7)
  set blockReceived(BlockReceivedEvent value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasBlockReceived() => $_has(6);
  @$pb.TagNumber(7)
  void clearBlockReceived() => $_clearField(7);
  @$pb.TagNumber(7)
  BlockReceivedEvent ensureBlockReceived() => $_ensure(6);

  @$pb.TagNumber(8)
  BlockSentEvent get blockSent => $_getN(7);
  @$pb.TagNumber(8)
  set blockSent(BlockSentEvent value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasBlockSent() => $_has(7);
  @$pb.TagNumber(8)
  void clearBlockSent() => $_clearField(8);
  @$pb.TagNumber(8)
  BlockSentEvent ensureBlockSent() => $_ensure(7);

  @$pb.TagNumber(9)
  DHTQueryStartedEvent get dhtQueryStarted => $_getN(8);
  @$pb.TagNumber(9)
  set dhtQueryStarted(DHTQueryStartedEvent value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasDhtQueryStarted() => $_has(8);
  @$pb.TagNumber(9)
  void clearDhtQueryStarted() => $_clearField(9);
  @$pb.TagNumber(9)
  DHTQueryStartedEvent ensureDhtQueryStarted() => $_ensure(8);

  @$pb.TagNumber(10)
  DHTQueryCompletedEvent get dhtQueryCompleted => $_getN(9);
  @$pb.TagNumber(10)
  set dhtQueryCompleted(DHTQueryCompletedEvent value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasDhtQueryCompleted() => $_has(9);
  @$pb.TagNumber(10)
  void clearDhtQueryCompleted() => $_clearField(10);
  @$pb.TagNumber(10)
  DHTQueryCompletedEvent ensureDhtQueryCompleted() => $_ensure(9);

  @$pb.TagNumber(11)
  DHTValueFoundEvent get dhtValueFound => $_getN(10);
  @$pb.TagNumber(11)
  set dhtValueFound(DHTValueFoundEvent value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasDhtValueFound() => $_has(10);
  @$pb.TagNumber(11)
  void clearDhtValueFound() => $_clearField(11);
  @$pb.TagNumber(11)
  DHTValueFoundEvent ensureDhtValueFound() => $_ensure(10);

  @$pb.TagNumber(12)
  DHTValueProvidedEvent get dhtValueProvided => $_getN(11);
  @$pb.TagNumber(12)
  set dhtValueProvided(DHTValueProvidedEvent value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasDhtValueProvided() => $_has(11);
  @$pb.TagNumber(12)
  void clearDhtValueProvided() => $_clearField(12);
  @$pb.TagNumber(12)
  DHTValueProvidedEvent ensureDhtValueProvided() => $_ensure(11);

  @$pb.TagNumber(13)
  DHTValueNotFoundEvent get dhtValueNotFound => $_getN(12);
  @$pb.TagNumber(13)
  set dhtValueNotFound(DHTValueNotFoundEvent value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasDhtValueNotFound() => $_has(12);
  @$pb.TagNumber(13)
  void clearDhtValueNotFound() => $_clearField(13);
  @$pb.TagNumber(13)
  DHTValueNotFoundEvent ensureDhtValueNotFound() => $_ensure(12);

  @$pb.TagNumber(14)
  PubsubMessagePublishedEvent get pubsubMessagePublished => $_getN(13);
  @$pb.TagNumber(14)
  set pubsubMessagePublished(PubsubMessagePublishedEvent value) =>
      $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasPubsubMessagePublished() => $_has(13);
  @$pb.TagNumber(14)
  void clearPubsubMessagePublished() => $_clearField(14);
  @$pb.TagNumber(14)
  PubsubMessagePublishedEvent ensurePubsubMessagePublished() => $_ensure(13);

  @$pb.TagNumber(15)
  PubsubMessageReceivedEvent get pubsubMessageReceived => $_getN(14);
  @$pb.TagNumber(15)
  set pubsubMessageReceived(PubsubMessageReceivedEvent value) =>
      $_setField(15, value);
  @$pb.TagNumber(15)
  $core.bool hasPubsubMessageReceived() => $_has(14);
  @$pb.TagNumber(15)
  void clearPubsubMessageReceived() => $_clearField(15);
  @$pb.TagNumber(15)
  PubsubMessageReceivedEvent ensurePubsubMessageReceived() => $_ensure(14);

  @$pb.TagNumber(16)
  PubsubSubscriptionCreatedEvent get pubsubSubscriptionCreated => $_getN(15);
  @$pb.TagNumber(16)
  set pubsubSubscriptionCreated(PubsubSubscriptionCreatedEvent value) =>
      $_setField(16, value);
  @$pb.TagNumber(16)
  $core.bool hasPubsubSubscriptionCreated() => $_has(15);
  @$pb.TagNumber(16)
  void clearPubsubSubscriptionCreated() => $_clearField(16);
  @$pb.TagNumber(16)
  PubsubSubscriptionCreatedEvent ensurePubsubSubscriptionCreated() =>
      $_ensure(15);

  @$pb.TagNumber(17)
  PubsubSubscriptionCancelledEvent get pubsubSubscriptionCancelled =>
      $_getN(16);
  @$pb.TagNumber(17)
  set pubsubSubscriptionCancelled(PubsubSubscriptionCancelledEvent value) =>
      $_setField(17, value);
  @$pb.TagNumber(17)
  $core.bool hasPubsubSubscriptionCancelled() => $_has(16);
  @$pb.TagNumber(17)
  void clearPubsubSubscriptionCancelled() => $_clearField(17);
  @$pb.TagNumber(17)
  PubsubSubscriptionCancelledEvent ensurePubsubSubscriptionCancelled() =>
      $_ensure(16);

  @$pb.TagNumber(18)
  CircuitRelayCreatedEvent get circuitRelayCreated => $_getN(17);
  @$pb.TagNumber(18)
  set circuitRelayCreated(CircuitRelayCreatedEvent value) =>
      $_setField(18, value);
  @$pb.TagNumber(18)
  $core.bool hasCircuitRelayCreated() => $_has(17);
  @$pb.TagNumber(18)
  void clearCircuitRelayCreated() => $_clearField(18);
  @$pb.TagNumber(18)
  CircuitRelayCreatedEvent ensureCircuitRelayCreated() => $_ensure(17);

  @$pb.TagNumber(19)
  CircuitRelayClosedEvent get circuitRelayClosed => $_getN(18);
  @$pb.TagNumber(19)
  set circuitRelayClosed(CircuitRelayClosedEvent value) =>
      $_setField(19, value);
  @$pb.TagNumber(19)
  $core.bool hasCircuitRelayClosed() => $_has(18);
  @$pb.TagNumber(19)
  void clearCircuitRelayClosed() => $_clearField(19);
  @$pb.TagNumber(19)
  CircuitRelayClosedEvent ensureCircuitRelayClosed() => $_ensure(18);

  @$pb.TagNumber(20)
  CircuitRelayTrafficEvent get circuitRelayTraffic => $_getN(19);
  @$pb.TagNumber(20)
  set circuitRelayTraffic(CircuitRelayTrafficEvent value) =>
      $_setField(20, value);
  @$pb.TagNumber(20)
  $core.bool hasCircuitRelayTraffic() => $_has(19);
  @$pb.TagNumber(20)
  void clearCircuitRelayTraffic() => $_clearField(20);
  @$pb.TagNumber(20)
  CircuitRelayTrafficEvent ensureCircuitRelayTraffic() => $_ensure(19);

  @$pb.TagNumber(21)
  CircuitRelayFailedEvent get circuitRelayFailed => $_getN(20);
  @$pb.TagNumber(21)
  set circuitRelayFailed(CircuitRelayFailedEvent value) =>
      $_setField(21, value);
  @$pb.TagNumber(21)
  $core.bool hasCircuitRelayFailed() => $_has(20);
  @$pb.TagNumber(21)
  void clearCircuitRelayFailed() => $_clearField(21);
  @$pb.TagNumber(21)
  CircuitRelayFailedEvent ensureCircuitRelayFailed() => $_ensure(20);

  @$pb.TagNumber(22)
  NodeStartedEvent get nodeStarted => $_getN(21);
  @$pb.TagNumber(22)
  set nodeStarted(NodeStartedEvent value) => $_setField(22, value);
  @$pb.TagNumber(22)
  $core.bool hasNodeStarted() => $_has(21);
  @$pb.TagNumber(22)
  void clearNodeStarted() => $_clearField(22);
  @$pb.TagNumber(22)
  NodeStartedEvent ensureNodeStarted() => $_ensure(21);

  @$pb.TagNumber(23)
  NodeStoppedEvent get nodeStopped => $_getN(22);
  @$pb.TagNumber(23)
  set nodeStopped(NodeStoppedEvent value) => $_setField(23, value);
  @$pb.TagNumber(23)
  $core.bool hasNodeStopped() => $_has(22);
  @$pb.TagNumber(23)
  void clearNodeStopped() => $_clearField(23);
  @$pb.TagNumber(23)
  NodeStoppedEvent ensureNodeStopped() => $_ensure(22);

  @$pb.TagNumber(24)
  NodeErrorEvent get error => $_getN(23);
  @$pb.TagNumber(24)
  set error(NodeErrorEvent value) => $_setField(24, value);
  @$pb.TagNumber(24)
  $core.bool hasError() => $_has(23);
  @$pb.TagNumber(24)
  void clearError() => $_clearField(24);
  @$pb.TagNumber(24)
  NodeErrorEvent ensureError() => $_ensure(23);

  @$pb.TagNumber(25)
  NetworkStatusChangedEvent get networkChanged => $_getN(24);
  @$pb.TagNumber(25)
  set networkChanged(NetworkStatusChangedEvent value) => $_setField(25, value);
  @$pb.TagNumber(25)
  $core.bool hasNetworkChanged() => $_has(24);
  @$pb.TagNumber(25)
  void clearNetworkChanged() => $_clearField(25);
  @$pb.TagNumber(25)
  NetworkStatusChangedEvent ensureNetworkChanged() => $_ensure(24);

  @$pb.TagNumber(26)
  DHTProviderAddedEvent get dhtProviderAdded => $_getN(25);
  @$pb.TagNumber(26)
  set dhtProviderAdded(DHTProviderAddedEvent value) => $_setField(26, value);
  @$pb.TagNumber(26)
  $core.bool hasDhtProviderAdded() => $_has(25);
  @$pb.TagNumber(26)
  void clearDhtProviderAdded() => $_clearField(26);
  @$pb.TagNumber(26)
  DHTProviderAddedEvent ensureDhtProviderAdded() => $_ensure(25);

  @$pb.TagNumber(27)
  DHTProviderQueriedEvent get dhtProviderQueried => $_getN(26);
  @$pb.TagNumber(27)
  set dhtProviderQueried(DHTProviderQueriedEvent value) =>
      $_setField(27, value);
  @$pb.TagNumber(27)
  $core.bool hasDhtProviderQueried() => $_has(26);
  @$pb.TagNumber(27)
  void clearDhtProviderQueried() => $_clearField(27);
  @$pb.TagNumber(27)
  DHTProviderQueriedEvent ensureDhtProviderQueried() => $_ensure(26);

  @$pb.TagNumber(28)
  StreamStartedEvent get streamStarted => $_getN(27);
  @$pb.TagNumber(28)
  set streamStarted(StreamStartedEvent value) => $_setField(28, value);
  @$pb.TagNumber(28)
  $core.bool hasStreamStarted() => $_has(27);
  @$pb.TagNumber(28)
  void clearStreamStarted() => $_clearField(28);
  @$pb.TagNumber(28)
  StreamStartedEvent ensureStreamStarted() => $_ensure(27);

  @$pb.TagNumber(29)
  StreamEndedEvent get streamEnded => $_getN(28);
  @$pb.TagNumber(29)
  set streamEnded(StreamEndedEvent value) => $_setField(29, value);
  @$pb.TagNumber(29)
  $core.bool hasStreamEnded() => $_has(28);
  @$pb.TagNumber(29)
  void clearStreamEnded() => $_clearField(29);
  @$pb.TagNumber(29)
  StreamEndedEvent ensureStreamEnded() => $_ensure(28);

  @$pb.TagNumber(30)
  PeerDiscoveredEvent get peerDiscovered => $_getN(29);
  @$pb.TagNumber(30)
  set peerDiscovered(PeerDiscoveredEvent value) => $_setField(30, value);
  @$pb.TagNumber(30)
  $core.bool hasPeerDiscovered() => $_has(29);
  @$pb.TagNumber(30)
  void clearPeerDiscovered() => $_clearField(30);
  @$pb.TagNumber(30)
  PeerDiscoveredEvent ensurePeerDiscovered() => $_ensure(29);

  @$pb.TagNumber(31)
  CircuitRelayDataReceivedEvent get circuitRelayDataReceived => $_getN(30);
  @$pb.TagNumber(31)
  set circuitRelayDataReceived(CircuitRelayDataReceivedEvent value) =>
      $_setField(31, value);
  @$pb.TagNumber(31)
  $core.bool hasCircuitRelayDataReceived() => $_has(30);
  @$pb.TagNumber(31)
  void clearCircuitRelayDataReceived() => $_clearField(31);
  @$pb.TagNumber(31)
  CircuitRelayDataReceivedEvent ensureCircuitRelayDataReceived() =>
      $_ensure(30);

  @$pb.TagNumber(32)
  CircuitRelayDataSentEvent get circuitRelayDataSent => $_getN(31);
  @$pb.TagNumber(32)
  set circuitRelayDataSent(CircuitRelayDataSentEvent value) =>
      $_setField(32, value);
  @$pb.TagNumber(32)
  $core.bool hasCircuitRelayDataSent() => $_has(31);
  @$pb.TagNumber(32)
  void clearCircuitRelayDataSent() => $_clearField(32);
  @$pb.TagNumber(32)
  CircuitRelayDataSentEvent ensureCircuitRelayDataSent() => $_ensure(31);

  @$pb.TagNumber(33)
  ResourceLimitExceededEvent get resourceLimitExceeded => $_getN(32);
  @$pb.TagNumber(33)
  set resourceLimitExceeded(ResourceLimitExceededEvent value) =>
      $_setField(33, value);
  @$pb.TagNumber(33)
  $core.bool hasResourceLimitExceeded() => $_has(32);
  @$pb.TagNumber(33)
  void clearResourceLimitExceeded() => $_clearField(33);
  @$pb.TagNumber(33)
  ResourceLimitExceededEvent ensureResourceLimitExceeded() => $_ensure(32);

  @$pb.TagNumber(34)
  SystemAlertEvent get systemAlert => $_getN(33);
  @$pb.TagNumber(34)
  set systemAlert(SystemAlertEvent value) => $_setField(34, value);
  @$pb.TagNumber(34)
  $core.bool hasSystemAlert() => $_has(33);
  @$pb.TagNumber(34)
  void clearSystemAlert() => $_clearField(34);
  @$pb.TagNumber(34)
  SystemAlertEvent ensureSystemAlert() => $_ensure(33);
}

/// Event message definitions:
class PeerConnectedEvent extends $pb.GeneratedMessage {
  factory PeerConnectedEvent({
    $core.String? peerId,
    $core.String? multiaddress,
  }) {
    final result = create();
    if (peerId != null) result.peerId = peerId;
    if (multiaddress != null) result.multiaddress = multiaddress;
    return result;
  }

  PeerConnectedEvent._();

  factory PeerConnectedEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PeerConnectedEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PeerConnectedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'peerId')
    ..aOS(2, _omitFieldNames ? '' : 'multiaddress')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PeerConnectedEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PeerConnectedEvent copyWith(void Function(PeerConnectedEvent) updates) =>
      super.copyWith((message) => updates(message as PeerConnectedEvent))
          as PeerConnectedEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PeerConnectedEvent create() => PeerConnectedEvent._();
  @$core.override
  PeerConnectedEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PeerConnectedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PeerConnectedEvent>(create);
  static PeerConnectedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get peerId => $_getSZ(0);
  @$pb.TagNumber(1)
  set peerId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPeerId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get multiaddress => $_getSZ(1);
  @$pb.TagNumber(2)
  set multiaddress($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMultiaddress() => $_has(1);
  @$pb.TagNumber(2)
  void clearMultiaddress() => $_clearField(2);
}

class PeerDisconnectedEvent extends $pb.GeneratedMessage {
  factory PeerDisconnectedEvent({
    $core.String? peerId,
    $core.String? reason,
  }) {
    final result = create();
    if (peerId != null) result.peerId = peerId;
    if (reason != null) result.reason = reason;
    return result;
  }

  PeerDisconnectedEvent._();

  factory PeerDisconnectedEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PeerDisconnectedEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PeerDisconnectedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'peerId')
    ..aOS(2, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PeerDisconnectedEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PeerDisconnectedEvent copyWith(
          void Function(PeerDisconnectedEvent) updates) =>
      super.copyWith((message) => updates(message as PeerDisconnectedEvent))
          as PeerDisconnectedEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PeerDisconnectedEvent create() => PeerDisconnectedEvent._();
  @$core.override
  PeerDisconnectedEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PeerDisconnectedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PeerDisconnectedEvent>(create);
  static PeerDisconnectedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get peerId => $_getSZ(0);
  @$pb.TagNumber(1)
  set peerId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPeerId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get reason => $_getSZ(1);
  @$pb.TagNumber(2)
  set reason($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReason() => $_has(1);
  @$pb.TagNumber(2)
  void clearReason() => $_clearField(2);
}

class ConnectionAttemptedEvent extends $pb.GeneratedMessage {
  factory ConnectionAttemptedEvent({
    $core.String? peerId,
    $core.bool? success,
  }) {
    final result = create();
    if (peerId != null) result.peerId = peerId;
    if (success != null) result.success = success;
    return result;
  }

  ConnectionAttemptedEvent._();

  factory ConnectionAttemptedEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ConnectionAttemptedEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ConnectionAttemptedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'peerId')
    ..aOB(2, _omitFieldNames ? '' : 'success')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConnectionAttemptedEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConnectionAttemptedEvent copyWith(
          void Function(ConnectionAttemptedEvent) updates) =>
      super.copyWith((message) => updates(message as ConnectionAttemptedEvent))
          as ConnectionAttemptedEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ConnectionAttemptedEvent create() => ConnectionAttemptedEvent._();
  @$core.override
  ConnectionAttemptedEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ConnectionAttemptedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ConnectionAttemptedEvent>(create);
  static ConnectionAttemptedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get peerId => $_getSZ(0);
  @$pb.TagNumber(1)
  set peerId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPeerId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get success => $_getBF(1);
  @$pb.TagNumber(2)
  set success($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSuccess() => $_has(1);
  @$pb.TagNumber(2)
  void clearSuccess() => $_clearField(2);
}

class ConnectionFailedEvent extends $pb.GeneratedMessage {
  factory ConnectionFailedEvent({
    $core.String? peerId,
    $core.String? reason,
  }) {
    final result = create();
    if (peerId != null) result.peerId = peerId;
    if (reason != null) result.reason = reason;
    return result;
  }

  ConnectionFailedEvent._();

  factory ConnectionFailedEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ConnectionFailedEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ConnectionFailedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'peerId')
    ..aOS(2, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConnectionFailedEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConnectionFailedEvent copyWith(
          void Function(ConnectionFailedEvent) updates) =>
      super.copyWith((message) => updates(message as ConnectionFailedEvent))
          as ConnectionFailedEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ConnectionFailedEvent create() => ConnectionFailedEvent._();
  @$core.override
  ConnectionFailedEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ConnectionFailedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ConnectionFailedEvent>(create);
  static ConnectionFailedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get peerId => $_getSZ(0);
  @$pb.TagNumber(1)
  set peerId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPeerId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get reason => $_getSZ(1);
  @$pb.TagNumber(2)
  set reason($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReason() => $_has(1);
  @$pb.TagNumber(2)
  void clearReason() => $_clearField(2);
}

class MessageReceivedEvent extends $pb.GeneratedMessage {
  factory MessageReceivedEvent({
    $core.String? peerId,
    $core.List<$core.int>? messageContent,
  }) {
    final result = create();
    if (peerId != null) result.peerId = peerId;
    if (messageContent != null) result.messageContent = messageContent;
    return result;
  }

  MessageReceivedEvent._();

  factory MessageReceivedEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MessageReceivedEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MessageReceivedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'peerId')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'messageContent', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MessageReceivedEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MessageReceivedEvent copyWith(void Function(MessageReceivedEvent) updates) =>
      super.copyWith((message) => updates(message as MessageReceivedEvent))
          as MessageReceivedEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MessageReceivedEvent create() => MessageReceivedEvent._();
  @$core.override
  MessageReceivedEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MessageReceivedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MessageReceivedEvent>(create);
  static MessageReceivedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get peerId => $_getSZ(0);
  @$pb.TagNumber(1)
  set peerId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPeerId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get messageContent => $_getN(1);
  @$pb.TagNumber(2)
  set messageContent($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessageContent() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessageContent() => $_clearField(2);
}

class MessageSentEvent extends $pb.GeneratedMessage {
  factory MessageSentEvent({
    $core.String? peerId,
    $core.List<$core.int>? messageContent,
  }) {
    final result = create();
    if (peerId != null) result.peerId = peerId;
    if (messageContent != null) result.messageContent = messageContent;
    return result;
  }

  MessageSentEvent._();

  factory MessageSentEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MessageSentEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MessageSentEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'peerId')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'messageContent', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MessageSentEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MessageSentEvent copyWith(void Function(MessageSentEvent) updates) =>
      super.copyWith((message) => updates(message as MessageSentEvent))
          as MessageSentEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MessageSentEvent create() => MessageSentEvent._();
  @$core.override
  MessageSentEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MessageSentEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MessageSentEvent>(create);
  static MessageSentEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get peerId => $_getSZ(0);
  @$pb.TagNumber(1)
  set peerId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPeerId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get messageContent => $_getN(1);
  @$pb.TagNumber(2)
  set messageContent($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessageContent() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessageContent() => $_clearField(2);
}

class BlockReceivedEvent extends $pb.GeneratedMessage {
  factory BlockReceivedEvent({
    $core.String? cid,
    $core.String? peerId,
  }) {
    final result = create();
    if (cid != null) result.cid = cid;
    if (peerId != null) result.peerId = peerId;
    return result;
  }

  BlockReceivedEvent._();

  factory BlockReceivedEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BlockReceivedEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BlockReceivedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'cid')
    ..aOS(2, _omitFieldNames ? '' : 'peerId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BlockReceivedEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BlockReceivedEvent copyWith(void Function(BlockReceivedEvent) updates) =>
      super.copyWith((message) => updates(message as BlockReceivedEvent))
          as BlockReceivedEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BlockReceivedEvent create() => BlockReceivedEvent._();
  @$core.override
  BlockReceivedEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BlockReceivedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BlockReceivedEvent>(create);
  static BlockReceivedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get cid => $_getSZ(0);
  @$pb.TagNumber(1)
  set cid($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCid() => $_has(0);
  @$pb.TagNumber(1)
  void clearCid() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get peerId => $_getSZ(1);
  @$pb.TagNumber(2)
  set peerId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPeerId() => $_has(1);
  @$pb.TagNumber(2)
  void clearPeerId() => $_clearField(2);
}

class BlockSentEvent extends $pb.GeneratedMessage {
  factory BlockSentEvent({
    $core.String? cid,
    $core.String? peerId,
  }) {
    final result = create();
    if (cid != null) result.cid = cid;
    if (peerId != null) result.peerId = peerId;
    return result;
  }

  BlockSentEvent._();

  factory BlockSentEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BlockSentEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BlockSentEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'cid')
    ..aOS(2, _omitFieldNames ? '' : 'peerId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BlockSentEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BlockSentEvent copyWith(void Function(BlockSentEvent) updates) =>
      super.copyWith((message) => updates(message as BlockSentEvent))
          as BlockSentEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BlockSentEvent create() => BlockSentEvent._();
  @$core.override
  BlockSentEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BlockSentEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BlockSentEvent>(create);
  static BlockSentEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get cid => $_getSZ(0);
  @$pb.TagNumber(1)
  set cid($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCid() => $_has(0);
  @$pb.TagNumber(1)
  void clearCid() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get peerId => $_getSZ(1);
  @$pb.TagNumber(2)
  set peerId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPeerId() => $_has(1);
  @$pb.TagNumber(2)
  void clearPeerId() => $_clearField(2);
}

class DHTQueryStartedEvent extends $pb.GeneratedMessage {
  factory DHTQueryStartedEvent({
    $core.String? queryType,
    $core.String? targetKey,
  }) {
    final result = create();
    if (queryType != null) result.queryType = queryType;
    if (targetKey != null) result.targetKey = targetKey;
    return result;
  }

  DHTQueryStartedEvent._();

  factory DHTQueryStartedEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DHTQueryStartedEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DHTQueryStartedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'queryType')
    ..aOS(2, _omitFieldNames ? '' : 'targetKey')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DHTQueryStartedEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DHTQueryStartedEvent copyWith(void Function(DHTQueryStartedEvent) updates) =>
      super.copyWith((message) => updates(message as DHTQueryStartedEvent))
          as DHTQueryStartedEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DHTQueryStartedEvent create() => DHTQueryStartedEvent._();
  @$core.override
  DHTQueryStartedEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DHTQueryStartedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DHTQueryStartedEvent>(create);
  static DHTQueryStartedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get queryType => $_getSZ(0);
  @$pb.TagNumber(1)
  set queryType($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasQueryType() => $_has(0);
  @$pb.TagNumber(1)
  void clearQueryType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get targetKey => $_getSZ(1);
  @$pb.TagNumber(2)
  set targetKey($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTargetKey() => $_has(1);
  @$pb.TagNumber(2)
  void clearTargetKey() => $_clearField(2);
}

class DHTQueryCompletedEvent extends $pb.GeneratedMessage {
  factory DHTQueryCompletedEvent({
    $core.String? queryType,
    $core.String? targetKey,
    $core.Iterable<$core.String>? results,
  }) {
    final result = create();
    if (queryType != null) result.queryType = queryType;
    if (targetKey != null) result.targetKey = targetKey;
    if (results != null) result.results.addAll(results);
    return result;
  }

  DHTQueryCompletedEvent._();

  factory DHTQueryCompletedEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DHTQueryCompletedEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DHTQueryCompletedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'queryType')
    ..aOS(2, _omitFieldNames ? '' : 'targetKey')
    ..pPS(3, _omitFieldNames ? '' : 'results')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DHTQueryCompletedEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DHTQueryCompletedEvent copyWith(
          void Function(DHTQueryCompletedEvent) updates) =>
      super.copyWith((message) => updates(message as DHTQueryCompletedEvent))
          as DHTQueryCompletedEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DHTQueryCompletedEvent create() => DHTQueryCompletedEvent._();
  @$core.override
  DHTQueryCompletedEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DHTQueryCompletedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DHTQueryCompletedEvent>(create);
  static DHTQueryCompletedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get queryType => $_getSZ(0);
  @$pb.TagNumber(1)
  set queryType($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasQueryType() => $_has(0);
  @$pb.TagNumber(1)
  void clearQueryType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get targetKey => $_getSZ(1);
  @$pb.TagNumber(2)
  set targetKey($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTargetKey() => $_has(1);
  @$pb.TagNumber(2)
  void clearTargetKey() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<$core.String> get results => $_getList(2);
}

class DHTValueFoundEvent extends $pb.GeneratedMessage {
  factory DHTValueFoundEvent({
    $core.String? key,
    $core.List<$core.int>? value,
    $core.String? peerId,
  }) {
    final result = create();
    if (key != null) result.key = key;
    if (value != null) result.value = value;
    if (peerId != null) result.peerId = peerId;
    return result;
  }

  DHTValueFoundEvent._();

  factory DHTValueFoundEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DHTValueFoundEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DHTValueFoundEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'key')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'value', $pb.PbFieldType.OY)
    ..aOS(3, _omitFieldNames ? '' : 'peerId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DHTValueFoundEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DHTValueFoundEvent copyWith(void Function(DHTValueFoundEvent) updates) =>
      super.copyWith((message) => updates(message as DHTValueFoundEvent))
          as DHTValueFoundEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DHTValueFoundEvent create() => DHTValueFoundEvent._();
  @$core.override
  DHTValueFoundEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DHTValueFoundEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DHTValueFoundEvent>(create);
  static DHTValueFoundEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get key => $_getSZ(0);
  @$pb.TagNumber(1)
  set key($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get value => $_getN(1);
  @$pb.TagNumber(2)
  set value($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearValue() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get peerId => $_getSZ(2);
  @$pb.TagNumber(3)
  set peerId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPeerId() => $_has(2);
  @$pb.TagNumber(3)
  void clearPeerId() => $_clearField(3);
}

class DHTValueNotFoundEvent extends $pb.GeneratedMessage {
  factory DHTValueNotFoundEvent({
    $core.String? key,
  }) {
    final result = create();
    if (key != null) result.key = key;
    return result;
  }

  DHTValueNotFoundEvent._();

  factory DHTValueNotFoundEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DHTValueNotFoundEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DHTValueNotFoundEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'key')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DHTValueNotFoundEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DHTValueNotFoundEvent copyWith(
          void Function(DHTValueNotFoundEvent) updates) =>
      super.copyWith((message) => updates(message as DHTValueNotFoundEvent))
          as DHTValueNotFoundEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DHTValueNotFoundEvent create() => DHTValueNotFoundEvent._();
  @$core.override
  DHTValueNotFoundEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DHTValueNotFoundEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DHTValueNotFoundEvent>(create);
  static DHTValueNotFoundEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get key => $_getSZ(0);
  @$pb.TagNumber(1)
  set key($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => $_clearField(1);
}

class DHTValueProvidedEvent extends $pb.GeneratedMessage {
  factory DHTValueProvidedEvent({
    $core.String? key,
    $core.List<$core.int>? value,
  }) {
    final result = create();
    if (key != null) result.key = key;
    if (value != null) result.value = value;
    return result;
  }

  DHTValueProvidedEvent._();

  factory DHTValueProvidedEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DHTValueProvidedEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DHTValueProvidedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'key')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'value', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DHTValueProvidedEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DHTValueProvidedEvent copyWith(
          void Function(DHTValueProvidedEvent) updates) =>
      super.copyWith((message) => updates(message as DHTValueProvidedEvent))
          as DHTValueProvidedEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DHTValueProvidedEvent create() => DHTValueProvidedEvent._();
  @$core.override
  DHTValueProvidedEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DHTValueProvidedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DHTValueProvidedEvent>(create);
  static DHTValueProvidedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get key => $_getSZ(0);
  @$pb.TagNumber(1)
  set key($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get value => $_getN(1);
  @$pb.TagNumber(2)
  set value($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearValue() => $_clearField(2);
}

class DHTProviderAddedEvent extends $pb.GeneratedMessage {
  factory DHTProviderAddedEvent({
    $core.String? key,
    $core.String? peerId,
  }) {
    final result = create();
    if (key != null) result.key = key;
    if (peerId != null) result.peerId = peerId;
    return result;
  }

  DHTProviderAddedEvent._();

  factory DHTProviderAddedEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DHTProviderAddedEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DHTProviderAddedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'key')
    ..aOS(2, _omitFieldNames ? '' : 'peerId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DHTProviderAddedEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DHTProviderAddedEvent copyWith(
          void Function(DHTProviderAddedEvent) updates) =>
      super.copyWith((message) => updates(message as DHTProviderAddedEvent))
          as DHTProviderAddedEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DHTProviderAddedEvent create() => DHTProviderAddedEvent._();
  @$core.override
  DHTProviderAddedEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DHTProviderAddedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DHTProviderAddedEvent>(create);
  static DHTProviderAddedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get key => $_getSZ(0);
  @$pb.TagNumber(1)
  set key($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get peerId => $_getSZ(1);
  @$pb.TagNumber(2)
  set peerId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPeerId() => $_has(1);
  @$pb.TagNumber(2)
  void clearPeerId() => $_clearField(2);
}

class DHTProviderQueriedEvent extends $pb.GeneratedMessage {
  factory DHTProviderQueriedEvent({
    $core.String? key,
    $core.Iterable<$core.String>? providers,
  }) {
    final result = create();
    if (key != null) result.key = key;
    if (providers != null) result.providers.addAll(providers);
    return result;
  }

  DHTProviderQueriedEvent._();

  factory DHTProviderQueriedEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DHTProviderQueriedEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DHTProviderQueriedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'key')
    ..pPS(2, _omitFieldNames ? '' : 'providers')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DHTProviderQueriedEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DHTProviderQueriedEvent copyWith(
          void Function(DHTProviderQueriedEvent) updates) =>
      super.copyWith((message) => updates(message as DHTProviderQueriedEvent))
          as DHTProviderQueriedEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DHTProviderQueriedEvent create() => DHTProviderQueriedEvent._();
  @$core.override
  DHTProviderQueriedEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DHTProviderQueriedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DHTProviderQueriedEvent>(create);
  static DHTProviderQueriedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get key => $_getSZ(0);
  @$pb.TagNumber(1)
  set key($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get providers => $_getList(1);
}

class PubsubMessagePublishedEvent extends $pb.GeneratedMessage {
  factory PubsubMessagePublishedEvent({
    $core.String? topic,
    $core.List<$core.int>? messageContent,
  }) {
    final result = create();
    if (topic != null) result.topic = topic;
    if (messageContent != null) result.messageContent = messageContent;
    return result;
  }

  PubsubMessagePublishedEvent._();

  factory PubsubMessagePublishedEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PubsubMessagePublishedEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PubsubMessagePublishedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'topic')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'messageContent', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PubsubMessagePublishedEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PubsubMessagePublishedEvent copyWith(
          void Function(PubsubMessagePublishedEvent) updates) =>
      super.copyWith(
              (message) => updates(message as PubsubMessagePublishedEvent))
          as PubsubMessagePublishedEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PubsubMessagePublishedEvent create() =>
      PubsubMessagePublishedEvent._();
  @$core.override
  PubsubMessagePublishedEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PubsubMessagePublishedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PubsubMessagePublishedEvent>(create);
  static PubsubMessagePublishedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get topic => $_getSZ(0);
  @$pb.TagNumber(1)
  set topic($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTopic() => $_has(0);
  @$pb.TagNumber(1)
  void clearTopic() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get messageContent => $_getN(1);
  @$pb.TagNumber(2)
  set messageContent($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessageContent() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessageContent() => $_clearField(2);
}

class PubsubMessageReceivedEvent extends $pb.GeneratedMessage {
  factory PubsubMessageReceivedEvent({
    $core.String? topic,
    $core.List<$core.int>? messageContent,
    $core.String? peerId,
  }) {
    final result = create();
    if (topic != null) result.topic = topic;
    if (messageContent != null) result.messageContent = messageContent;
    if (peerId != null) result.peerId = peerId;
    return result;
  }

  PubsubMessageReceivedEvent._();

  factory PubsubMessageReceivedEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PubsubMessageReceivedEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PubsubMessageReceivedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'topic')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'messageContent', $pb.PbFieldType.OY)
    ..aOS(3, _omitFieldNames ? '' : 'peerId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PubsubMessageReceivedEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PubsubMessageReceivedEvent copyWith(
          void Function(PubsubMessageReceivedEvent) updates) =>
      super.copyWith(
              (message) => updates(message as PubsubMessageReceivedEvent))
          as PubsubMessageReceivedEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PubsubMessageReceivedEvent create() => PubsubMessageReceivedEvent._();
  @$core.override
  PubsubMessageReceivedEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PubsubMessageReceivedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PubsubMessageReceivedEvent>(create);
  static PubsubMessageReceivedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get topic => $_getSZ(0);
  @$pb.TagNumber(1)
  set topic($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTopic() => $_has(0);
  @$pb.TagNumber(1)
  void clearTopic() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get messageContent => $_getN(1);
  @$pb.TagNumber(2)
  set messageContent($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessageContent() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessageContent() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get peerId => $_getSZ(2);
  @$pb.TagNumber(3)
  set peerId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPeerId() => $_has(2);
  @$pb.TagNumber(3)
  void clearPeerId() => $_clearField(3);
}

class PubsubSubscriptionCreatedEvent extends $pb.GeneratedMessage {
  factory PubsubSubscriptionCreatedEvent({
    $core.String? topic,
  }) {
    final result = create();
    if (topic != null) result.topic = topic;
    return result;
  }

  PubsubSubscriptionCreatedEvent._();

  factory PubsubSubscriptionCreatedEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PubsubSubscriptionCreatedEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PubsubSubscriptionCreatedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'topic')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PubsubSubscriptionCreatedEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PubsubSubscriptionCreatedEvent copyWith(
          void Function(PubsubSubscriptionCreatedEvent) updates) =>
      super.copyWith(
              (message) => updates(message as PubsubSubscriptionCreatedEvent))
          as PubsubSubscriptionCreatedEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PubsubSubscriptionCreatedEvent create() =>
      PubsubSubscriptionCreatedEvent._();
  @$core.override
  PubsubSubscriptionCreatedEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PubsubSubscriptionCreatedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PubsubSubscriptionCreatedEvent>(create);
  static PubsubSubscriptionCreatedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get topic => $_getSZ(0);
  @$pb.TagNumber(1)
  set topic($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTopic() => $_has(0);
  @$pb.TagNumber(1)
  void clearTopic() => $_clearField(1);
}

class PubsubSubscriptionCancelledEvent extends $pb.GeneratedMessage {
  factory PubsubSubscriptionCancelledEvent({
    $core.String? topic,
  }) {
    final result = create();
    if (topic != null) result.topic = topic;
    return result;
  }

  PubsubSubscriptionCancelledEvent._();

  factory PubsubSubscriptionCancelledEvent.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PubsubSubscriptionCancelledEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PubsubSubscriptionCancelledEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'topic')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PubsubSubscriptionCancelledEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PubsubSubscriptionCancelledEvent copyWith(
          void Function(PubsubSubscriptionCancelledEvent) updates) =>
      super.copyWith(
              (message) => updates(message as PubsubSubscriptionCancelledEvent))
          as PubsubSubscriptionCancelledEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PubsubSubscriptionCancelledEvent create() =>
      PubsubSubscriptionCancelledEvent._();
  @$core.override
  PubsubSubscriptionCancelledEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PubsubSubscriptionCancelledEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PubsubSubscriptionCancelledEvent>(
          create);
  static PubsubSubscriptionCancelledEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get topic => $_getSZ(0);
  @$pb.TagNumber(1)
  set topic($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTopic() => $_has(0);
  @$pb.TagNumber(1)
  void clearTopic() => $_clearField(1);
}

class CircuitRelayCreatedEvent extends $pb.GeneratedMessage {
  factory CircuitRelayCreatedEvent({
    $core.String? relayAddress,
  }) {
    final result = create();
    if (relayAddress != null) result.relayAddress = relayAddress;
    return result;
  }

  CircuitRelayCreatedEvent._();

  factory CircuitRelayCreatedEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CircuitRelayCreatedEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CircuitRelayCreatedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'relayAddress')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CircuitRelayCreatedEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CircuitRelayCreatedEvent copyWith(
          void Function(CircuitRelayCreatedEvent) updates) =>
      super.copyWith((message) => updates(message as CircuitRelayCreatedEvent))
          as CircuitRelayCreatedEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CircuitRelayCreatedEvent create() => CircuitRelayCreatedEvent._();
  @$core.override
  CircuitRelayCreatedEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CircuitRelayCreatedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CircuitRelayCreatedEvent>(create);
  static CircuitRelayCreatedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get relayAddress => $_getSZ(0);
  @$pb.TagNumber(1)
  set relayAddress($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRelayAddress() => $_has(0);
  @$pb.TagNumber(1)
  void clearRelayAddress() => $_clearField(1);
}

class CircuitRelayClosedEvent extends $pb.GeneratedMessage {
  factory CircuitRelayClosedEvent({
    $core.String? relayAddress,
    $core.String? reason,
  }) {
    final result = create();
    if (relayAddress != null) result.relayAddress = relayAddress;
    if (reason != null) result.reason = reason;
    return result;
  }

  CircuitRelayClosedEvent._();

  factory CircuitRelayClosedEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CircuitRelayClosedEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CircuitRelayClosedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'relayAddress')
    ..aOS(2, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CircuitRelayClosedEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CircuitRelayClosedEvent copyWith(
          void Function(CircuitRelayClosedEvent) updates) =>
      super.copyWith((message) => updates(message as CircuitRelayClosedEvent))
          as CircuitRelayClosedEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CircuitRelayClosedEvent create() => CircuitRelayClosedEvent._();
  @$core.override
  CircuitRelayClosedEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CircuitRelayClosedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CircuitRelayClosedEvent>(create);
  static CircuitRelayClosedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get relayAddress => $_getSZ(0);
  @$pb.TagNumber(1)
  set relayAddress($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRelayAddress() => $_has(0);
  @$pb.TagNumber(1)
  void clearRelayAddress() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get reason => $_getSZ(1);
  @$pb.TagNumber(2)
  set reason($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReason() => $_has(1);
  @$pb.TagNumber(2)
  void clearReason() => $_clearField(2);
}

class CircuitRelayTrafficEvent extends $pb.GeneratedMessage {
  factory CircuitRelayTrafficEvent({
    $core.String? relayAddress,
    $fixnum.Int64? dataSize,
  }) {
    final result = create();
    if (relayAddress != null) result.relayAddress = relayAddress;
    if (dataSize != null) result.dataSize = dataSize;
    return result;
  }

  CircuitRelayTrafficEvent._();

  factory CircuitRelayTrafficEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CircuitRelayTrafficEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CircuitRelayTrafficEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'relayAddress')
    ..aInt64(2, _omitFieldNames ? '' : 'dataSize')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CircuitRelayTrafficEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CircuitRelayTrafficEvent copyWith(
          void Function(CircuitRelayTrafficEvent) updates) =>
      super.copyWith((message) => updates(message as CircuitRelayTrafficEvent))
          as CircuitRelayTrafficEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CircuitRelayTrafficEvent create() => CircuitRelayTrafficEvent._();
  @$core.override
  CircuitRelayTrafficEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CircuitRelayTrafficEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CircuitRelayTrafficEvent>(create);
  static CircuitRelayTrafficEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get relayAddress => $_getSZ(0);
  @$pb.TagNumber(1)
  set relayAddress($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRelayAddress() => $_has(0);
  @$pb.TagNumber(1)
  void clearRelayAddress() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get dataSize => $_getI64(1);
  @$pb.TagNumber(2)
  set dataSize($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDataSize() => $_has(1);
  @$pb.TagNumber(2)
  void clearDataSize() => $_clearField(2);
}

class CircuitRelayDataReceivedEvent extends $pb.GeneratedMessage {
  factory CircuitRelayDataReceivedEvent({
    $core.String? relayAddress,
    $fixnum.Int64? dataSize,
  }) {
    final result = create();
    if (relayAddress != null) result.relayAddress = relayAddress;
    if (dataSize != null) result.dataSize = dataSize;
    return result;
  }

  CircuitRelayDataReceivedEvent._();

  factory CircuitRelayDataReceivedEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CircuitRelayDataReceivedEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CircuitRelayDataReceivedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'relayAddress')
    ..aInt64(2, _omitFieldNames ? '' : 'dataSize')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CircuitRelayDataReceivedEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CircuitRelayDataReceivedEvent copyWith(
          void Function(CircuitRelayDataReceivedEvent) updates) =>
      super.copyWith(
              (message) => updates(message as CircuitRelayDataReceivedEvent))
          as CircuitRelayDataReceivedEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CircuitRelayDataReceivedEvent create() =>
      CircuitRelayDataReceivedEvent._();
  @$core.override
  CircuitRelayDataReceivedEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CircuitRelayDataReceivedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CircuitRelayDataReceivedEvent>(create);
  static CircuitRelayDataReceivedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get relayAddress => $_getSZ(0);
  @$pb.TagNumber(1)
  set relayAddress($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRelayAddress() => $_has(0);
  @$pb.TagNumber(1)
  void clearRelayAddress() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get dataSize => $_getI64(1);
  @$pb.TagNumber(2)
  set dataSize($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDataSize() => $_has(1);
  @$pb.TagNumber(2)
  void clearDataSize() => $_clearField(2);
}

class CircuitRelayDataSentEvent extends $pb.GeneratedMessage {
  factory CircuitRelayDataSentEvent({
    $core.String? relayAddress,
    $fixnum.Int64? dataSize,
  }) {
    final result = create();
    if (relayAddress != null) result.relayAddress = relayAddress;
    if (dataSize != null) result.dataSize = dataSize;
    return result;
  }

  CircuitRelayDataSentEvent._();

  factory CircuitRelayDataSentEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CircuitRelayDataSentEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CircuitRelayDataSentEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'relayAddress')
    ..aInt64(2, _omitFieldNames ? '' : 'dataSize')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CircuitRelayDataSentEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CircuitRelayDataSentEvent copyWith(
          void Function(CircuitRelayDataSentEvent) updates) =>
      super.copyWith((message) => updates(message as CircuitRelayDataSentEvent))
          as CircuitRelayDataSentEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CircuitRelayDataSentEvent create() => CircuitRelayDataSentEvent._();
  @$core.override
  CircuitRelayDataSentEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CircuitRelayDataSentEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CircuitRelayDataSentEvent>(create);
  static CircuitRelayDataSentEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get relayAddress => $_getSZ(0);
  @$pb.TagNumber(1)
  set relayAddress($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRelayAddress() => $_has(0);
  @$pb.TagNumber(1)
  void clearRelayAddress() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get dataSize => $_getI64(1);
  @$pb.TagNumber(2)
  set dataSize($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDataSize() => $_has(1);
  @$pb.TagNumber(2)
  void clearDataSize() => $_clearField(2);
}

class CircuitRelayFailedEvent extends $pb.GeneratedMessage {
  factory CircuitRelayFailedEvent({
    $core.String? relayAddress,
    $core.String? reason,
  }) {
    final result = create();
    if (relayAddress != null) result.relayAddress = relayAddress;
    if (reason != null) result.reason = reason;
    return result;
  }

  CircuitRelayFailedEvent._();

  factory CircuitRelayFailedEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CircuitRelayFailedEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CircuitRelayFailedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'relayAddress')
    ..aOS(2, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CircuitRelayFailedEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CircuitRelayFailedEvent copyWith(
          void Function(CircuitRelayFailedEvent) updates) =>
      super.copyWith((message) => updates(message as CircuitRelayFailedEvent))
          as CircuitRelayFailedEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CircuitRelayFailedEvent create() => CircuitRelayFailedEvent._();
  @$core.override
  CircuitRelayFailedEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CircuitRelayFailedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CircuitRelayFailedEvent>(create);
  static CircuitRelayFailedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get relayAddress => $_getSZ(0);
  @$pb.TagNumber(1)
  set relayAddress($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRelayAddress() => $_has(0);
  @$pb.TagNumber(1)
  void clearRelayAddress() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get reason => $_getSZ(1);
  @$pb.TagNumber(2)
  set reason($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReason() => $_has(1);
  @$pb.TagNumber(2)
  void clearReason() => $_clearField(2);
}

class StreamStartedEvent extends $pb.GeneratedMessage {
  factory StreamStartedEvent({
    $core.String? streamId,
    $core.String? peerId,
  }) {
    final result = create();
    if (streamId != null) result.streamId = streamId;
    if (peerId != null) result.peerId = peerId;
    return result;
  }

  StreamStartedEvent._();

  factory StreamStartedEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StreamStartedEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StreamStartedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'streamId')
    ..aOS(2, _omitFieldNames ? '' : 'peerId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamStartedEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamStartedEvent copyWith(void Function(StreamStartedEvent) updates) =>
      super.copyWith((message) => updates(message as StreamStartedEvent))
          as StreamStartedEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StreamStartedEvent create() => StreamStartedEvent._();
  @$core.override
  StreamStartedEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StreamStartedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StreamStartedEvent>(create);
  static StreamStartedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get streamId => $_getSZ(0);
  @$pb.TagNumber(1)
  set streamId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStreamId() => $_has(0);
  @$pb.TagNumber(1)
  void clearStreamId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get peerId => $_getSZ(1);
  @$pb.TagNumber(2)
  set peerId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPeerId() => $_has(1);
  @$pb.TagNumber(2)
  void clearPeerId() => $_clearField(2);
}

class StreamEndedEvent extends $pb.GeneratedMessage {
  factory StreamEndedEvent({
    $core.String? streamId,
    $core.String? peerId,
    $core.String? reason,
  }) {
    final result = create();
    if (streamId != null) result.streamId = streamId;
    if (peerId != null) result.peerId = peerId;
    if (reason != null) result.reason = reason;
    return result;
  }

  StreamEndedEvent._();

  factory StreamEndedEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StreamEndedEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StreamEndedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'streamId')
    ..aOS(2, _omitFieldNames ? '' : 'peerId')
    ..aOS(3, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamEndedEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamEndedEvent copyWith(void Function(StreamEndedEvent) updates) =>
      super.copyWith((message) => updates(message as StreamEndedEvent))
          as StreamEndedEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StreamEndedEvent create() => StreamEndedEvent._();
  @$core.override
  StreamEndedEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StreamEndedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StreamEndedEvent>(create);
  static StreamEndedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get streamId => $_getSZ(0);
  @$pb.TagNumber(1)
  set streamId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStreamId() => $_has(0);
  @$pb.TagNumber(1)
  void clearStreamId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get peerId => $_getSZ(1);
  @$pb.TagNumber(2)
  set peerId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPeerId() => $_has(1);
  @$pb.TagNumber(2)
  void clearPeerId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get reason => $_getSZ(2);
  @$pb.TagNumber(3)
  set reason($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasReason() => $_has(2);
  @$pb.TagNumber(3)
  void clearReason() => $_clearField(3);
}

class PeerDiscoveredEvent extends $pb.GeneratedMessage {
  factory PeerDiscoveredEvent({
    $core.String? peerId,
  }) {
    final result = create();
    if (peerId != null) result.peerId = peerId;
    return result;
  }

  PeerDiscoveredEvent._();

  factory PeerDiscoveredEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PeerDiscoveredEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PeerDiscoveredEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'peerId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PeerDiscoveredEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PeerDiscoveredEvent copyWith(void Function(PeerDiscoveredEvent) updates) =>
      super.copyWith((message) => updates(message as PeerDiscoveredEvent))
          as PeerDiscoveredEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PeerDiscoveredEvent create() => PeerDiscoveredEvent._();
  @$core.override
  PeerDiscoveredEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PeerDiscoveredEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PeerDiscoveredEvent>(create);
  static PeerDiscoveredEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get peerId => $_getSZ(0);
  @$pb.TagNumber(1)
  set peerId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPeerId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerId() => $_clearField(1);
}

class NodeStartedEvent extends $pb.GeneratedMessage {
  factory NodeStartedEvent() => create();

  NodeStartedEvent._();

  factory NodeStartedEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory NodeStartedEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NodeStartedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeStartedEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeStartedEvent copyWith(void Function(NodeStartedEvent) updates) =>
      super.copyWith((message) => updates(message as NodeStartedEvent))
          as NodeStartedEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NodeStartedEvent create() => NodeStartedEvent._();
  @$core.override
  NodeStartedEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static NodeStartedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NodeStartedEvent>(create);
  static NodeStartedEvent? _defaultInstance;
}

class NodeStoppedEvent extends $pb.GeneratedMessage {
  factory NodeStoppedEvent() => create();

  NodeStoppedEvent._();

  factory NodeStoppedEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory NodeStoppedEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NodeStoppedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeStoppedEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeStoppedEvent copyWith(void Function(NodeStoppedEvent) updates) =>
      super.copyWith((message) => updates(message as NodeStoppedEvent))
          as NodeStoppedEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NodeStoppedEvent create() => NodeStoppedEvent._();
  @$core.override
  NodeStoppedEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static NodeStoppedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NodeStoppedEvent>(create);
  static NodeStoppedEvent? _defaultInstance;
}

class NodeErrorEvent extends $pb.GeneratedMessage {
  factory NodeErrorEvent({
    NodeErrorEvent_ErrorType? errorType,
    $core.String? message,
    $core.String? stackTrace,
    $core.String? source,
  }) {
    final result = create();
    if (errorType != null) result.errorType = errorType;
    if (message != null) result.message = message;
    if (stackTrace != null) result.stackTrace = stackTrace;
    if (source != null) result.source = source;
    return result;
  }

  NodeErrorEvent._();

  factory NodeErrorEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory NodeErrorEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NodeErrorEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aE<NodeErrorEvent_ErrorType>(1, _omitFieldNames ? '' : 'errorType',
        enumValues: NodeErrorEvent_ErrorType.values)
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..aOS(3, _omitFieldNames ? '' : 'stackTrace')
    ..aOS(4, _omitFieldNames ? '' : 'source')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeErrorEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeErrorEvent copyWith(void Function(NodeErrorEvent) updates) =>
      super.copyWith((message) => updates(message as NodeErrorEvent))
          as NodeErrorEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NodeErrorEvent create() => NodeErrorEvent._();
  @$core.override
  NodeErrorEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static NodeErrorEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NodeErrorEvent>(create);
  static NodeErrorEvent? _defaultInstance;

  @$pb.TagNumber(1)
  NodeErrorEvent_ErrorType get errorType => $_getN(0);
  @$pb.TagNumber(1)
  set errorType(NodeErrorEvent_ErrorType value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasErrorType() => $_has(0);
  @$pb.TagNumber(1)
  void clearErrorType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get stackTrace => $_getSZ(2);
  @$pb.TagNumber(3)
  set stackTrace($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStackTrace() => $_has(2);
  @$pb.TagNumber(3)
  void clearStackTrace() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get source => $_getSZ(3);
  @$pb.TagNumber(4)
  set source($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSource() => $_has(3);
  @$pb.TagNumber(4)
  void clearSource() => $_clearField(4);
}

class NetworkStatusChangedEvent extends $pb.GeneratedMessage {
  factory NetworkStatusChangedEvent({
    NetworkStatusChangedEvent_ChangeType? changeType,
  }) {
    final result = create();
    if (changeType != null) result.changeType = changeType;
    return result;
  }

  NetworkStatusChangedEvent._();

  factory NetworkStatusChangedEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory NetworkStatusChangedEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NetworkStatusChangedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aE<NetworkStatusChangedEvent_ChangeType>(
        1, _omitFieldNames ? '' : 'changeType',
        enumValues: NetworkStatusChangedEvent_ChangeType.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NetworkStatusChangedEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NetworkStatusChangedEvent copyWith(
          void Function(NetworkStatusChangedEvent) updates) =>
      super.copyWith((message) => updates(message as NetworkStatusChangedEvent))
          as NetworkStatusChangedEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NetworkStatusChangedEvent create() => NetworkStatusChangedEvent._();
  @$core.override
  NetworkStatusChangedEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static NetworkStatusChangedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NetworkStatusChangedEvent>(create);
  static NetworkStatusChangedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  NetworkStatusChangedEvent_ChangeType get changeType => $_getN(0);
  @$pb.TagNumber(1)
  set changeType(NetworkStatusChangedEvent_ChangeType value) =>
      $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasChangeType() => $_has(0);
  @$pb.TagNumber(1)
  void clearChangeType() => $_clearField(1);
}

class ResourceLimitExceededEvent extends $pb.GeneratedMessage {
  factory ResourceLimitExceededEvent({
    $core.String? resourceType,
    $core.String? message,
  }) {
    final result = create();
    if (resourceType != null) result.resourceType = resourceType;
    if (message != null) result.message = message;
    return result;
  }

  ResourceLimitExceededEvent._();

  factory ResourceLimitExceededEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ResourceLimitExceededEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ResourceLimitExceededEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'resourceType')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResourceLimitExceededEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResourceLimitExceededEvent copyWith(
          void Function(ResourceLimitExceededEvent) updates) =>
      super.copyWith(
              (message) => updates(message as ResourceLimitExceededEvent))
          as ResourceLimitExceededEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ResourceLimitExceededEvent create() => ResourceLimitExceededEvent._();
  @$core.override
  ResourceLimitExceededEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ResourceLimitExceededEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ResourceLimitExceededEvent>(create);
  static ResourceLimitExceededEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get resourceType => $_getSZ(0);
  @$pb.TagNumber(1)
  set resourceType($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasResourceType() => $_has(0);
  @$pb.TagNumber(1)
  void clearResourceType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => $_clearField(2);
}

class SystemAlertEvent extends $pb.GeneratedMessage {
  factory SystemAlertEvent({
    $core.String? alertType,
    $core.String? message,
  }) {
    final result = create();
    if (alertType != null) result.alertType = alertType;
    if (message != null) result.message = message;
    return result;
  }

  SystemAlertEvent._();

  factory SystemAlertEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SystemAlertEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SystemAlertEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'alertType')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SystemAlertEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SystemAlertEvent copyWith(void Function(SystemAlertEvent) updates) =>
      super.copyWith((message) => updates(message as SystemAlertEvent))
          as SystemAlertEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SystemAlertEvent create() => SystemAlertEvent._();
  @$core.override
  SystemAlertEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SystemAlertEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SystemAlertEvent>(create);
  static SystemAlertEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get alertType => $_getSZ(0);
  @$pb.TagNumber(1)
  set alertType($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAlertType() => $_has(0);
  @$pb.TagNumber(1)
  void clearAlertType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => $_clearField(2);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
