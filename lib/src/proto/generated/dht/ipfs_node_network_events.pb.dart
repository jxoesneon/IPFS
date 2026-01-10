//
//  Generated code. Do not modify.
//  source: dht/ipfs_node_network_events.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'ipfs_node_network_events.pbenum.dart';

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
    final $result = create();
    if (peerConnected != null) {
      $result.peerConnected = peerConnected;
    }
    if (peerDisconnected != null) {
      $result.peerDisconnected = peerDisconnected;
    }
    if (connectionAttempted != null) {
      $result.connectionAttempted = connectionAttempted;
    }
    if (connectionFailed != null) {
      $result.connectionFailed = connectionFailed;
    }
    if (messageReceived != null) {
      $result.messageReceived = messageReceived;
    }
    if (messageSent != null) {
      $result.messageSent = messageSent;
    }
    if (blockReceived != null) {
      $result.blockReceived = blockReceived;
    }
    if (blockSent != null) {
      $result.blockSent = blockSent;
    }
    if (dhtQueryStarted != null) {
      $result.dhtQueryStarted = dhtQueryStarted;
    }
    if (dhtQueryCompleted != null) {
      $result.dhtQueryCompleted = dhtQueryCompleted;
    }
    if (dhtValueFound != null) {
      $result.dhtValueFound = dhtValueFound;
    }
    if (dhtValueProvided != null) {
      $result.dhtValueProvided = dhtValueProvided;
    }
    if (dhtValueNotFound != null) {
      $result.dhtValueNotFound = dhtValueNotFound;
    }
    if (pubsubMessagePublished != null) {
      $result.pubsubMessagePublished = pubsubMessagePublished;
    }
    if (pubsubMessageReceived != null) {
      $result.pubsubMessageReceived = pubsubMessageReceived;
    }
    if (pubsubSubscriptionCreated != null) {
      $result.pubsubSubscriptionCreated = pubsubSubscriptionCreated;
    }
    if (pubsubSubscriptionCancelled != null) {
      $result.pubsubSubscriptionCancelled = pubsubSubscriptionCancelled;
    }
    if (circuitRelayCreated != null) {
      $result.circuitRelayCreated = circuitRelayCreated;
    }
    if (circuitRelayClosed != null) {
      $result.circuitRelayClosed = circuitRelayClosed;
    }
    if (circuitRelayTraffic != null) {
      $result.circuitRelayTraffic = circuitRelayTraffic;
    }
    if (circuitRelayFailed != null) {
      $result.circuitRelayFailed = circuitRelayFailed;
    }
    if (nodeStarted != null) {
      $result.nodeStarted = nodeStarted;
    }
    if (nodeStopped != null) {
      $result.nodeStopped = nodeStopped;
    }
    if (error != null) {
      $result.error = error;
    }
    if (networkChanged != null) {
      $result.networkChanged = networkChanged;
    }
    if (dhtProviderAdded != null) {
      $result.dhtProviderAdded = dhtProviderAdded;
    }
    if (dhtProviderQueried != null) {
      $result.dhtProviderQueried = dhtProviderQueried;
    }
    if (streamStarted != null) {
      $result.streamStarted = streamStarted;
    }
    if (streamEnded != null) {
      $result.streamEnded = streamEnded;
    }
    if (peerDiscovered != null) {
      $result.peerDiscovered = peerDiscovered;
    }
    if (circuitRelayDataReceived != null) {
      $result.circuitRelayDataReceived = circuitRelayDataReceived;
    }
    if (circuitRelayDataSent != null) {
      $result.circuitRelayDataSent = circuitRelayDataSent;
    }
    if (resourceLimitExceeded != null) {
      $result.resourceLimitExceeded = resourceLimitExceeded;
    }
    if (systemAlert != null) {
      $result.systemAlert = systemAlert;
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

  NetworkEvent_Event whichEvent() => _NetworkEvent_EventByTag[$_whichOneof(0)]!;
  void clearEvent() => clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  PeerConnectedEvent get peerConnected => $_getN(0);
  @$pb.TagNumber(1)
  set peerConnected(PeerConnectedEvent v) {
    setField(1, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasPeerConnected() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerConnected() => clearField(1);
  @$pb.TagNumber(1)
  PeerConnectedEvent ensurePeerConnected() => $_ensure(0);

  @$pb.TagNumber(2)
  PeerDisconnectedEvent get peerDisconnected => $_getN(1);
  @$pb.TagNumber(2)
  set peerDisconnected(PeerDisconnectedEvent v) {
    setField(2, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasPeerDisconnected() => $_has(1);
  @$pb.TagNumber(2)
  void clearPeerDisconnected() => clearField(2);
  @$pb.TagNumber(2)
  PeerDisconnectedEvent ensurePeerDisconnected() => $_ensure(1);

  @$pb.TagNumber(3)
  ConnectionAttemptedEvent get connectionAttempted => $_getN(2);
  @$pb.TagNumber(3)
  set connectionAttempted(ConnectionAttemptedEvent v) {
    setField(3, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasConnectionAttempted() => $_has(2);
  @$pb.TagNumber(3)
  void clearConnectionAttempted() => clearField(3);
  @$pb.TagNumber(3)
  ConnectionAttemptedEvent ensureConnectionAttempted() => $_ensure(2);

  @$pb.TagNumber(4)
  ConnectionFailedEvent get connectionFailed => $_getN(3);
  @$pb.TagNumber(4)
  set connectionFailed(ConnectionFailedEvent v) {
    setField(4, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasConnectionFailed() => $_has(3);
  @$pb.TagNumber(4)
  void clearConnectionFailed() => clearField(4);
  @$pb.TagNumber(4)
  ConnectionFailedEvent ensureConnectionFailed() => $_ensure(3);

  @$pb.TagNumber(5)
  MessageReceivedEvent get messageReceived => $_getN(4);
  @$pb.TagNumber(5)
  set messageReceived(MessageReceivedEvent v) {
    setField(5, v);
  }

  @$pb.TagNumber(5)
  $core.bool hasMessageReceived() => $_has(4);
  @$pb.TagNumber(5)
  void clearMessageReceived() => clearField(5);
  @$pb.TagNumber(5)
  MessageReceivedEvent ensureMessageReceived() => $_ensure(4);

  @$pb.TagNumber(6)
  MessageSentEvent get messageSent => $_getN(5);
  @$pb.TagNumber(6)
  set messageSent(MessageSentEvent v) {
    setField(6, v);
  }

  @$pb.TagNumber(6)
  $core.bool hasMessageSent() => $_has(5);
  @$pb.TagNumber(6)
  void clearMessageSent() => clearField(6);
  @$pb.TagNumber(6)
  MessageSentEvent ensureMessageSent() => $_ensure(5);

  @$pb.TagNumber(7)
  BlockReceivedEvent get blockReceived => $_getN(6);
  @$pb.TagNumber(7)
  set blockReceived(BlockReceivedEvent v) {
    setField(7, v);
  }

  @$pb.TagNumber(7)
  $core.bool hasBlockReceived() => $_has(6);
  @$pb.TagNumber(7)
  void clearBlockReceived() => clearField(7);
  @$pb.TagNumber(7)
  BlockReceivedEvent ensureBlockReceived() => $_ensure(6);

  @$pb.TagNumber(8)
  BlockSentEvent get blockSent => $_getN(7);
  @$pb.TagNumber(8)
  set blockSent(BlockSentEvent v) {
    setField(8, v);
  }

  @$pb.TagNumber(8)
  $core.bool hasBlockSent() => $_has(7);
  @$pb.TagNumber(8)
  void clearBlockSent() => clearField(8);
  @$pb.TagNumber(8)
  BlockSentEvent ensureBlockSent() => $_ensure(7);

  @$pb.TagNumber(9)
  DHTQueryStartedEvent get dhtQueryStarted => $_getN(8);
  @$pb.TagNumber(9)
  set dhtQueryStarted(DHTQueryStartedEvent v) {
    setField(9, v);
  }

  @$pb.TagNumber(9)
  $core.bool hasDhtQueryStarted() => $_has(8);
  @$pb.TagNumber(9)
  void clearDhtQueryStarted() => clearField(9);
  @$pb.TagNumber(9)
  DHTQueryStartedEvent ensureDhtQueryStarted() => $_ensure(8);

  @$pb.TagNumber(10)
  DHTQueryCompletedEvent get dhtQueryCompleted => $_getN(9);
  @$pb.TagNumber(10)
  set dhtQueryCompleted(DHTQueryCompletedEvent v) {
    setField(10, v);
  }

  @$pb.TagNumber(10)
  $core.bool hasDhtQueryCompleted() => $_has(9);
  @$pb.TagNumber(10)
  void clearDhtQueryCompleted() => clearField(10);
  @$pb.TagNumber(10)
  DHTQueryCompletedEvent ensureDhtQueryCompleted() => $_ensure(9);

  @$pb.TagNumber(11)
  DHTValueFoundEvent get dhtValueFound => $_getN(10);
  @$pb.TagNumber(11)
  set dhtValueFound(DHTValueFoundEvent v) {
    setField(11, v);
  }

  @$pb.TagNumber(11)
  $core.bool hasDhtValueFound() => $_has(10);
  @$pb.TagNumber(11)
  void clearDhtValueFound() => clearField(11);
  @$pb.TagNumber(11)
  DHTValueFoundEvent ensureDhtValueFound() => $_ensure(10);

  @$pb.TagNumber(12)
  DHTValueProvidedEvent get dhtValueProvided => $_getN(11);
  @$pb.TagNumber(12)
  set dhtValueProvided(DHTValueProvidedEvent v) {
    setField(12, v);
  }

  @$pb.TagNumber(12)
  $core.bool hasDhtValueProvided() => $_has(11);
  @$pb.TagNumber(12)
  void clearDhtValueProvided() => clearField(12);
  @$pb.TagNumber(12)
  DHTValueProvidedEvent ensureDhtValueProvided() => $_ensure(11);

  @$pb.TagNumber(13)
  DHTValueNotFoundEvent get dhtValueNotFound => $_getN(12);
  @$pb.TagNumber(13)
  set dhtValueNotFound(DHTValueNotFoundEvent v) {
    setField(13, v);
  }

  @$pb.TagNumber(13)
  $core.bool hasDhtValueNotFound() => $_has(12);
  @$pb.TagNumber(13)
  void clearDhtValueNotFound() => clearField(13);
  @$pb.TagNumber(13)
  DHTValueNotFoundEvent ensureDhtValueNotFound() => $_ensure(12);

  @$pb.TagNumber(14)
  PubsubMessagePublishedEvent get pubsubMessagePublished => $_getN(13);
  @$pb.TagNumber(14)
  set pubsubMessagePublished(PubsubMessagePublishedEvent v) {
    setField(14, v);
  }

  @$pb.TagNumber(14)
  $core.bool hasPubsubMessagePublished() => $_has(13);
  @$pb.TagNumber(14)
  void clearPubsubMessagePublished() => clearField(14);
  @$pb.TagNumber(14)
  PubsubMessagePublishedEvent ensurePubsubMessagePublished() => $_ensure(13);

  @$pb.TagNumber(15)
  PubsubMessageReceivedEvent get pubsubMessageReceived => $_getN(14);
  @$pb.TagNumber(15)
  set pubsubMessageReceived(PubsubMessageReceivedEvent v) {
    setField(15, v);
  }

  @$pb.TagNumber(15)
  $core.bool hasPubsubMessageReceived() => $_has(14);
  @$pb.TagNumber(15)
  void clearPubsubMessageReceived() => clearField(15);
  @$pb.TagNumber(15)
  PubsubMessageReceivedEvent ensurePubsubMessageReceived() => $_ensure(14);

  @$pb.TagNumber(16)
  PubsubSubscriptionCreatedEvent get pubsubSubscriptionCreated => $_getN(15);
  @$pb.TagNumber(16)
  set pubsubSubscriptionCreated(PubsubSubscriptionCreatedEvent v) {
    setField(16, v);
  }

  @$pb.TagNumber(16)
  $core.bool hasPubsubSubscriptionCreated() => $_has(15);
  @$pb.TagNumber(16)
  void clearPubsubSubscriptionCreated() => clearField(16);
  @$pb.TagNumber(16)
  PubsubSubscriptionCreatedEvent ensurePubsubSubscriptionCreated() =>
      $_ensure(15);

  @$pb.TagNumber(17)
  PubsubSubscriptionCancelledEvent get pubsubSubscriptionCancelled =>
      $_getN(16);
  @$pb.TagNumber(17)
  set pubsubSubscriptionCancelled(PubsubSubscriptionCancelledEvent v) {
    setField(17, v);
  }

  @$pb.TagNumber(17)
  $core.bool hasPubsubSubscriptionCancelled() => $_has(16);
  @$pb.TagNumber(17)
  void clearPubsubSubscriptionCancelled() => clearField(17);
  @$pb.TagNumber(17)
  PubsubSubscriptionCancelledEvent ensurePubsubSubscriptionCancelled() =>
      $_ensure(16);

  @$pb.TagNumber(18)
  CircuitRelayCreatedEvent get circuitRelayCreated => $_getN(17);
  @$pb.TagNumber(18)
  set circuitRelayCreated(CircuitRelayCreatedEvent v) {
    setField(18, v);
  }

  @$pb.TagNumber(18)
  $core.bool hasCircuitRelayCreated() => $_has(17);
  @$pb.TagNumber(18)
  void clearCircuitRelayCreated() => clearField(18);
  @$pb.TagNumber(18)
  CircuitRelayCreatedEvent ensureCircuitRelayCreated() => $_ensure(17);

  @$pb.TagNumber(19)
  CircuitRelayClosedEvent get circuitRelayClosed => $_getN(18);
  @$pb.TagNumber(19)
  set circuitRelayClosed(CircuitRelayClosedEvent v) {
    setField(19, v);
  }

  @$pb.TagNumber(19)
  $core.bool hasCircuitRelayClosed() => $_has(18);
  @$pb.TagNumber(19)
  void clearCircuitRelayClosed() => clearField(19);
  @$pb.TagNumber(19)
  CircuitRelayClosedEvent ensureCircuitRelayClosed() => $_ensure(18);

  @$pb.TagNumber(20)
  CircuitRelayTrafficEvent get circuitRelayTraffic => $_getN(19);
  @$pb.TagNumber(20)
  set circuitRelayTraffic(CircuitRelayTrafficEvent v) {
    setField(20, v);
  }

  @$pb.TagNumber(20)
  $core.bool hasCircuitRelayTraffic() => $_has(19);
  @$pb.TagNumber(20)
  void clearCircuitRelayTraffic() => clearField(20);
  @$pb.TagNumber(20)
  CircuitRelayTrafficEvent ensureCircuitRelayTraffic() => $_ensure(19);

  @$pb.TagNumber(21)
  CircuitRelayFailedEvent get circuitRelayFailed => $_getN(20);
  @$pb.TagNumber(21)
  set circuitRelayFailed(CircuitRelayFailedEvent v) {
    setField(21, v);
  }

  @$pb.TagNumber(21)
  $core.bool hasCircuitRelayFailed() => $_has(20);
  @$pb.TagNumber(21)
  void clearCircuitRelayFailed() => clearField(21);
  @$pb.TagNumber(21)
  CircuitRelayFailedEvent ensureCircuitRelayFailed() => $_ensure(20);

  @$pb.TagNumber(22)
  NodeStartedEvent get nodeStarted => $_getN(21);
  @$pb.TagNumber(22)
  set nodeStarted(NodeStartedEvent v) {
    setField(22, v);
  }

  @$pb.TagNumber(22)
  $core.bool hasNodeStarted() => $_has(21);
  @$pb.TagNumber(22)
  void clearNodeStarted() => clearField(22);
  @$pb.TagNumber(22)
  NodeStartedEvent ensureNodeStarted() => $_ensure(21);

  @$pb.TagNumber(23)
  NodeStoppedEvent get nodeStopped => $_getN(22);
  @$pb.TagNumber(23)
  set nodeStopped(NodeStoppedEvent v) {
    setField(23, v);
  }

  @$pb.TagNumber(23)
  $core.bool hasNodeStopped() => $_has(22);
  @$pb.TagNumber(23)
  void clearNodeStopped() => clearField(23);
  @$pb.TagNumber(23)
  NodeStoppedEvent ensureNodeStopped() => $_ensure(22);

  @$pb.TagNumber(24)
  NodeErrorEvent get error => $_getN(23);
  @$pb.TagNumber(24)
  set error(NodeErrorEvent v) {
    setField(24, v);
  }

  @$pb.TagNumber(24)
  $core.bool hasError() => $_has(23);
  @$pb.TagNumber(24)
  void clearError() => clearField(24);
  @$pb.TagNumber(24)
  NodeErrorEvent ensureError() => $_ensure(23);

  @$pb.TagNumber(25)
  NetworkStatusChangedEvent get networkChanged => $_getN(24);
  @$pb.TagNumber(25)
  set networkChanged(NetworkStatusChangedEvent v) {
    setField(25, v);
  }

  @$pb.TagNumber(25)
  $core.bool hasNetworkChanged() => $_has(24);
  @$pb.TagNumber(25)
  void clearNetworkChanged() => clearField(25);
  @$pb.TagNumber(25)
  NetworkStatusChangedEvent ensureNetworkChanged() => $_ensure(24);

  @$pb.TagNumber(26)
  DHTProviderAddedEvent get dhtProviderAdded => $_getN(25);
  @$pb.TagNumber(26)
  set dhtProviderAdded(DHTProviderAddedEvent v) {
    setField(26, v);
  }

  @$pb.TagNumber(26)
  $core.bool hasDhtProviderAdded() => $_has(25);
  @$pb.TagNumber(26)
  void clearDhtProviderAdded() => clearField(26);
  @$pb.TagNumber(26)
  DHTProviderAddedEvent ensureDhtProviderAdded() => $_ensure(25);

  @$pb.TagNumber(27)
  DHTProviderQueriedEvent get dhtProviderQueried => $_getN(26);
  @$pb.TagNumber(27)
  set dhtProviderQueried(DHTProviderQueriedEvent v) {
    setField(27, v);
  }

  @$pb.TagNumber(27)
  $core.bool hasDhtProviderQueried() => $_has(26);
  @$pb.TagNumber(27)
  void clearDhtProviderQueried() => clearField(27);
  @$pb.TagNumber(27)
  DHTProviderQueriedEvent ensureDhtProviderQueried() => $_ensure(26);

  @$pb.TagNumber(28)
  StreamStartedEvent get streamStarted => $_getN(27);
  @$pb.TagNumber(28)
  set streamStarted(StreamStartedEvent v) {
    setField(28, v);
  }

  @$pb.TagNumber(28)
  $core.bool hasStreamStarted() => $_has(27);
  @$pb.TagNumber(28)
  void clearStreamStarted() => clearField(28);
  @$pb.TagNumber(28)
  StreamStartedEvent ensureStreamStarted() => $_ensure(27);

  @$pb.TagNumber(29)
  StreamEndedEvent get streamEnded => $_getN(28);
  @$pb.TagNumber(29)
  set streamEnded(StreamEndedEvent v) {
    setField(29, v);
  }

  @$pb.TagNumber(29)
  $core.bool hasStreamEnded() => $_has(28);
  @$pb.TagNumber(29)
  void clearStreamEnded() => clearField(29);
  @$pb.TagNumber(29)
  StreamEndedEvent ensureStreamEnded() => $_ensure(28);

  @$pb.TagNumber(30)
  PeerDiscoveredEvent get peerDiscovered => $_getN(29);
  @$pb.TagNumber(30)
  set peerDiscovered(PeerDiscoveredEvent v) {
    setField(30, v);
  }

  @$pb.TagNumber(30)
  $core.bool hasPeerDiscovered() => $_has(29);
  @$pb.TagNumber(30)
  void clearPeerDiscovered() => clearField(30);
  @$pb.TagNumber(30)
  PeerDiscoveredEvent ensurePeerDiscovered() => $_ensure(29);

  @$pb.TagNumber(31)
  CircuitRelayDataReceivedEvent get circuitRelayDataReceived => $_getN(30);
  @$pb.TagNumber(31)
  set circuitRelayDataReceived(CircuitRelayDataReceivedEvent v) {
    setField(31, v);
  }

  @$pb.TagNumber(31)
  $core.bool hasCircuitRelayDataReceived() => $_has(30);
  @$pb.TagNumber(31)
  void clearCircuitRelayDataReceived() => clearField(31);
  @$pb.TagNumber(31)
  CircuitRelayDataReceivedEvent ensureCircuitRelayDataReceived() =>
      $_ensure(30);

  @$pb.TagNumber(32)
  CircuitRelayDataSentEvent get circuitRelayDataSent => $_getN(31);
  @$pb.TagNumber(32)
  set circuitRelayDataSent(CircuitRelayDataSentEvent v) {
    setField(32, v);
  }

  @$pb.TagNumber(32)
  $core.bool hasCircuitRelayDataSent() => $_has(31);
  @$pb.TagNumber(32)
  void clearCircuitRelayDataSent() => clearField(32);
  @$pb.TagNumber(32)
  CircuitRelayDataSentEvent ensureCircuitRelayDataSent() => $_ensure(31);

  @$pb.TagNumber(33)
  ResourceLimitExceededEvent get resourceLimitExceeded => $_getN(32);
  @$pb.TagNumber(33)
  set resourceLimitExceeded(ResourceLimitExceededEvent v) {
    setField(33, v);
  }

  @$pb.TagNumber(33)
  $core.bool hasResourceLimitExceeded() => $_has(32);
  @$pb.TagNumber(33)
  void clearResourceLimitExceeded() => clearField(33);
  @$pb.TagNumber(33)
  ResourceLimitExceededEvent ensureResourceLimitExceeded() => $_ensure(32);

  @$pb.TagNumber(34)
  SystemAlertEvent get systemAlert => $_getN(33);
  @$pb.TagNumber(34)
  set systemAlert(SystemAlertEvent v) {
    setField(34, v);
  }

  @$pb.TagNumber(34)
  $core.bool hasSystemAlert() => $_has(33);
  @$pb.TagNumber(34)
  void clearSystemAlert() => clearField(34);
  @$pb.TagNumber(34)
  SystemAlertEvent ensureSystemAlert() => $_ensure(33);
}

/// Event message definitions:
class PeerConnectedEvent extends $pb.GeneratedMessage {
  factory PeerConnectedEvent({
    $core.String? peerId,
    $core.String? multiaddress,
  }) {
    final $result = create();
    if (peerId != null) {
      $result.peerId = peerId;
    }
    if (multiaddress != null) {
      $result.multiaddress = multiaddress;
    }
    return $result;
  }
  PeerConnectedEvent._() : super();
  factory PeerConnectedEvent.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory PeerConnectedEvent.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PeerConnectedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'peerId')
    ..aOS(2, _omitFieldNames ? '' : 'multiaddress')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  PeerConnectedEvent clone() => PeerConnectedEvent()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  PeerConnectedEvent copyWith(void Function(PeerConnectedEvent) updates) =>
      super.copyWith((message) => updates(message as PeerConnectedEvent))
          as PeerConnectedEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PeerConnectedEvent create() => PeerConnectedEvent._();
  PeerConnectedEvent createEmptyInstance() => create();
  static $pb.PbList<PeerConnectedEvent> createRepeated() =>
      $pb.PbList<PeerConnectedEvent>();
  @$core.pragma('dart2js:noInline')
  static PeerConnectedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PeerConnectedEvent>(create);
  static PeerConnectedEvent? _defaultInstance;

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
  $core.String get multiaddress => $_getSZ(1);
  @$pb.TagNumber(2)
  set multiaddress($core.String v) {
    $_setString(1, v);
  }

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
    final $result = create();
    if (peerId != null) {
      $result.peerId = peerId;
    }
    if (reason != null) {
      $result.reason = reason;
    }
    return $result;
  }
  PeerDisconnectedEvent._() : super();
  factory PeerDisconnectedEvent.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory PeerDisconnectedEvent.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PeerDisconnectedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'peerId')
    ..aOS(2, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  PeerDisconnectedEvent clone() =>
      PeerDisconnectedEvent()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  PeerDisconnectedEvent copyWith(
          void Function(PeerDisconnectedEvent) updates) =>
      super.copyWith((message) => updates(message as PeerDisconnectedEvent))
          as PeerDisconnectedEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PeerDisconnectedEvent create() => PeerDisconnectedEvent._();
  PeerDisconnectedEvent createEmptyInstance() => create();
  static $pb.PbList<PeerDisconnectedEvent> createRepeated() =>
      $pb.PbList<PeerDisconnectedEvent>();
  @$core.pragma('dart2js:noInline')
  static PeerDisconnectedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PeerDisconnectedEvent>(create);
  static PeerDisconnectedEvent? _defaultInstance;

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
  $core.String get reason => $_getSZ(1);
  @$pb.TagNumber(2)
  set reason($core.String v) {
    $_setString(1, v);
  }

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
    final $result = create();
    if (peerId != null) {
      $result.peerId = peerId;
    }
    if (success != null) {
      $result.success = success;
    }
    return $result;
  }
  ConnectionAttemptedEvent._() : super();
  factory ConnectionAttemptedEvent.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory ConnectionAttemptedEvent.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ConnectionAttemptedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'peerId')
    ..aOB(2, _omitFieldNames ? '' : 'success')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  ConnectionAttemptedEvent clone() =>
      ConnectionAttemptedEvent()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  ConnectionAttemptedEvent copyWith(
          void Function(ConnectionAttemptedEvent) updates) =>
      super.copyWith((message) => updates(message as ConnectionAttemptedEvent))
          as ConnectionAttemptedEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ConnectionAttemptedEvent create() => ConnectionAttemptedEvent._();
  ConnectionAttemptedEvent createEmptyInstance() => create();
  static $pb.PbList<ConnectionAttemptedEvent> createRepeated() =>
      $pb.PbList<ConnectionAttemptedEvent>();
  @$core.pragma('dart2js:noInline')
  static ConnectionAttemptedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ConnectionAttemptedEvent>(create);
  static ConnectionAttemptedEvent? _defaultInstance;

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
  $core.bool get success => $_getBF(1);
  @$pb.TagNumber(2)
  set success($core.bool v) {
    $_setBool(1, v);
  }

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
    final $result = create();
    if (peerId != null) {
      $result.peerId = peerId;
    }
    if (reason != null) {
      $result.reason = reason;
    }
    return $result;
  }
  ConnectionFailedEvent._() : super();
  factory ConnectionFailedEvent.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory ConnectionFailedEvent.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ConnectionFailedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'peerId')
    ..aOS(2, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  ConnectionFailedEvent clone() =>
      ConnectionFailedEvent()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  ConnectionFailedEvent copyWith(
          void Function(ConnectionFailedEvent) updates) =>
      super.copyWith((message) => updates(message as ConnectionFailedEvent))
          as ConnectionFailedEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ConnectionFailedEvent create() => ConnectionFailedEvent._();
  ConnectionFailedEvent createEmptyInstance() => create();
  static $pb.PbList<ConnectionFailedEvent> createRepeated() =>
      $pb.PbList<ConnectionFailedEvent>();
  @$core.pragma('dart2js:noInline')
  static ConnectionFailedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ConnectionFailedEvent>(create);
  static ConnectionFailedEvent? _defaultInstance;

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
  $core.String get reason => $_getSZ(1);
  @$pb.TagNumber(2)
  set reason($core.String v) {
    $_setString(1, v);
  }

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
    final $result = create();
    if (peerId != null) {
      $result.peerId = peerId;
    }
    if (messageContent != null) {
      $result.messageContent = messageContent;
    }
    return $result;
  }
  MessageReceivedEvent._() : super();
  factory MessageReceivedEvent.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory MessageReceivedEvent.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MessageReceivedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'peerId')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'messageContent', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  MessageReceivedEvent clone() =>
      MessageReceivedEvent()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  MessageReceivedEvent copyWith(void Function(MessageReceivedEvent) updates) =>
      super.copyWith((message) => updates(message as MessageReceivedEvent))
          as MessageReceivedEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MessageReceivedEvent create() => MessageReceivedEvent._();
  MessageReceivedEvent createEmptyInstance() => create();
  static $pb.PbList<MessageReceivedEvent> createRepeated() =>
      $pb.PbList<MessageReceivedEvent>();
  @$core.pragma('dart2js:noInline')
  static MessageReceivedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MessageReceivedEvent>(create);
  static MessageReceivedEvent? _defaultInstance;

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
  $core.List<$core.int> get messageContent => $_getN(1);
  @$pb.TagNumber(2)
  set messageContent($core.List<$core.int> v) {
    $_setBytes(1, v);
  }

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
    final $result = create();
    if (peerId != null) {
      $result.peerId = peerId;
    }
    if (messageContent != null) {
      $result.messageContent = messageContent;
    }
    return $result;
  }
  MessageSentEvent._() : super();
  factory MessageSentEvent.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory MessageSentEvent.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MessageSentEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'peerId')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'messageContent', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  MessageSentEvent clone() => MessageSentEvent()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  MessageSentEvent copyWith(void Function(MessageSentEvent) updates) =>
      super.copyWith((message) => updates(message as MessageSentEvent))
          as MessageSentEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MessageSentEvent create() => MessageSentEvent._();
  MessageSentEvent createEmptyInstance() => create();
  static $pb.PbList<MessageSentEvent> createRepeated() =>
      $pb.PbList<MessageSentEvent>();
  @$core.pragma('dart2js:noInline')
  static MessageSentEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MessageSentEvent>(create);
  static MessageSentEvent? _defaultInstance;

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
  $core.List<$core.int> get messageContent => $_getN(1);
  @$pb.TagNumber(2)
  set messageContent($core.List<$core.int> v) {
    $_setBytes(1, v);
  }

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
    final $result = create();
    if (cid != null) {
      $result.cid = cid;
    }
    if (peerId != null) {
      $result.peerId = peerId;
    }
    return $result;
  }
  BlockReceivedEvent._() : super();
  factory BlockReceivedEvent.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory BlockReceivedEvent.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BlockReceivedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'cid')
    ..aOS(2, _omitFieldNames ? '' : 'peerId')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  BlockReceivedEvent clone() => BlockReceivedEvent()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  BlockReceivedEvent copyWith(void Function(BlockReceivedEvent) updates) =>
      super.copyWith((message) => updates(message as BlockReceivedEvent))
          as BlockReceivedEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BlockReceivedEvent create() => BlockReceivedEvent._();
  BlockReceivedEvent createEmptyInstance() => create();
  static $pb.PbList<BlockReceivedEvent> createRepeated() =>
      $pb.PbList<BlockReceivedEvent>();
  @$core.pragma('dart2js:noInline')
  static BlockReceivedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BlockReceivedEvent>(create);
  static BlockReceivedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get cid => $_getSZ(0);
  @$pb.TagNumber(1)
  set cid($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasCid() => $_has(0);
  @$pb.TagNumber(1)
  void clearCid() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get peerId => $_getSZ(1);
  @$pb.TagNumber(2)
  set peerId($core.String v) {
    $_setString(1, v);
  }

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
    final $result = create();
    if (cid != null) {
      $result.cid = cid;
    }
    if (peerId != null) {
      $result.peerId = peerId;
    }
    return $result;
  }
  BlockSentEvent._() : super();
  factory BlockSentEvent.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory BlockSentEvent.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BlockSentEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'cid')
    ..aOS(2, _omitFieldNames ? '' : 'peerId')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  BlockSentEvent clone() => BlockSentEvent()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  BlockSentEvent copyWith(void Function(BlockSentEvent) updates) =>
      super.copyWith((message) => updates(message as BlockSentEvent))
          as BlockSentEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BlockSentEvent create() => BlockSentEvent._();
  BlockSentEvent createEmptyInstance() => create();
  static $pb.PbList<BlockSentEvent> createRepeated() =>
      $pb.PbList<BlockSentEvent>();
  @$core.pragma('dart2js:noInline')
  static BlockSentEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BlockSentEvent>(create);
  static BlockSentEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get cid => $_getSZ(0);
  @$pb.TagNumber(1)
  set cid($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasCid() => $_has(0);
  @$pb.TagNumber(1)
  void clearCid() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get peerId => $_getSZ(1);
  @$pb.TagNumber(2)
  set peerId($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasPeerId() => $_has(1);
  @$pb.TagNumber(2)
  void clearPeerId() => clearField(2);
}

class DHTQueryStartedEvent extends $pb.GeneratedMessage {
  factory DHTQueryStartedEvent({
    $core.String? queryType,
    $core.String? targetKey,
  }) {
    final $result = create();
    if (queryType != null) {
      $result.queryType = queryType;
    }
    if (targetKey != null) {
      $result.targetKey = targetKey;
    }
    return $result;
  }
  DHTQueryStartedEvent._() : super();
  factory DHTQueryStartedEvent.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory DHTQueryStartedEvent.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DHTQueryStartedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'queryType')
    ..aOS(2, _omitFieldNames ? '' : 'targetKey')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  DHTQueryStartedEvent clone() =>
      DHTQueryStartedEvent()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  DHTQueryStartedEvent copyWith(void Function(DHTQueryStartedEvent) updates) =>
      super.copyWith((message) => updates(message as DHTQueryStartedEvent))
          as DHTQueryStartedEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DHTQueryStartedEvent create() => DHTQueryStartedEvent._();
  DHTQueryStartedEvent createEmptyInstance() => create();
  static $pb.PbList<DHTQueryStartedEvent> createRepeated() =>
      $pb.PbList<DHTQueryStartedEvent>();
  @$core.pragma('dart2js:noInline')
  static DHTQueryStartedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DHTQueryStartedEvent>(create);
  static DHTQueryStartedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get queryType => $_getSZ(0);
  @$pb.TagNumber(1)
  set queryType($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasQueryType() => $_has(0);
  @$pb.TagNumber(1)
  void clearQueryType() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get targetKey => $_getSZ(1);
  @$pb.TagNumber(2)
  set targetKey($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasTargetKey() => $_has(1);
  @$pb.TagNumber(2)
  void clearTargetKey() => clearField(2);
}

class DHTQueryCompletedEvent extends $pb.GeneratedMessage {
  factory DHTQueryCompletedEvent({
    $core.String? queryType,
    $core.String? targetKey,
    $core.Iterable<$core.String>? results,
  }) {
    final $result = create();
    if (queryType != null) {
      $result.queryType = queryType;
    }
    if (targetKey != null) {
      $result.targetKey = targetKey;
    }
    if (results != null) {
      $result.results.addAll(results);
    }
    return $result;
  }
  DHTQueryCompletedEvent._() : super();
  factory DHTQueryCompletedEvent.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory DHTQueryCompletedEvent.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DHTQueryCompletedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'queryType')
    ..aOS(2, _omitFieldNames ? '' : 'targetKey')
    ..pPS(3, _omitFieldNames ? '' : 'results')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  DHTQueryCompletedEvent clone() =>
      DHTQueryCompletedEvent()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  DHTQueryCompletedEvent copyWith(
          void Function(DHTQueryCompletedEvent) updates) =>
      super.copyWith((message) => updates(message as DHTQueryCompletedEvent))
          as DHTQueryCompletedEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DHTQueryCompletedEvent create() => DHTQueryCompletedEvent._();
  DHTQueryCompletedEvent createEmptyInstance() => create();
  static $pb.PbList<DHTQueryCompletedEvent> createRepeated() =>
      $pb.PbList<DHTQueryCompletedEvent>();
  @$core.pragma('dart2js:noInline')
  static DHTQueryCompletedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DHTQueryCompletedEvent>(create);
  static DHTQueryCompletedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get queryType => $_getSZ(0);
  @$pb.TagNumber(1)
  set queryType($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasQueryType() => $_has(0);
  @$pb.TagNumber(1)
  void clearQueryType() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get targetKey => $_getSZ(1);
  @$pb.TagNumber(2)
  set targetKey($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasTargetKey() => $_has(1);
  @$pb.TagNumber(2)
  void clearTargetKey() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.String> get results => $_getList(2);
}

class DHTValueFoundEvent extends $pb.GeneratedMessage {
  factory DHTValueFoundEvent({
    $core.String? key,
    $core.List<$core.int>? value,
    $core.String? peerId,
  }) {
    final $result = create();
    if (key != null) {
      $result.key = key;
    }
    if (value != null) {
      $result.value = value;
    }
    if (peerId != null) {
      $result.peerId = peerId;
    }
    return $result;
  }
  DHTValueFoundEvent._() : super();
  factory DHTValueFoundEvent.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory DHTValueFoundEvent.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

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

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  DHTValueFoundEvent clone() => DHTValueFoundEvent()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  DHTValueFoundEvent copyWith(void Function(DHTValueFoundEvent) updates) =>
      super.copyWith((message) => updates(message as DHTValueFoundEvent))
          as DHTValueFoundEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DHTValueFoundEvent create() => DHTValueFoundEvent._();
  DHTValueFoundEvent createEmptyInstance() => create();
  static $pb.PbList<DHTValueFoundEvent> createRepeated() =>
      $pb.PbList<DHTValueFoundEvent>();
  @$core.pragma('dart2js:noInline')
  static DHTValueFoundEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DHTValueFoundEvent>(create);
  static DHTValueFoundEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get key => $_getSZ(0);
  @$pb.TagNumber(1)
  set key($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get value => $_getN(1);
  @$pb.TagNumber(2)
  set value($core.List<$core.int> v) {
    $_setBytes(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearValue() => clearField(2);

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
}

class DHTValueNotFoundEvent extends $pb.GeneratedMessage {
  factory DHTValueNotFoundEvent({
    $core.String? key,
  }) {
    final $result = create();
    if (key != null) {
      $result.key = key;
    }
    return $result;
  }
  DHTValueNotFoundEvent._() : super();
  factory DHTValueNotFoundEvent.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory DHTValueNotFoundEvent.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DHTValueNotFoundEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'key')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  DHTValueNotFoundEvent clone() =>
      DHTValueNotFoundEvent()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  DHTValueNotFoundEvent copyWith(
          void Function(DHTValueNotFoundEvent) updates) =>
      super.copyWith((message) => updates(message as DHTValueNotFoundEvent))
          as DHTValueNotFoundEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DHTValueNotFoundEvent create() => DHTValueNotFoundEvent._();
  DHTValueNotFoundEvent createEmptyInstance() => create();
  static $pb.PbList<DHTValueNotFoundEvent> createRepeated() =>
      $pb.PbList<DHTValueNotFoundEvent>();
  @$core.pragma('dart2js:noInline')
  static DHTValueNotFoundEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DHTValueNotFoundEvent>(create);
  static DHTValueNotFoundEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get key => $_getSZ(0);
  @$pb.TagNumber(1)
  set key($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => clearField(1);
}

class DHTValueProvidedEvent extends $pb.GeneratedMessage {
  factory DHTValueProvidedEvent({
    $core.String? key,
    $core.List<$core.int>? value,
  }) {
    final $result = create();
    if (key != null) {
      $result.key = key;
    }
    if (value != null) {
      $result.value = value;
    }
    return $result;
  }
  DHTValueProvidedEvent._() : super();
  factory DHTValueProvidedEvent.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory DHTValueProvidedEvent.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DHTValueProvidedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'key')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'value', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  DHTValueProvidedEvent clone() =>
      DHTValueProvidedEvent()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  DHTValueProvidedEvent copyWith(
          void Function(DHTValueProvidedEvent) updates) =>
      super.copyWith((message) => updates(message as DHTValueProvidedEvent))
          as DHTValueProvidedEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DHTValueProvidedEvent create() => DHTValueProvidedEvent._();
  DHTValueProvidedEvent createEmptyInstance() => create();
  static $pb.PbList<DHTValueProvidedEvent> createRepeated() =>
      $pb.PbList<DHTValueProvidedEvent>();
  @$core.pragma('dart2js:noInline')
  static DHTValueProvidedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DHTValueProvidedEvent>(create);
  static DHTValueProvidedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get key => $_getSZ(0);
  @$pb.TagNumber(1)
  set key($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get value => $_getN(1);
  @$pb.TagNumber(2)
  set value($core.List<$core.int> v) {
    $_setBytes(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearValue() => clearField(2);
}

class DHTProviderAddedEvent extends $pb.GeneratedMessage {
  factory DHTProviderAddedEvent({
    $core.String? key,
    $core.String? peerId,
  }) {
    final $result = create();
    if (key != null) {
      $result.key = key;
    }
    if (peerId != null) {
      $result.peerId = peerId;
    }
    return $result;
  }
  DHTProviderAddedEvent._() : super();
  factory DHTProviderAddedEvent.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory DHTProviderAddedEvent.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DHTProviderAddedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'key')
    ..aOS(2, _omitFieldNames ? '' : 'peerId')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  DHTProviderAddedEvent clone() =>
      DHTProviderAddedEvent()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  DHTProviderAddedEvent copyWith(
          void Function(DHTProviderAddedEvent) updates) =>
      super.copyWith((message) => updates(message as DHTProviderAddedEvent))
          as DHTProviderAddedEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DHTProviderAddedEvent create() => DHTProviderAddedEvent._();
  DHTProviderAddedEvent createEmptyInstance() => create();
  static $pb.PbList<DHTProviderAddedEvent> createRepeated() =>
      $pb.PbList<DHTProviderAddedEvent>();
  @$core.pragma('dart2js:noInline')
  static DHTProviderAddedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DHTProviderAddedEvent>(create);
  static DHTProviderAddedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get key => $_getSZ(0);
  @$pb.TagNumber(1)
  set key($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get peerId => $_getSZ(1);
  @$pb.TagNumber(2)
  set peerId($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasPeerId() => $_has(1);
  @$pb.TagNumber(2)
  void clearPeerId() => clearField(2);
}

class DHTProviderQueriedEvent extends $pb.GeneratedMessage {
  factory DHTProviderQueriedEvent({
    $core.String? key,
    $core.Iterable<$core.String>? providers,
  }) {
    final $result = create();
    if (key != null) {
      $result.key = key;
    }
    if (providers != null) {
      $result.providers.addAll(providers);
    }
    return $result;
  }
  DHTProviderQueriedEvent._() : super();
  factory DHTProviderQueriedEvent.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory DHTProviderQueriedEvent.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DHTProviderQueriedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'key')
    ..pPS(2, _omitFieldNames ? '' : 'providers')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  DHTProviderQueriedEvent clone() =>
      DHTProviderQueriedEvent()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  DHTProviderQueriedEvent copyWith(
          void Function(DHTProviderQueriedEvent) updates) =>
      super.copyWith((message) => updates(message as DHTProviderQueriedEvent))
          as DHTProviderQueriedEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DHTProviderQueriedEvent create() => DHTProviderQueriedEvent._();
  DHTProviderQueriedEvent createEmptyInstance() => create();
  static $pb.PbList<DHTProviderQueriedEvent> createRepeated() =>
      $pb.PbList<DHTProviderQueriedEvent>();
  @$core.pragma('dart2js:noInline')
  static DHTProviderQueriedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DHTProviderQueriedEvent>(create);
  static DHTProviderQueriedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get key => $_getSZ(0);
  @$pb.TagNumber(1)
  set key($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.String> get providers => $_getList(1);
}

class PubsubMessagePublishedEvent extends $pb.GeneratedMessage {
  factory PubsubMessagePublishedEvent({
    $core.String? topic,
    $core.List<$core.int>? messageContent,
  }) {
    final $result = create();
    if (topic != null) {
      $result.topic = topic;
    }
    if (messageContent != null) {
      $result.messageContent = messageContent;
    }
    return $result;
  }
  PubsubMessagePublishedEvent._() : super();
  factory PubsubMessagePublishedEvent.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory PubsubMessagePublishedEvent.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PubsubMessagePublishedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'topic')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'messageContent', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  PubsubMessagePublishedEvent clone() =>
      PubsubMessagePublishedEvent()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  PubsubMessagePublishedEvent copyWith(
          void Function(PubsubMessagePublishedEvent) updates) =>
      super.copyWith(
              (message) => updates(message as PubsubMessagePublishedEvent))
          as PubsubMessagePublishedEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PubsubMessagePublishedEvent create() =>
      PubsubMessagePublishedEvent._();
  PubsubMessagePublishedEvent createEmptyInstance() => create();
  static $pb.PbList<PubsubMessagePublishedEvent> createRepeated() =>
      $pb.PbList<PubsubMessagePublishedEvent>();
  @$core.pragma('dart2js:noInline')
  static PubsubMessagePublishedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PubsubMessagePublishedEvent>(create);
  static PubsubMessagePublishedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get topic => $_getSZ(0);
  @$pb.TagNumber(1)
  set topic($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasTopic() => $_has(0);
  @$pb.TagNumber(1)
  void clearTopic() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get messageContent => $_getN(1);
  @$pb.TagNumber(2)
  set messageContent($core.List<$core.int> v) {
    $_setBytes(1, v);
  }

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
    final $result = create();
    if (topic != null) {
      $result.topic = topic;
    }
    if (messageContent != null) {
      $result.messageContent = messageContent;
    }
    if (peerId != null) {
      $result.peerId = peerId;
    }
    return $result;
  }
  PubsubMessageReceivedEvent._() : super();
  factory PubsubMessageReceivedEvent.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory PubsubMessageReceivedEvent.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

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

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  PubsubMessageReceivedEvent clone() =>
      PubsubMessageReceivedEvent()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  PubsubMessageReceivedEvent copyWith(
          void Function(PubsubMessageReceivedEvent) updates) =>
      super.copyWith(
              (message) => updates(message as PubsubMessageReceivedEvent))
          as PubsubMessageReceivedEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PubsubMessageReceivedEvent create() => PubsubMessageReceivedEvent._();
  PubsubMessageReceivedEvent createEmptyInstance() => create();
  static $pb.PbList<PubsubMessageReceivedEvent> createRepeated() =>
      $pb.PbList<PubsubMessageReceivedEvent>();
  @$core.pragma('dart2js:noInline')
  static PubsubMessageReceivedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PubsubMessageReceivedEvent>(create);
  static PubsubMessageReceivedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get topic => $_getSZ(0);
  @$pb.TagNumber(1)
  set topic($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasTopic() => $_has(0);
  @$pb.TagNumber(1)
  void clearTopic() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get messageContent => $_getN(1);
  @$pb.TagNumber(2)
  set messageContent($core.List<$core.int> v) {
    $_setBytes(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasMessageContent() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessageContent() => clearField(2);

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
}

class PubsubSubscriptionCreatedEvent extends $pb.GeneratedMessage {
  factory PubsubSubscriptionCreatedEvent({
    $core.String? topic,
  }) {
    final $result = create();
    if (topic != null) {
      $result.topic = topic;
    }
    return $result;
  }
  PubsubSubscriptionCreatedEvent._() : super();
  factory PubsubSubscriptionCreatedEvent.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory PubsubSubscriptionCreatedEvent.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PubsubSubscriptionCreatedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'topic')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  PubsubSubscriptionCreatedEvent clone() =>
      PubsubSubscriptionCreatedEvent()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  PubsubSubscriptionCreatedEvent copyWith(
          void Function(PubsubSubscriptionCreatedEvent) updates) =>
      super.copyWith(
              (message) => updates(message as PubsubSubscriptionCreatedEvent))
          as PubsubSubscriptionCreatedEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PubsubSubscriptionCreatedEvent create() =>
      PubsubSubscriptionCreatedEvent._();
  PubsubSubscriptionCreatedEvent createEmptyInstance() => create();
  static $pb.PbList<PubsubSubscriptionCreatedEvent> createRepeated() =>
      $pb.PbList<PubsubSubscriptionCreatedEvent>();
  @$core.pragma('dart2js:noInline')
  static PubsubSubscriptionCreatedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PubsubSubscriptionCreatedEvent>(create);
  static PubsubSubscriptionCreatedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get topic => $_getSZ(0);
  @$pb.TagNumber(1)
  set topic($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasTopic() => $_has(0);
  @$pb.TagNumber(1)
  void clearTopic() => clearField(1);
}

class PubsubSubscriptionCancelledEvent extends $pb.GeneratedMessage {
  factory PubsubSubscriptionCancelledEvent({
    $core.String? topic,
  }) {
    final $result = create();
    if (topic != null) {
      $result.topic = topic;
    }
    return $result;
  }
  PubsubSubscriptionCancelledEvent._() : super();
  factory PubsubSubscriptionCancelledEvent.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory PubsubSubscriptionCancelledEvent.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PubsubSubscriptionCancelledEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'topic')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  PubsubSubscriptionCancelledEvent clone() =>
      PubsubSubscriptionCancelledEvent()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  PubsubSubscriptionCancelledEvent copyWith(
          void Function(PubsubSubscriptionCancelledEvent) updates) =>
      super.copyWith(
              (message) => updates(message as PubsubSubscriptionCancelledEvent))
          as PubsubSubscriptionCancelledEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PubsubSubscriptionCancelledEvent create() =>
      PubsubSubscriptionCancelledEvent._();
  PubsubSubscriptionCancelledEvent createEmptyInstance() => create();
  static $pb.PbList<PubsubSubscriptionCancelledEvent> createRepeated() =>
      $pb.PbList<PubsubSubscriptionCancelledEvent>();
  @$core.pragma('dart2js:noInline')
  static PubsubSubscriptionCancelledEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PubsubSubscriptionCancelledEvent>(
          create);
  static PubsubSubscriptionCancelledEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get topic => $_getSZ(0);
  @$pb.TagNumber(1)
  set topic($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasTopic() => $_has(0);
  @$pb.TagNumber(1)
  void clearTopic() => clearField(1);
}

class CircuitRelayCreatedEvent extends $pb.GeneratedMessage {
  factory CircuitRelayCreatedEvent({
    $core.String? relayAddress,
  }) {
    final $result = create();
    if (relayAddress != null) {
      $result.relayAddress = relayAddress;
    }
    return $result;
  }
  CircuitRelayCreatedEvent._() : super();
  factory CircuitRelayCreatedEvent.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory CircuitRelayCreatedEvent.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CircuitRelayCreatedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'relayAddress')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  CircuitRelayCreatedEvent clone() =>
      CircuitRelayCreatedEvent()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  CircuitRelayCreatedEvent copyWith(
          void Function(CircuitRelayCreatedEvent) updates) =>
      super.copyWith((message) => updates(message as CircuitRelayCreatedEvent))
          as CircuitRelayCreatedEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CircuitRelayCreatedEvent create() => CircuitRelayCreatedEvent._();
  CircuitRelayCreatedEvent createEmptyInstance() => create();
  static $pb.PbList<CircuitRelayCreatedEvent> createRepeated() =>
      $pb.PbList<CircuitRelayCreatedEvent>();
  @$core.pragma('dart2js:noInline')
  static CircuitRelayCreatedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CircuitRelayCreatedEvent>(create);
  static CircuitRelayCreatedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get relayAddress => $_getSZ(0);
  @$pb.TagNumber(1)
  set relayAddress($core.String v) {
    $_setString(0, v);
  }

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
    final $result = create();
    if (relayAddress != null) {
      $result.relayAddress = relayAddress;
    }
    if (reason != null) {
      $result.reason = reason;
    }
    return $result;
  }
  CircuitRelayClosedEvent._() : super();
  factory CircuitRelayClosedEvent.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory CircuitRelayClosedEvent.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CircuitRelayClosedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'relayAddress')
    ..aOS(2, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  CircuitRelayClosedEvent clone() =>
      CircuitRelayClosedEvent()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  CircuitRelayClosedEvent copyWith(
          void Function(CircuitRelayClosedEvent) updates) =>
      super.copyWith((message) => updates(message as CircuitRelayClosedEvent))
          as CircuitRelayClosedEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CircuitRelayClosedEvent create() => CircuitRelayClosedEvent._();
  CircuitRelayClosedEvent createEmptyInstance() => create();
  static $pb.PbList<CircuitRelayClosedEvent> createRepeated() =>
      $pb.PbList<CircuitRelayClosedEvent>();
  @$core.pragma('dart2js:noInline')
  static CircuitRelayClosedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CircuitRelayClosedEvent>(create);
  static CircuitRelayClosedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get relayAddress => $_getSZ(0);
  @$pb.TagNumber(1)
  set relayAddress($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasRelayAddress() => $_has(0);
  @$pb.TagNumber(1)
  void clearRelayAddress() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get reason => $_getSZ(1);
  @$pb.TagNumber(2)
  set reason($core.String v) {
    $_setString(1, v);
  }

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
    final $result = create();
    if (relayAddress != null) {
      $result.relayAddress = relayAddress;
    }
    if (dataSize != null) {
      $result.dataSize = dataSize;
    }
    return $result;
  }
  CircuitRelayTrafficEvent._() : super();
  factory CircuitRelayTrafficEvent.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory CircuitRelayTrafficEvent.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CircuitRelayTrafficEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'relayAddress')
    ..aInt64(2, _omitFieldNames ? '' : 'dataSize')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  CircuitRelayTrafficEvent clone() =>
      CircuitRelayTrafficEvent()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  CircuitRelayTrafficEvent copyWith(
          void Function(CircuitRelayTrafficEvent) updates) =>
      super.copyWith((message) => updates(message as CircuitRelayTrafficEvent))
          as CircuitRelayTrafficEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CircuitRelayTrafficEvent create() => CircuitRelayTrafficEvent._();
  CircuitRelayTrafficEvent createEmptyInstance() => create();
  static $pb.PbList<CircuitRelayTrafficEvent> createRepeated() =>
      $pb.PbList<CircuitRelayTrafficEvent>();
  @$core.pragma('dart2js:noInline')
  static CircuitRelayTrafficEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CircuitRelayTrafficEvent>(create);
  static CircuitRelayTrafficEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get relayAddress => $_getSZ(0);
  @$pb.TagNumber(1)
  set relayAddress($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasRelayAddress() => $_has(0);
  @$pb.TagNumber(1)
  void clearRelayAddress() => clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get dataSize => $_getI64(1);
  @$pb.TagNumber(2)
  set dataSize($fixnum.Int64 v) {
    $_setInt64(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasDataSize() => $_has(1);
  @$pb.TagNumber(2)
  void clearDataSize() => clearField(2);
}

class CircuitRelayDataReceivedEvent extends $pb.GeneratedMessage {
  factory CircuitRelayDataReceivedEvent({
    $core.String? relayAddress,
    $fixnum.Int64? dataSize,
  }) {
    final $result = create();
    if (relayAddress != null) {
      $result.relayAddress = relayAddress;
    }
    if (dataSize != null) {
      $result.dataSize = dataSize;
    }
    return $result;
  }
  CircuitRelayDataReceivedEvent._() : super();
  factory CircuitRelayDataReceivedEvent.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory CircuitRelayDataReceivedEvent.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CircuitRelayDataReceivedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'relayAddress')
    ..aInt64(2, _omitFieldNames ? '' : 'dataSize')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  CircuitRelayDataReceivedEvent clone() =>
      CircuitRelayDataReceivedEvent()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  CircuitRelayDataReceivedEvent copyWith(
          void Function(CircuitRelayDataReceivedEvent) updates) =>
      super.copyWith(
              (message) => updates(message as CircuitRelayDataReceivedEvent))
          as CircuitRelayDataReceivedEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CircuitRelayDataReceivedEvent create() =>
      CircuitRelayDataReceivedEvent._();
  CircuitRelayDataReceivedEvent createEmptyInstance() => create();
  static $pb.PbList<CircuitRelayDataReceivedEvent> createRepeated() =>
      $pb.PbList<CircuitRelayDataReceivedEvent>();
  @$core.pragma('dart2js:noInline')
  static CircuitRelayDataReceivedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CircuitRelayDataReceivedEvent>(create);
  static CircuitRelayDataReceivedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get relayAddress => $_getSZ(0);
  @$pb.TagNumber(1)
  set relayAddress($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasRelayAddress() => $_has(0);
  @$pb.TagNumber(1)
  void clearRelayAddress() => clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get dataSize => $_getI64(1);
  @$pb.TagNumber(2)
  set dataSize($fixnum.Int64 v) {
    $_setInt64(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasDataSize() => $_has(1);
  @$pb.TagNumber(2)
  void clearDataSize() => clearField(2);
}

class CircuitRelayDataSentEvent extends $pb.GeneratedMessage {
  factory CircuitRelayDataSentEvent({
    $core.String? relayAddress,
    $fixnum.Int64? dataSize,
  }) {
    final $result = create();
    if (relayAddress != null) {
      $result.relayAddress = relayAddress;
    }
    if (dataSize != null) {
      $result.dataSize = dataSize;
    }
    return $result;
  }
  CircuitRelayDataSentEvent._() : super();
  factory CircuitRelayDataSentEvent.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory CircuitRelayDataSentEvent.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CircuitRelayDataSentEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'relayAddress')
    ..aInt64(2, _omitFieldNames ? '' : 'dataSize')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  CircuitRelayDataSentEvent clone() =>
      CircuitRelayDataSentEvent()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  CircuitRelayDataSentEvent copyWith(
          void Function(CircuitRelayDataSentEvent) updates) =>
      super.copyWith((message) => updates(message as CircuitRelayDataSentEvent))
          as CircuitRelayDataSentEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CircuitRelayDataSentEvent create() => CircuitRelayDataSentEvent._();
  CircuitRelayDataSentEvent createEmptyInstance() => create();
  static $pb.PbList<CircuitRelayDataSentEvent> createRepeated() =>
      $pb.PbList<CircuitRelayDataSentEvent>();
  @$core.pragma('dart2js:noInline')
  static CircuitRelayDataSentEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CircuitRelayDataSentEvent>(create);
  static CircuitRelayDataSentEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get relayAddress => $_getSZ(0);
  @$pb.TagNumber(1)
  set relayAddress($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasRelayAddress() => $_has(0);
  @$pb.TagNumber(1)
  void clearRelayAddress() => clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get dataSize => $_getI64(1);
  @$pb.TagNumber(2)
  set dataSize($fixnum.Int64 v) {
    $_setInt64(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasDataSize() => $_has(1);
  @$pb.TagNumber(2)
  void clearDataSize() => clearField(2);
}

class CircuitRelayFailedEvent extends $pb.GeneratedMessage {
  factory CircuitRelayFailedEvent({
    $core.String? relayAddress,
    $core.String? reason,
  }) {
    final $result = create();
    if (relayAddress != null) {
      $result.relayAddress = relayAddress;
    }
    if (reason != null) {
      $result.reason = reason;
    }
    return $result;
  }
  CircuitRelayFailedEvent._() : super();
  factory CircuitRelayFailedEvent.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory CircuitRelayFailedEvent.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CircuitRelayFailedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'relayAddress')
    ..aOS(2, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  CircuitRelayFailedEvent clone() =>
      CircuitRelayFailedEvent()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  CircuitRelayFailedEvent copyWith(
          void Function(CircuitRelayFailedEvent) updates) =>
      super.copyWith((message) => updates(message as CircuitRelayFailedEvent))
          as CircuitRelayFailedEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CircuitRelayFailedEvent create() => CircuitRelayFailedEvent._();
  CircuitRelayFailedEvent createEmptyInstance() => create();
  static $pb.PbList<CircuitRelayFailedEvent> createRepeated() =>
      $pb.PbList<CircuitRelayFailedEvent>();
  @$core.pragma('dart2js:noInline')
  static CircuitRelayFailedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CircuitRelayFailedEvent>(create);
  static CircuitRelayFailedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get relayAddress => $_getSZ(0);
  @$pb.TagNumber(1)
  set relayAddress($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasRelayAddress() => $_has(0);
  @$pb.TagNumber(1)
  void clearRelayAddress() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get reason => $_getSZ(1);
  @$pb.TagNumber(2)
  set reason($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasReason() => $_has(1);
  @$pb.TagNumber(2)
  void clearReason() => clearField(2);
}

class StreamStartedEvent extends $pb.GeneratedMessage {
  factory StreamStartedEvent({
    $core.String? streamId,
    $core.String? peerId,
  }) {
    final $result = create();
    if (streamId != null) {
      $result.streamId = streamId;
    }
    if (peerId != null) {
      $result.peerId = peerId;
    }
    return $result;
  }
  StreamStartedEvent._() : super();
  factory StreamStartedEvent.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory StreamStartedEvent.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StreamStartedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'streamId')
    ..aOS(2, _omitFieldNames ? '' : 'peerId')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  StreamStartedEvent clone() => StreamStartedEvent()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  StreamStartedEvent copyWith(void Function(StreamStartedEvent) updates) =>
      super.copyWith((message) => updates(message as StreamStartedEvent))
          as StreamStartedEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StreamStartedEvent create() => StreamStartedEvent._();
  StreamStartedEvent createEmptyInstance() => create();
  static $pb.PbList<StreamStartedEvent> createRepeated() =>
      $pb.PbList<StreamStartedEvent>();
  @$core.pragma('dart2js:noInline')
  static StreamStartedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StreamStartedEvent>(create);
  static StreamStartedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get streamId => $_getSZ(0);
  @$pb.TagNumber(1)
  set streamId($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasStreamId() => $_has(0);
  @$pb.TagNumber(1)
  void clearStreamId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get peerId => $_getSZ(1);
  @$pb.TagNumber(2)
  set peerId($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasPeerId() => $_has(1);
  @$pb.TagNumber(2)
  void clearPeerId() => clearField(2);
}

class StreamEndedEvent extends $pb.GeneratedMessage {
  factory StreamEndedEvent({
    $core.String? streamId,
    $core.String? peerId,
    $core.String? reason,
  }) {
    final $result = create();
    if (streamId != null) {
      $result.streamId = streamId;
    }
    if (peerId != null) {
      $result.peerId = peerId;
    }
    if (reason != null) {
      $result.reason = reason;
    }
    return $result;
  }
  StreamEndedEvent._() : super();
  factory StreamEndedEvent.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory StreamEndedEvent.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StreamEndedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'streamId')
    ..aOS(2, _omitFieldNames ? '' : 'peerId')
    ..aOS(3, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  StreamEndedEvent clone() => StreamEndedEvent()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  StreamEndedEvent copyWith(void Function(StreamEndedEvent) updates) =>
      super.copyWith((message) => updates(message as StreamEndedEvent))
          as StreamEndedEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StreamEndedEvent create() => StreamEndedEvent._();
  StreamEndedEvent createEmptyInstance() => create();
  static $pb.PbList<StreamEndedEvent> createRepeated() =>
      $pb.PbList<StreamEndedEvent>();
  @$core.pragma('dart2js:noInline')
  static StreamEndedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StreamEndedEvent>(create);
  static StreamEndedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get streamId => $_getSZ(0);
  @$pb.TagNumber(1)
  set streamId($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasStreamId() => $_has(0);
  @$pb.TagNumber(1)
  void clearStreamId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get peerId => $_getSZ(1);
  @$pb.TagNumber(2)
  set peerId($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasPeerId() => $_has(1);
  @$pb.TagNumber(2)
  void clearPeerId() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get reason => $_getSZ(2);
  @$pb.TagNumber(3)
  set reason($core.String v) {
    $_setString(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasReason() => $_has(2);
  @$pb.TagNumber(3)
  void clearReason() => clearField(3);
}

class PeerDiscoveredEvent extends $pb.GeneratedMessage {
  factory PeerDiscoveredEvent({
    $core.String? peerId,
  }) {
    final $result = create();
    if (peerId != null) {
      $result.peerId = peerId;
    }
    return $result;
  }
  PeerDiscoveredEvent._() : super();
  factory PeerDiscoveredEvent.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory PeerDiscoveredEvent.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PeerDiscoveredEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'peerId')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  PeerDiscoveredEvent clone() => PeerDiscoveredEvent()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  PeerDiscoveredEvent copyWith(void Function(PeerDiscoveredEvent) updates) =>
      super.copyWith((message) => updates(message as PeerDiscoveredEvent))
          as PeerDiscoveredEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PeerDiscoveredEvent create() => PeerDiscoveredEvent._();
  PeerDiscoveredEvent createEmptyInstance() => create();
  static $pb.PbList<PeerDiscoveredEvent> createRepeated() =>
      $pb.PbList<PeerDiscoveredEvent>();
  @$core.pragma('dart2js:noInline')
  static PeerDiscoveredEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PeerDiscoveredEvent>(create);
  static PeerDiscoveredEvent? _defaultInstance;

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
}

class NodeStartedEvent extends $pb.GeneratedMessage {
  factory NodeStartedEvent() => create();
  NodeStartedEvent._() : super();
  factory NodeStartedEvent.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory NodeStartedEvent.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NodeStartedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  NodeStartedEvent clone() => NodeStartedEvent()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  NodeStartedEvent copyWith(void Function(NodeStartedEvent) updates) =>
      super.copyWith((message) => updates(message as NodeStartedEvent))
          as NodeStartedEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NodeStartedEvent create() => NodeStartedEvent._();
  NodeStartedEvent createEmptyInstance() => create();
  static $pb.PbList<NodeStartedEvent> createRepeated() =>
      $pb.PbList<NodeStartedEvent>();
  @$core.pragma('dart2js:noInline')
  static NodeStartedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NodeStartedEvent>(create);
  static NodeStartedEvent? _defaultInstance;
}

class NodeStoppedEvent extends $pb.GeneratedMessage {
  factory NodeStoppedEvent() => create();
  NodeStoppedEvent._() : super();
  factory NodeStoppedEvent.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory NodeStoppedEvent.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NodeStoppedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  NodeStoppedEvent clone() => NodeStoppedEvent()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  NodeStoppedEvent copyWith(void Function(NodeStoppedEvent) updates) =>
      super.copyWith((message) => updates(message as NodeStoppedEvent))
          as NodeStoppedEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NodeStoppedEvent create() => NodeStoppedEvent._();
  NodeStoppedEvent createEmptyInstance() => create();
  static $pb.PbList<NodeStoppedEvent> createRepeated() =>
      $pb.PbList<NodeStoppedEvent>();
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
    final $result = create();
    if (errorType != null) {
      $result.errorType = errorType;
    }
    if (message != null) {
      $result.message = message;
    }
    if (stackTrace != null) {
      $result.stackTrace = stackTrace;
    }
    if (source != null) {
      $result.source = source;
    }
    return $result;
  }
  NodeErrorEvent._() : super();
  factory NodeErrorEvent.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory NodeErrorEvent.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NodeErrorEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..e<NodeErrorEvent_ErrorType>(
        1, _omitFieldNames ? '' : 'errorType', $pb.PbFieldType.OE,
        defaultOrMaker: NodeErrorEvent_ErrorType.UNKNOWN,
        valueOf: NodeErrorEvent_ErrorType.valueOf,
        enumValues: NodeErrorEvent_ErrorType.values)
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..aOS(3, _omitFieldNames ? '' : 'stackTrace')
    ..aOS(4, _omitFieldNames ? '' : 'source')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  NodeErrorEvent clone() => NodeErrorEvent()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  NodeErrorEvent copyWith(void Function(NodeErrorEvent) updates) =>
      super.copyWith((message) => updates(message as NodeErrorEvent))
          as NodeErrorEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NodeErrorEvent create() => NodeErrorEvent._();
  NodeErrorEvent createEmptyInstance() => create();
  static $pb.PbList<NodeErrorEvent> createRepeated() =>
      $pb.PbList<NodeErrorEvent>();
  @$core.pragma('dart2js:noInline')
  static NodeErrorEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NodeErrorEvent>(create);
  static NodeErrorEvent? _defaultInstance;

  @$pb.TagNumber(1)
  NodeErrorEvent_ErrorType get errorType => $_getN(0);
  @$pb.TagNumber(1)
  set errorType(NodeErrorEvent_ErrorType v) {
    setField(1, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasErrorType() => $_has(0);
  @$pb.TagNumber(1)
  void clearErrorType() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get stackTrace => $_getSZ(2);
  @$pb.TagNumber(3)
  set stackTrace($core.String v) {
    $_setString(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasStackTrace() => $_has(2);
  @$pb.TagNumber(3)
  void clearStackTrace() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get source => $_getSZ(3);
  @$pb.TagNumber(4)
  set source($core.String v) {
    $_setString(3, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasSource() => $_has(3);
  @$pb.TagNumber(4)
  void clearSource() => clearField(4);
}

class NetworkStatusChangedEvent extends $pb.GeneratedMessage {
  factory NetworkStatusChangedEvent({
    NetworkStatusChangedEvent_ChangeType? changeType,
  }) {
    final $result = create();
    if (changeType != null) {
      $result.changeType = changeType;
    }
    return $result;
  }
  NetworkStatusChangedEvent._() : super();
  factory NetworkStatusChangedEvent.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory NetworkStatusChangedEvent.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NetworkStatusChangedEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..e<NetworkStatusChangedEvent_ChangeType>(
        1, _omitFieldNames ? '' : 'changeType', $pb.PbFieldType.OE,
        defaultOrMaker: NetworkStatusChangedEvent_ChangeType.UNKNOWN,
        valueOf: NetworkStatusChangedEvent_ChangeType.valueOf,
        enumValues: NetworkStatusChangedEvent_ChangeType.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  NetworkStatusChangedEvent clone() =>
      NetworkStatusChangedEvent()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  NetworkStatusChangedEvent copyWith(
          void Function(NetworkStatusChangedEvent) updates) =>
      super.copyWith((message) => updates(message as NetworkStatusChangedEvent))
          as NetworkStatusChangedEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NetworkStatusChangedEvent create() => NetworkStatusChangedEvent._();
  NetworkStatusChangedEvent createEmptyInstance() => create();
  static $pb.PbList<NetworkStatusChangedEvent> createRepeated() =>
      $pb.PbList<NetworkStatusChangedEvent>();
  @$core.pragma('dart2js:noInline')
  static NetworkStatusChangedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NetworkStatusChangedEvent>(create);
  static NetworkStatusChangedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  NetworkStatusChangedEvent_ChangeType get changeType => $_getN(0);
  @$pb.TagNumber(1)
  set changeType(NetworkStatusChangedEvent_ChangeType v) {
    setField(1, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasChangeType() => $_has(0);
  @$pb.TagNumber(1)
  void clearChangeType() => clearField(1);
}

class ResourceLimitExceededEvent extends $pb.GeneratedMessage {
  factory ResourceLimitExceededEvent({
    $core.String? resourceType,
    $core.String? message,
  }) {
    final $result = create();
    if (resourceType != null) {
      $result.resourceType = resourceType;
    }
    if (message != null) {
      $result.message = message;
    }
    return $result;
  }
  ResourceLimitExceededEvent._() : super();
  factory ResourceLimitExceededEvent.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory ResourceLimitExceededEvent.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ResourceLimitExceededEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'resourceType')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  ResourceLimitExceededEvent clone() =>
      ResourceLimitExceededEvent()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  ResourceLimitExceededEvent copyWith(
          void Function(ResourceLimitExceededEvent) updates) =>
      super.copyWith(
              (message) => updates(message as ResourceLimitExceededEvent))
          as ResourceLimitExceededEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ResourceLimitExceededEvent create() => ResourceLimitExceededEvent._();
  ResourceLimitExceededEvent createEmptyInstance() => create();
  static $pb.PbList<ResourceLimitExceededEvent> createRepeated() =>
      $pb.PbList<ResourceLimitExceededEvent>();
  @$core.pragma('dart2js:noInline')
  static ResourceLimitExceededEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ResourceLimitExceededEvent>(create);
  static ResourceLimitExceededEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get resourceType => $_getSZ(0);
  @$pb.TagNumber(1)
  set resourceType($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasResourceType() => $_has(0);
  @$pb.TagNumber(1)
  void clearResourceType() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => clearField(2);
}

class SystemAlertEvent extends $pb.GeneratedMessage {
  factory SystemAlertEvent({
    $core.String? alertType,
    $core.String? message,
  }) {
    final $result = create();
    if (alertType != null) {
      $result.alertType = alertType;
    }
    if (message != null) {
      $result.message = message;
    }
    return $result;
  }
  SystemAlertEvent._() : super();
  factory SystemAlertEvent.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory SystemAlertEvent.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SystemAlertEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.ipfs_node'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'alertType')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  SystemAlertEvent clone() => SystemAlertEvent()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  SystemAlertEvent copyWith(void Function(SystemAlertEvent) updates) =>
      super.copyWith((message) => updates(message as SystemAlertEvent))
          as SystemAlertEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SystemAlertEvent create() => SystemAlertEvent._();
  SystemAlertEvent createEmptyInstance() => create();
  static $pb.PbList<SystemAlertEvent> createRepeated() =>
      $pb.PbList<SystemAlertEvent>();
  @$core.pragma('dart2js:noInline')
  static SystemAlertEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SystemAlertEvent>(create);
  static SystemAlertEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get alertType => $_getSZ(0);
  @$pb.TagNumber(1)
  set alertType($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasAlertType() => $_has(0);
  @$pb.TagNumber(1)
  void clearAlertType() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => clearField(2);
}

const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
