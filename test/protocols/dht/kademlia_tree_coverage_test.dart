import 'dart:async';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/proto/generated/dht/kademlia.pb.dart' as kad;
import 'package:dart_ipfs/src/protocols/dht/dht_client.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_routing_table.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'kademlia_tree_coverage_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<DHTClient>(),
  MockSpec<RouterInterface>(),
  MockSpec<KademliaRoutingTable>(),
])
void main() {
  late KademliaTree tree;
  late MockDHTClient mockClient;
  late MockRouterInterface mockRouter;
  late MockKademliaRoutingTable mockRoutingTable;
  late PeerId localPeerId;

  setUp(() {
    mockClient = MockDHTClient();
    mockRouter = MockRouterInterface();
    mockRoutingTable = MockKademliaRoutingTable();
    localPeerId = PeerId(value: Uint8List.fromList(List.filled(32, 0)));

    when(mockClient.peerId).thenReturn(localPeerId);
    when(mockClient.router).thenReturn(mockRouter);
    when(mockClient.kademliaRoutingTable).thenReturn(mockRoutingTable);
    when(mockRouter.peerID).thenReturn(localPeerId.toBase58());

    when(mockRoutingTable.findClosestPeers(any, any)).thenReturn([]);

    tree = KademliaTree(mockClient);
  });

  group('KademliaTree Coverage Tests', () {
    test('Constructor initializes correctly', () {
      expect(tree.root, isNotNull);
      expect(tree.buckets.length, equals(256));
      expect(tree.dhtClient, equals(mockClient));
      expect(tree.lastSeen, isEmpty);
      expect(tree.recentContacts, isEmpty);
      expect(tree.lookupSuccessHistory, isEmpty);
    });

    test('findClosestPeers returns closest peers from buckets', () async {
      final target = PeerId(value: Uint8List.fromList(List.filled(32, 1)));
      // Initially only root might be there or nothing
      final peers = tree.findClosestPeers(target, 10);
      expect(peers, isEmpty); // Root is not in buckets
    });

    test('storeLocalValue and getValue delegate to ValueStore', () async {
      await tree.storeLocalValue('key', Uint8List.fromList([1, 2, 3]));
      final val = await tree.getValue('key');
      expect(val, equals(Uint8List.fromList([1, 2, 3])));
    });

    test('sendPing failure case', () async {
      final peer = PeerId(value: Uint8List.fromList(List.filled(32, 2)));
      // Should timeout because we don't resolve it
      final result = await tree
          .sendPing(peer)
          .timeout(const Duration(milliseconds: 100), onTimeout: () => false);
      expect(result, isFalse);
    });

    test('storeValue failure case', () async {
      final peer = PeerId(value: Uint8List.fromList(List.filled(32, 2)));
      final result = await tree
          .storeValue(peer, Uint8List.fromList([1]), Uint8List.fromList([2]))
          .timeout(const Duration(milliseconds: 100), onTimeout: () => false);
      expect(result, isFalse);
    });

    test('findValue basic flow with no peers', () async {
      final key = Uint8List.fromList([1, 2, 3]);
      final (value, peers) = await tree.findValue(key);
      expect(value, isNull);
      expect(peers, isEmpty);
    });

    test('handleIncomingMessage can be called', () {
      final message = kad.Message();
      tree.handleIncomingMessage(message);
    });

    test('refresh can be called', () {
      tree.refresh();
    });

    test('getAssociatedPeer returns null for unknown peer', () {
      final peer = PeerId(value: Uint8List.fromList(List.filled(32, 3)));
      expect(tree.getAssociatedPeer(peer), isNull);
    });
  });
}
