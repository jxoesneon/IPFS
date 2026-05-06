import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_client.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/refresh.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/add_peer.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';

@GenerateMocks([DHTClient, RouterInterface])
import 'refresh_test.mocks.dart';

void main() {
  late MockDHTClient mockClient;
  late MockRouterInterface mockRouter;
  late KademliaTree tree;
  late PeerId localPeerId;

  setUp(() {
    mockClient = MockDHTClient();
    mockRouter = MockRouterInterface();
    localPeerId = PeerId(value: Uint8List.fromList(List.filled(32, 0)));

    when(mockClient.peerId).thenReturn(localPeerId);
    when(mockClient.router).thenReturn(mockRouter);

    tree = KademliaTree(mockClient);
  });

  group('Refresh Extension', () {
    test('refresh() updates lastSeen for recently seen peers', () {
      final peerId = PeerId(value: Uint8List.fromList(List.filled(32, 1)));

      // Manually add peer to a bucket
      // We need to calculate the correct bucket index or just add it to any bucket for testing refresh
      // KademliaTree has a public 'buckets' getter
      tree.buckets[0].insert(
        peerId,
        tree.root!,
      ); // value doesn't matter much for refresh

      final initialLastSeen = DateTime.now().subtract(
        const Duration(minutes: 10),
      );
      tree.lastSeen[peerId] = initialLastSeen;

      tree.refresh();

      expect(tree.lastSeen.containsKey(peerId), isTrue);
      expect(tree.lastSeen[peerId]!.isAfter(initialLastSeen), isTrue);
    });

    test('refresh() removes stale peers', () {
      final peerId = PeerId(value: Uint8List.fromList(List.filled(32, 1)));

      // Add peer via tree.addPeer to ensure correct bucket placement
      tree.addPeer(peerId, localPeerId);

      // Set last seen to be older than refreshTimeout (1 hour)
      final staleTime = DateTime.now().subtract(const Duration(minutes: 70));
      tree.lastSeen[peerId] = staleTime;

      tree.refresh();

      // Peer should be removed from lastSeen
      expect(tree.lastSeen.containsKey(peerId), isFalse);

      // Peer should be removed from buckets
      bool found = false;
      for (var bucket in tree.buckets) {
        if (bucket.containsKey(peerId)) {
          found = true;
          break;
        }
      }
      expect(found, isFalse);
    });

    test('refresh() handles peers with no entry in lastSeen', () {
      final peerId = PeerId(value: Uint8List.fromList(List.filled(32, 2)));

      // Add peer via tree.addPeer to ensure correct bucket placement
      tree.addPeer(peerId, localPeerId);
      // tree.lastSeen[peerId] is NOT set

      tree.refresh();

      // It should now have an entry in lastSeen
      expect(tree.lastSeen.containsKey(peerId), isTrue);
    });
  });
}
