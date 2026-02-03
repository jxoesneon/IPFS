import 'dart:async';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_client.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_routing_table.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/proto/generated/dht/common_red_black_tree.pb.dart';
import 'package:dart_ipfs/src/proto/generated/dht/kademlia.pb.dart' as kad;
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart'
    as pb_ts;
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/kademlia_tree_node.dart';
import 'package:dart_ipfs/src/protocols/dht/red_black_tree.dart';
import 'package:test/test.dart';

// Mocks/Fakes
class MockNetworkHandler implements NetworkHandler {
  Future<Uint8List> Function(String, String, Uint8List)? onSendRequest;

  @override
  Future<Uint8List> sendRequest(
    String peerId,
    String protocol,
    Uint8List data,
  ) async {
    if (onSendRequest != null) return onSendRequest!(peerId, protocol, data);
    return Uint8List(0);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class MockDHTClient implements DHTClient {
  @override
  final PeerId peerId;
  @override
  final PeerId associatedPeerId;
  @override
  final NetworkHandler networkHandler;

  MockDHTClient(this.peerId, this.networkHandler) : associatedPeerId = peerId;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  group('KademliaRoutingTable', () {
    late KademliaRoutingTable table;
    late MockDHTClient mockClient;
    late MockNetworkHandler mockNetworkHandler;
    late PeerId localPeerId;

    setUp(() {
      localPeerId = PeerId(value: Uint8List(32));
      mockNetworkHandler = MockNetworkHandler();
      mockClient = MockDHTClient(localPeerId, mockNetworkHandler);
      table = KademliaRoutingTable();
      table.initialize(mockClient);
    });

    PeerId createPeerId(int byte0, [int byte31 = 0]) {
      final bytes = Uint8List(32);
      bytes[0] = byte0;
      bytes[31] = byte31;
      return PeerId(value: bytes);
    }

    test('initialization', () {
      expect(table, isNotNull);
      expect(table.peerCount, 0);
      expect(table.buckets, isNotEmpty);
    });

    test('addPeer adds peers to correct bucket', () async {
      final peer = createPeerId(0x80);
      await table.addPeer(peer, peer);

      expect(table.peerCount, 1);
      expect(table.containsPeer(peer), isTrue);
    });

    test('IP limit enforcement', () async {
      final peer1 = createPeerId(0x80, 1);
      final peer2 = createPeerId(0x80, 2);
      final peer3 = createPeerId(0x80, 3);
      final ip = '192.168.1.1';

      await table.addPeer(peer1, peer1, address: ip);
      await table.addPeer(peer2, peer2, address: ip);

      await table.addPeer(peer3, peer3, address: ip);

      expect(table.containsPeer(peer1), isTrue);
      expect(table.containsPeer(peer2), isTrue);
      expect(table.containsPeer(peer3), isFalse);
    });

    test('buckets management', () async {
      for (int i = 0; i < 25; i++) {
        await table.addPeer(createPeerId(0x80, i), localPeerId);
      }

      // Since splitBucket is removed, we just fill the bucket (size 20).
      // Extra peers are dropped.
      // Bucket count is 256 (pre-sized or expanded).
      expect(table.buckets.length, 256);

      final peers = <PeerId>[];
      for (var bucket in table.buckets) {
        for (var entry in bucket.entries) {
          peers.add(entry.key);
        }
      }
      expect(peers.length, 20); // Only 20 allowed
    });

    test('refresh and stale node coverage', () async {
      final peer = createPeerId(0x80);
      await table.addPeer(peer, peer);

      final node = table.buckets[0].entries.first.value;
      node.lastSeen = DateTime.now()
          .subtract(Duration(hours: 5))
          .millisecondsSinceEpoch;

      table.refresh();
      expect(table.containsPeer(peer), isFalse);
    });

    test('removePeer', () async {
      final peer = createPeerId(0x80);
      await table.addPeer(peer, peer);
      expect(table.containsPeer(peer), isTrue);

      table.removePeer(peer);
      expect(table.containsPeer(peer), isFalse);
    });

    test('updatePeer coverage', () async {
      final peerId = createPeerId(0x40);
      final vPeerInfo = V_PeerInfo()
        ..peerId = peerId.value
        ..ipAddress = '1.1.1.1'
        ..lastSeen = pb_ts.Timestamp.fromDateTime(DateTime.now());

      final pingMsg = kad.Message()..type = kad.Message_MessageType.PING;
      mockNetworkHandler.onSendRequest = (p, pr, d) async =>
          pingMsg.writeToBuffer();

      await table.updatePeer(vPeerInfo);
      expect(table.containsPeer(peerId), isTrue);
    });

    test('updatePeer failure path', () async {
      final peerId = createPeerId(0x40);
      final vPeerInfo = V_PeerInfo()..peerId = peerId.value;

      mockNetworkHandler.onSendRequest = (p, pr, d) async =>
          throw Exception('Ping failed');

      expect(() => table.updatePeer(vPeerInfo), throwsException);
    });

    test('pingPeer failure', () async {
      mockNetworkHandler.onSendRequest = (p, pr, d) async =>
          throw Exception('Timeout');

      final result = await table.pingPeer(createPeerId(0x20));
      expect(result, isFalse);
    });

    test('findClosestPeers and internal bucket management', () async {
      // Test addPeerToBucket and removePeerFromBucket directly for coverage
      final p1 = createPeerId(0x10);
      final p2 = createPeerId(0x10, 1);

      table.addPeerToBucket(p1, localPeerId);
      table.addPeerToBucket(p2, localPeerId);
      expect(table.containsPeer(p1), isTrue);

      // Update existing
      table.addPeerToBucket(p1, localPeerId);

      table.removePeerFromBucket(p1);
      expect(table.containsPeer(p1), isFalse);

      // Remove non-existent
      table.removePeerFromBucket(createPeerId(0xFF));
    });

    test('stale threshold with different NodeStats', () async {
      final peer = createPeerId(0x80);
      await table.addPeer(peer, peer);

      // Force node stale for 1.5 hours (Default threshold is 1 hour)
      final node = table.buckets[0].entries.first.value;
      node.lastSeen = DateTime.now()
          .subtract(Duration(minutes: 90))
          .millisecondsSinceEpoch;

      // Should be stale with default stats (50 connected peers)
      table.refresh();
      expect(table.containsPeer(peer), isFalse);

      // Re-add and test with high peer count (Threshold becomes 2 hours)
      // Note: To truly test 2 hour threshold, we'd need to mock _getNodeStats or wait.
      // The current implementation of _getNodeStats is hardcoded to 50.
      // But we can test the branching if we could modify it.
      // Since _getNodeStats is internal and hardcoded, we cover the 50-path.
    });

    test('findClosestPeers', () async {
      for (int i = 0; i < 5; i++) {
        final p = createPeerId(0x80, i);
        await table.addPeer(p, p);
      }

      final target = createPeerId(0x80, 100);
      final closest = table.findClosestPeers(target, 3);
      expect(closest.length, 3);
    });

    test('addKeyProvider and updateKeyProviderTimestamp', () {
      final key = createPeerId(0x10);
      final provider = createPeerId(0x11);
      final now = DateTime.now();

      table.addKeyProvider(key, provider, now);
      expect(table.containsPeer(key), isTrue);

      table.updateKeyProviderTimestamp(
        key,
        provider,
        now.add(Duration(minutes: 1)),
      );
    });

    test('xorDistanceComparator Tiebreakers', () {
      expect(table.distance(createPeerId(0), createPeerId(0)), 0);
      // Distances to 0 for different bytes
      expect(table.distance(createPeerId(0x80), createPeerId(0)), 0);
    });

    test('addPeer with existing IP and removal', () async {
      final ip = '1.2.3.4';
      final p1 = createPeerId(0x80, 1);
      await table.addPeer(p1, p1, address: ip);

      await table.addPeer(p1, p1, address: ip);
      expect(table.containsPeer(p1), isTrue);

      table.removePeer(p1);
    });

    test('refresh and generateRandomKeyInBucket', () {
      table.refresh();
    });

    test('nodeLookup and getAssociatedPeer', () async {
      final p = createPeerId(0x80);
      await table.addPeer(p, p);

      final closest = await table.nodeLookup(p);
      expect(closest, isNotEmpty);

      expect(table.getAssociatedPeer(p), equals(p));
      expect(table.getAssociatedPeer(createPeerId(0xFF)), isNull);
    });

    test('clear', () async {
      await table.addPeer(createPeerId(0x80), localPeerId);
      expect(table.peerCount, 1);
      table.clear();
      expect(table.peerCount, 0);
    });

    test('distance sub-byte edge cases', () {
      expect(table.distance(createPeerId(0x80), createPeerId(0x00)), 0);
      expect(table.distance(createPeerId(0, 0x80), createPeerId(0, 0x00)), 248);
    });

    test('removePeer for non-existent peer', () {
      table.removePeer(createPeerId(0xFF));
    });

    test('update existing key provider', () {
      final key = createPeerId(0x05);
      final peerId = createPeerId(0x06);
      table.addKeyProvider(key, peerId, DateTime.now());
      table.addKeyProvider(key, peerId, DateTime.now()); // Update
    });

    test('stale node removal across multiple buckets', () async {
      for (int i = 0; i < 5; i++) {
        await table.addPeer(createPeerId(0x80, i), localPeerId);
        await table.addPeer(createPeerId(0x40, i), localPeerId);
      }

      final bucket1 = table.buckets[1];
      for (var entry in bucket1.entries.toList()) {
        entry.value.lastSeen = DateTime.now()
            .subtract(Duration(hours: 10))
            .millisecondsSinceEpoch;
      }

      table.refresh();
    });

    test('distance and peersEqual edge cases', () {
      final p1 = PeerId(value: Uint8List.fromList([1, 2, 3]));
      final p2 = PeerId(value: Uint8List.fromList([1, 2]));
      expect(table.distance(p1, p2), isNonNegative);
    });

    test('IP count cleanup on removal', () async {
      final ip = '1.1.1.1';
      final p1 = createPeerId(0x80, 1);
      await table.addPeer(p1, p1, address: ip);
      expect(table.containsPeer(p1), isTrue);

      table.removePeer(p1);
      expect(table.containsPeer(p1), isFalse);

      // Re-add should succeed since count was decremented
      await table.addPeer(createPeerId(0x80, 2), localPeerId, address: ip);
      await table.addPeer(createPeerId(0x80, 3), localPeerId, address: ip);
      expect(table.containsPeer(createPeerId(0x80, 3)), isTrue);
    });

    test('stale node removal coverage', () async {
      final p1 = createPeerId(0x80);
      await table.addPeer(p1, p1);

      // Manually make node stale
      final node = table.buckets[0].entries.first.value;
      node.lastSeen = DateTime.now()
          .subtract(Duration(hours: 2))
          .millisecondsSinceEpoch;

      table.refresh();
      expect(table.containsPeer(p1), isFalse);
    });

    test('addPeerToBucket on full bucket drops peer', () async {
      // Fill bucket 0 with 20 peers
      for (int i = 0; i < 20; i++) {
        final p = createPeerId(0x80, i);
        await table.addPeer(p, p);
      }
      expect(table.buckets.length, 256);

      // Add one more via addPeerToBucket specifically
      final extra = createPeerId(0x80, 20);
      table.addPeerToBucket(extra, extra);

      // Should be dropped
      expect(table.containsPeer(extra), isFalse);
    });

    test('updatePeer on full bucket', () async {
      // Fill bucket 0 with 20 peers
      final pStart = createPeerId(0x80, 0);
      await table.addPeer(pStart, pStart);

      for (int i = 1; i < 20; i++) {
        final p = createPeerId(0x80, i);
        await table.addPeer(p, p);
      }

      // Prepare update for pStart (already in table)
      final vPeerInfo = V_PeerInfo()
        ..peerId = pStart.value
        ..ipAddress = '1.2.3.4'
        ..lastSeen = pb_ts.Timestamp.fromDateTime(DateTime.now());

      mockNetworkHandler.onSendRequest = (p, pr, d) async =>
          (kad.Message()..type = kad.Message_MessageType.PING).writeToBuffer();

      // Should update timestamp without error or split
      await table.updatePeer(vPeerInfo);

      // Verify pStart still there
      expect(table.containsPeer(pStart), isTrue);
    });
  });
}
