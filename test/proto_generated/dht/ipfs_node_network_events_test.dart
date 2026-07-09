// Auto-generated proto coverage tests. Do not hand-edit.

import 'package:test/test.dart';
import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:dart_ipfs/src/proto/generated/dht/ipfs_node_network_events.pbenum.dart';
import 'package:dart_ipfs/src/proto/generated/dht/ipfs_node_network_events.pb.dart';

void main() {
  group('NetworkEvent', () {
    test('round-trips and accessors work', () {
      final original = NetworkEvent(peerConnected: PeerConnectedEvent.create(), peerDisconnected: PeerDisconnectedEvent.create(), connectionAttempted: ConnectionAttemptedEvent.create(), connectionFailed: ConnectionFailedEvent.create(), messageReceived: MessageReceivedEvent.create(), messageSent: MessageSentEvent.create(), blockReceived: BlockReceivedEvent.create(), blockSent: BlockSentEvent.create(), dhtQueryStarted: DHTQueryStartedEvent.create(), dhtQueryCompleted: DHTQueryCompletedEvent.create(), dhtValueFound: DHTValueFoundEvent.create(), dhtValueProvided: DHTValueProvidedEvent.create(), dhtValueNotFound: DHTValueNotFoundEvent.create(), pubsubMessagePublished: PubsubMessagePublishedEvent.create(), pubsubMessageReceived: PubsubMessageReceivedEvent.create(), pubsubSubscriptionCreated: PubsubSubscriptionCreatedEvent.create(), pubsubSubscriptionCancelled: PubsubSubscriptionCancelledEvent.create(), circuitRelayCreated: CircuitRelayCreatedEvent.create(), circuitRelayClosed: CircuitRelayClosedEvent.create(), circuitRelayTraffic: CircuitRelayTrafficEvent.create(), circuitRelayFailed: CircuitRelayFailedEvent.create(), nodeStarted: NodeStartedEvent.create(), nodeStopped: NodeStoppedEvent.create(), error: NodeErrorEvent.create(), networkChanged: NetworkStatusChangedEvent.create(), dhtProviderAdded: DHTProviderAddedEvent.create(), dhtProviderQueried: DHTProviderQueriedEvent.create(), streamStarted: StreamStartedEvent.create(), streamEnded: StreamEndedEvent.create(), peerDiscovered: PeerDiscoveredEvent.create(), circuitRelayDataReceived: CircuitRelayDataReceivedEvent.create(), circuitRelayDataSent: CircuitRelayDataSentEvent.create(), resourceLimitExceeded: ResourceLimitExceededEvent.create(), systemAlert: SystemAlertEvent.create());
      original.peerConnected;
      original.peerDisconnected;
      original.connectionAttempted;
      original.connectionFailed;
      original.messageReceived;
      original.messageSent;
      original.blockReceived;
      original.blockSent;
      original.dhtQueryStarted;
      original.dhtQueryCompleted;
      original.dhtValueFound;
      original.dhtValueProvided;
      original.dhtValueNotFound;
      original.pubsubMessagePublished;
      original.pubsubMessageReceived;
      original.pubsubSubscriptionCreated;
      original.pubsubSubscriptionCancelled;
      original.circuitRelayCreated;
      original.circuitRelayClosed;
      original.circuitRelayTraffic;
      original.circuitRelayFailed;
      original.nodeStarted;
      original.nodeStopped;
      original.error;
      original.networkChanged;
      original.dhtProviderAdded;
      original.dhtProviderQueried;
      original.streamStarted;
      original.streamEnded;
      original.peerDiscovered;
      original.circuitRelayDataReceived;
      original.circuitRelayDataSent;
      original.resourceLimitExceeded;
      original.systemAlert;
      original.hasPeerConnected();
      original.clearPeerConnected();
      original.hasPeerDisconnected();
      original.clearPeerDisconnected();
      original.hasConnectionAttempted();
      original.clearConnectionAttempted();
      original.hasConnectionFailed();
      original.clearConnectionFailed();
      original.hasMessageReceived();
      original.clearMessageReceived();
      original.hasMessageSent();
      original.clearMessageSent();
      original.hasBlockReceived();
      original.clearBlockReceived();
      original.hasBlockSent();
      original.clearBlockSent();
      original.hasDhtQueryStarted();
      original.clearDhtQueryStarted();
      original.hasDhtQueryCompleted();
      original.clearDhtQueryCompleted();
      original.hasDhtValueFound();
      original.clearDhtValueFound();
      original.hasDhtValueProvided();
      original.clearDhtValueProvided();
      original.hasDhtValueNotFound();
      original.clearDhtValueNotFound();
      original.hasPubsubMessagePublished();
      original.clearPubsubMessagePublished();
      original.hasPubsubMessageReceived();
      original.clearPubsubMessageReceived();
      original.hasPubsubSubscriptionCreated();
      original.clearPubsubSubscriptionCreated();
      original.hasPubsubSubscriptionCancelled();
      original.clearPubsubSubscriptionCancelled();
      original.hasCircuitRelayCreated();
      original.clearCircuitRelayCreated();
      original.hasCircuitRelayClosed();
      original.clearCircuitRelayClosed();
      original.hasCircuitRelayTraffic();
      original.clearCircuitRelayTraffic();
      original.hasCircuitRelayFailed();
      original.clearCircuitRelayFailed();
      original.hasNodeStarted();
      original.clearNodeStarted();
      original.hasNodeStopped();
      original.clearNodeStopped();
      original.hasError();
      original.clearError();
      original.hasNetworkChanged();
      original.clearNetworkChanged();
      original.hasDhtProviderAdded();
      original.clearDhtProviderAdded();
      original.hasDhtProviderQueried();
      original.clearDhtProviderQueried();
      original.hasStreamStarted();
      original.clearStreamStarted();
      original.hasStreamEnded();
      original.clearStreamEnded();
      original.hasPeerDiscovered();
      original.clearPeerDiscovered();
      original.hasCircuitRelayDataReceived();
      original.clearCircuitRelayDataReceived();
      original.hasCircuitRelayDataSent();
      original.clearCircuitRelayDataSent();
      original.hasResourceLimitExceeded();
      original.clearResourceLimitExceeded();
      original.hasSystemAlert();
      original.clearSystemAlert();
      original.ensureConnectionFailed();
      original.ensureDhtValueFound();
      original.ensureCircuitRelayDataReceived();
      original.ensureCircuitRelayFailed();
      original.ensureDhtValueProvided();
      original.ensureResourceLimitExceeded();
      original.ensureBlockSent();
      original.ensureCircuitRelayClosed();
      original.ensureMessageSent();
      original.ensurePeerConnected();
      original.ensureCircuitRelayTraffic();
      original.ensureError();
      original.ensurePeerDiscovered();
      original.ensurePubsubSubscriptionCreated();
      original.ensurePubsubMessagePublished();
      original.ensureNodeStarted();
      original.ensureBlockReceived();
      original.ensureConnectionAttempted();
      original.ensureMessageReceived();
      original.ensureDhtQueryStarted();
      original.ensurePubsubMessageReceived();
      original.ensureStreamEnded();
      original.ensureStreamStarted();
      original.ensureCircuitRelayCreated();
      original.ensureDhtProviderQueried();
      original.ensureDhtProviderAdded();
      original.ensureNetworkChanged();
      original.ensurePubsubSubscriptionCancelled();
      original.ensureCircuitRelayDataSent();
      original.ensurePeerDisconnected();
      original.ensureDhtValueNotFound();
      original.ensureNodeStopped();
      original.ensureDhtQueryCompleted();
      original.ensureSystemAlert();
      expect(original.whichEvent(), isNotNull);
      expect(NetworkEvent.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = NetworkEvent.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(NetworkEvent.fromJson(json), isNotNull);
    });
  });

  group('PeerConnectedEvent', () {
    test('round-trips and accessors work', () {
      final original = PeerConnectedEvent(peerId: 'a', multiaddress: 'a');
      expect(original.peerId, 'a');
      expect(original.multiaddress, 'a');
      original.hasPeerId();
      original.clearPeerId();
      original.hasMultiaddress();
      original.clearMultiaddress();
      expect(PeerConnectedEvent.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = PeerConnectedEvent.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(PeerConnectedEvent.fromJson(json), isNotNull);
    });
  });

  group('PeerDisconnectedEvent', () {
    test('round-trips and accessors work', () {
      final original = PeerDisconnectedEvent(peerId: 'a', reason: 'a');
      expect(original.peerId, 'a');
      expect(original.reason, 'a');
      original.hasPeerId();
      original.clearPeerId();
      original.hasReason();
      original.clearReason();
      expect(PeerDisconnectedEvent.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = PeerDisconnectedEvent.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(PeerDisconnectedEvent.fromJson(json), isNotNull);
    });
  });

  group('ConnectionAttemptedEvent', () {
    test('round-trips and accessors work', () {
      final original = ConnectionAttemptedEvent(peerId: 'a', success: true);
      expect(original.peerId, 'a');
      expect(original.success, true);
      original.hasPeerId();
      original.clearPeerId();
      original.hasSuccess();
      original.clearSuccess();
      expect(ConnectionAttemptedEvent.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = ConnectionAttemptedEvent.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(ConnectionAttemptedEvent.fromJson(json), isNotNull);
    });
  });

  group('ConnectionFailedEvent', () {
    test('round-trips and accessors work', () {
      final original = ConnectionFailedEvent(peerId: 'a', reason: 'a');
      expect(original.peerId, 'a');
      expect(original.reason, 'a');
      original.hasPeerId();
      original.clearPeerId();
      original.hasReason();
      original.clearReason();
      expect(ConnectionFailedEvent.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = ConnectionFailedEvent.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(ConnectionFailedEvent.fromJson(json), isNotNull);
    });
  });

  group('MessageReceivedEvent', () {
    test('round-trips and accessors work', () {
      final original = MessageReceivedEvent(peerId: 'a', messageContent: const [0, 1, 2]);
      expect(original.peerId, 'a');
      expect(original.messageContent, const [0, 1, 2]);
      original.hasPeerId();
      original.clearPeerId();
      original.hasMessageContent();
      original.clearMessageContent();
      expect(MessageReceivedEvent.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = MessageReceivedEvent.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(MessageReceivedEvent.fromJson(json), isNotNull);
    });
  });

  group('MessageSentEvent', () {
    test('round-trips and accessors work', () {
      final original = MessageSentEvent(peerId: 'a', messageContent: const [0, 1, 2]);
      expect(original.peerId, 'a');
      expect(original.messageContent, const [0, 1, 2]);
      original.hasPeerId();
      original.clearPeerId();
      original.hasMessageContent();
      original.clearMessageContent();
      expect(MessageSentEvent.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = MessageSentEvent.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(MessageSentEvent.fromJson(json), isNotNull);
    });
  });

  group('BlockReceivedEvent', () {
    test('round-trips and accessors work', () {
      final original = BlockReceivedEvent(cid: 'a', peerId: 'a');
      expect(original.cid, 'a');
      expect(original.peerId, 'a');
      original.hasCid();
      original.clearCid();
      original.hasPeerId();
      original.clearPeerId();
      expect(BlockReceivedEvent.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = BlockReceivedEvent.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(BlockReceivedEvent.fromJson(json), isNotNull);
    });
  });

  group('BlockSentEvent', () {
    test('round-trips and accessors work', () {
      final original = BlockSentEvent(cid: 'a', peerId: 'a');
      expect(original.cid, 'a');
      expect(original.peerId, 'a');
      original.hasCid();
      original.clearCid();
      original.hasPeerId();
      original.clearPeerId();
      expect(BlockSentEvent.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = BlockSentEvent.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(BlockSentEvent.fromJson(json), isNotNull);
    });
  });

  group('DHTQueryStartedEvent', () {
    test('round-trips and accessors work', () {
      final original = DHTQueryStartedEvent(queryType: 'a', targetKey: 'a');
      expect(original.queryType, 'a');
      expect(original.targetKey, 'a');
      original.hasQueryType();
      original.clearQueryType();
      original.hasTargetKey();
      original.clearTargetKey();
      expect(DHTQueryStartedEvent.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = DHTQueryStartedEvent.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(DHTQueryStartedEvent.fromJson(json), isNotNull);
    });
  });

  group('DHTQueryCompletedEvent', () {
    test('round-trips and accessors work', () {
      final original = DHTQueryCompletedEvent(queryType: 'a', targetKey: 'a', results: ['a']);
      expect(original.queryType, 'a');
      expect(original.targetKey, 'a');
      expect(original.results, ['a']);
      original.hasQueryType();
      original.clearQueryType();
      original.hasTargetKey();
      original.clearTargetKey();
      original.results.clear();
      expect(DHTQueryCompletedEvent.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = DHTQueryCompletedEvent.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(DHTQueryCompletedEvent.fromJson(json), isNotNull);
    });
  });

  group('DHTValueFoundEvent', () {
    test('round-trips and accessors work', () {
      final original = DHTValueFoundEvent(key: 'a', value: const [0, 1, 2], peerId: 'a');
      expect(original.key, 'a');
      expect(original.value, const [0, 1, 2]);
      expect(original.peerId, 'a');
      original.hasKey();
      original.clearKey();
      original.hasValue();
      original.clearValue();
      original.hasPeerId();
      original.clearPeerId();
      expect(DHTValueFoundEvent.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = DHTValueFoundEvent.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(DHTValueFoundEvent.fromJson(json), isNotNull);
    });
  });

  group('DHTValueNotFoundEvent', () {
    test('round-trips and accessors work', () {
      final original = DHTValueNotFoundEvent(key: 'a');
      expect(original.key, 'a');
      original.hasKey();
      original.clearKey();
      expect(DHTValueNotFoundEvent.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = DHTValueNotFoundEvent.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(DHTValueNotFoundEvent.fromJson(json), isNotNull);
    });
  });

  group('DHTValueProvidedEvent', () {
    test('round-trips and accessors work', () {
      final original = DHTValueProvidedEvent(key: 'a', value: const [0, 1, 2]);
      expect(original.key, 'a');
      expect(original.value, const [0, 1, 2]);
      original.hasKey();
      original.clearKey();
      original.hasValue();
      original.clearValue();
      expect(DHTValueProvidedEvent.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = DHTValueProvidedEvent.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(DHTValueProvidedEvent.fromJson(json), isNotNull);
    });
  });

  group('DHTProviderAddedEvent', () {
    test('round-trips and accessors work', () {
      final original = DHTProviderAddedEvent(key: 'a', peerId: 'a');
      expect(original.key, 'a');
      expect(original.peerId, 'a');
      original.hasKey();
      original.clearKey();
      original.hasPeerId();
      original.clearPeerId();
      expect(DHTProviderAddedEvent.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = DHTProviderAddedEvent.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(DHTProviderAddedEvent.fromJson(json), isNotNull);
    });
  });

  group('DHTProviderQueriedEvent', () {
    test('round-trips and accessors work', () {
      final original = DHTProviderQueriedEvent(key: 'a', providers: ['a']);
      expect(original.key, 'a');
      expect(original.providers, ['a']);
      original.hasKey();
      original.clearKey();
      original.providers.clear();
      expect(DHTProviderQueriedEvent.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = DHTProviderQueriedEvent.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(DHTProviderQueriedEvent.fromJson(json), isNotNull);
    });
  });

  group('PubsubMessagePublishedEvent', () {
    test('round-trips and accessors work', () {
      final original = PubsubMessagePublishedEvent(topic: 'a', messageContent: const [0, 1, 2]);
      expect(original.topic, 'a');
      expect(original.messageContent, const [0, 1, 2]);
      original.hasTopic();
      original.clearTopic();
      original.hasMessageContent();
      original.clearMessageContent();
      expect(PubsubMessagePublishedEvent.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = PubsubMessagePublishedEvent.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(PubsubMessagePublishedEvent.fromJson(json), isNotNull);
    });
  });

  group('PubsubMessageReceivedEvent', () {
    test('round-trips and accessors work', () {
      final original = PubsubMessageReceivedEvent(topic: 'a', messageContent: const [0, 1, 2], peerId: 'a');
      expect(original.topic, 'a');
      expect(original.messageContent, const [0, 1, 2]);
      expect(original.peerId, 'a');
      original.hasTopic();
      original.clearTopic();
      original.hasMessageContent();
      original.clearMessageContent();
      original.hasPeerId();
      original.clearPeerId();
      expect(PubsubMessageReceivedEvent.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = PubsubMessageReceivedEvent.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(PubsubMessageReceivedEvent.fromJson(json), isNotNull);
    });
  });

  group('PubsubSubscriptionCreatedEvent', () {
    test('round-trips and accessors work', () {
      final original = PubsubSubscriptionCreatedEvent(topic: 'a');
      expect(original.topic, 'a');
      original.hasTopic();
      original.clearTopic();
      expect(PubsubSubscriptionCreatedEvent.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = PubsubSubscriptionCreatedEvent.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(PubsubSubscriptionCreatedEvent.fromJson(json), isNotNull);
    });
  });

  group('PubsubSubscriptionCancelledEvent', () {
    test('round-trips and accessors work', () {
      final original = PubsubSubscriptionCancelledEvent(topic: 'a');
      expect(original.topic, 'a');
      original.hasTopic();
      original.clearTopic();
      expect(PubsubSubscriptionCancelledEvent.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = PubsubSubscriptionCancelledEvent.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(PubsubSubscriptionCancelledEvent.fromJson(json), isNotNull);
    });
  });

  group('CircuitRelayCreatedEvent', () {
    test('round-trips and accessors work', () {
      final original = CircuitRelayCreatedEvent(relayAddress: 'a');
      expect(original.relayAddress, 'a');
      original.hasRelayAddress();
      original.clearRelayAddress();
      expect(CircuitRelayCreatedEvent.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = CircuitRelayCreatedEvent.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(CircuitRelayCreatedEvent.fromJson(json), isNotNull);
    });
  });

  group('CircuitRelayClosedEvent', () {
    test('round-trips and accessors work', () {
      final original = CircuitRelayClosedEvent(relayAddress: 'a', reason: 'a');
      expect(original.relayAddress, 'a');
      expect(original.reason, 'a');
      original.hasRelayAddress();
      original.clearRelayAddress();
      original.hasReason();
      original.clearReason();
      expect(CircuitRelayClosedEvent.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = CircuitRelayClosedEvent.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(CircuitRelayClosedEvent.fromJson(json), isNotNull);
    });
  });

  group('CircuitRelayTrafficEvent', () {
    test('round-trips and accessors work', () {
      final original = CircuitRelayTrafficEvent(relayAddress: 'a', dataSize: $fixnum.Int64(1));
      expect(original.relayAddress, 'a');
      expect(original.dataSize, $fixnum.Int64(1));
      original.hasRelayAddress();
      original.clearRelayAddress();
      original.hasDataSize();
      original.clearDataSize();
      expect(CircuitRelayTrafficEvent.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = CircuitRelayTrafficEvent.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(CircuitRelayTrafficEvent.fromJson(json), isNotNull);
    });
  });

  group('CircuitRelayDataReceivedEvent', () {
    test('round-trips and accessors work', () {
      final original = CircuitRelayDataReceivedEvent(relayAddress: 'a', dataSize: $fixnum.Int64(1));
      expect(original.relayAddress, 'a');
      expect(original.dataSize, $fixnum.Int64(1));
      original.hasRelayAddress();
      original.clearRelayAddress();
      original.hasDataSize();
      original.clearDataSize();
      expect(CircuitRelayDataReceivedEvent.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = CircuitRelayDataReceivedEvent.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(CircuitRelayDataReceivedEvent.fromJson(json), isNotNull);
    });
  });

  group('CircuitRelayDataSentEvent', () {
    test('round-trips and accessors work', () {
      final original = CircuitRelayDataSentEvent(relayAddress: 'a', dataSize: $fixnum.Int64(1));
      expect(original.relayAddress, 'a');
      expect(original.dataSize, $fixnum.Int64(1));
      original.hasRelayAddress();
      original.clearRelayAddress();
      original.hasDataSize();
      original.clearDataSize();
      expect(CircuitRelayDataSentEvent.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = CircuitRelayDataSentEvent.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(CircuitRelayDataSentEvent.fromJson(json), isNotNull);
    });
  });

  group('CircuitRelayFailedEvent', () {
    test('round-trips and accessors work', () {
      final original = CircuitRelayFailedEvent(relayAddress: 'a', reason: 'a');
      expect(original.relayAddress, 'a');
      expect(original.reason, 'a');
      original.hasRelayAddress();
      original.clearRelayAddress();
      original.hasReason();
      original.clearReason();
      expect(CircuitRelayFailedEvent.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = CircuitRelayFailedEvent.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(CircuitRelayFailedEvent.fromJson(json), isNotNull);
    });
  });

  group('StreamStartedEvent', () {
    test('round-trips and accessors work', () {
      final original = StreamStartedEvent(streamId: 'a', peerId: 'a');
      expect(original.streamId, 'a');
      expect(original.peerId, 'a');
      original.hasStreamId();
      original.clearStreamId();
      original.hasPeerId();
      original.clearPeerId();
      expect(StreamStartedEvent.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = StreamStartedEvent.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(StreamStartedEvent.fromJson(json), isNotNull);
    });
  });

  group('StreamEndedEvent', () {
    test('round-trips and accessors work', () {
      final original = StreamEndedEvent(streamId: 'a', peerId: 'a', reason: 'a');
      expect(original.streamId, 'a');
      expect(original.peerId, 'a');
      expect(original.reason, 'a');
      original.hasStreamId();
      original.clearStreamId();
      original.hasPeerId();
      original.clearPeerId();
      original.hasReason();
      original.clearReason();
      expect(StreamEndedEvent.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = StreamEndedEvent.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(StreamEndedEvent.fromJson(json), isNotNull);
    });
  });

  group('PeerDiscoveredEvent', () {
    test('round-trips and accessors work', () {
      final original = PeerDiscoveredEvent(peerId: 'a');
      expect(original.peerId, 'a');
      original.hasPeerId();
      original.clearPeerId();
      expect(PeerDiscoveredEvent.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = PeerDiscoveredEvent.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(PeerDiscoveredEvent.fromJson(json), isNotNull);
    });
  });

  group('NodeErrorEvent', () {
    test('round-trips and accessors work', () {
      final original = NodeErrorEvent(errorType: NodeErrorEvent_ErrorType.values.first, message: 'a', stackTrace: 'a', source: 'a');
      expect(original.errorType, isNotNull);
      expect(original.message, 'a');
      expect(original.stackTrace, 'a');
      expect(original.source, 'a');
      original.hasErrorType();
      original.clearErrorType();
      original.hasMessage();
      original.clearMessage();
      original.hasStackTrace();
      original.clearStackTrace();
      original.hasSource();
      original.clearSource();
      expect(NodeErrorEvent.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = NodeErrorEvent.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(NodeErrorEvent.fromJson(json), isNotNull);
    });
  });

  group('NetworkStatusChangedEvent', () {
    test('round-trips and accessors work', () {
      final original = NetworkStatusChangedEvent(changeType: NetworkStatusChangedEvent_ChangeType.values.first);
      expect(original.changeType, isNotNull);
      original.hasChangeType();
      original.clearChangeType();
      expect(NetworkStatusChangedEvent.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = NetworkStatusChangedEvent.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(NetworkStatusChangedEvent.fromJson(json), isNotNull);
    });
  });

  group('ResourceLimitExceededEvent', () {
    test('round-trips and accessors work', () {
      final original = ResourceLimitExceededEvent(resourceType: 'a', message: 'a');
      expect(original.resourceType, 'a');
      expect(original.message, 'a');
      original.hasResourceType();
      original.clearResourceType();
      original.hasMessage();
      original.clearMessage();
      expect(ResourceLimitExceededEvent.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = ResourceLimitExceededEvent.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(ResourceLimitExceededEvent.fromJson(json), isNotNull);
    });
  });

  group('SystemAlertEvent', () {
    test('round-trips and accessors work', () {
      final original = SystemAlertEvent(alertType: 'a', message: 'a');
      expect(original.alertType, 'a');
      expect(original.message, 'a');
      original.hasAlertType();
      original.clearAlertType();
      original.hasMessage();
      original.clearMessage();
      expect(SystemAlertEvent.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = SystemAlertEvent.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(SystemAlertEvent.fromJson(json), isNotNull);
    });
  });

}
