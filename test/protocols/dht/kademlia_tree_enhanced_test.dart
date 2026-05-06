import 'dart:async';
import 'dart:typed_data';

import 'package:dart_ipfs/src/proto/generated/base_messages.pb.dart';
import 'package:dart_ipfs/src/proto/generated/dht/kademlia.pb.dart' as kad;
import 'package:dart_ipfs/src/proto/generated/dht/dht.pb.dart' as dht_proto;
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/bucket_management.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/kademlia_tree_node.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/helpers.dart'
    as helpers;
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'kademlia_tree_coverage_test.mocks.dart';

void main() {
  late KademliaTree tree;
  late MockDHTClient mockClient;
  late MockRouterInterface mockRouter;
  late PeerId localPeerId;

  setUp(() {
    mockClient = MockDHTClient();
    mockRouter = MockRouterInterface();
    localPeerId = PeerId(value: Uint8List.fromList(List.filled(32, 0)));

    when(mockClient.peerId).thenReturn(localPeerId);
    when(mockClient.router).thenReturn(mockRouter);
    when(mockRouter.peerID).thenReturn(localPeerId.toBase58());

    tree = KademliaTree(mockClient);
  });

  group('KademliaTree Enhanced Coverage', () {
    test('nodeLookup iterative process with simulated responses', () async {
      final target = PeerId(value: Uint8List.fromList(List.filled(32, 255)));

      // Add 3 initial peers
      for (int i = 1; i <= 3; i++) {
        final peerId = PeerId(value: Uint8List.fromList(List.filled(32, i)));
        final node = KademliaTreeNode(
          peerId,
          helpers.calculateDistance(peerId, localPeerId),
          localPeerId,
          lastSeen: DateTime.now().millisecondsSinceEpoch,
        );
        final bucketIndex = tree.getBucketIndex(node.distance);
        tree.buckets[bucketIndex].insert(peerId, node);
      }

      // Intercept sendMessage to respond
      when(mockRouter.sendMessage(any, any)).thenAnswer((invocation) async {
        final messageBytes = invocation.positionalArguments[1] as Uint8List;
        final ipfsMessage = IPFSMessage.fromBuffer(messageBytes);
        final requestId = int.parse(ipfsMessage.requestId);

        // Create a response with closer peers
        final response = kad.Message()
          ..type = kad.Message_MessageType.FIND_NODE;

        // Add some "closer" peers in the response
        for (int i = 10; i < 13; i++) {
          final p = kad.Peer()..id = Uint8List.fromList(List.filled(32, i));
          response.closerPeers.add(p);
        }

        // Schedule response
        Future.delayed(Duration(milliseconds: 10), () {
          tree.handleResponse(requestId, response);
        });
      });

      final result = await tree.nodeLookup(target);

      expect(result, isNotEmpty);
      expect(result.length, greaterThanOrEqualTo(3));
    });

    test('Rate limiting integration', () async {
      final target = PeerId(value: Uint8List.fromList(List.filled(32, 255)));

      when(mockRouter.sendMessage(any, any)).thenAnswer((invocation) async {
        final messageBytes = invocation.positionalArguments[1] as Uint8List;
        final ipfsMessage = IPFSMessage.fromBuffer(messageBytes);
        tree.handleResponse(
          int.parse(ipfsMessage.requestId),
          kad.Message()..type = kad.Message_MessageType.FIND_NODE,
        );
      });

      await tree.nodeLookup(target);
    });

    test('Periodic tasks and republishing', () async {
      tree.refresh();

      tree.handleIncomingMessage(
        kad.Message()..type = kad.Message_MessageType.PING,
      );
      tree.handleIncomingMessage(
        kad.Message()..type = kad.Message_MessageType.FIND_NODE,
      );
      tree.handleIncomingMessage(
        kad.Message()..type = kad.Message_MessageType.GET_VALUE,
      );
      tree.handleIncomingMessage(
        kad.Message()..type = kad.Message_MessageType.PUT_VALUE,
      );
    });

    test('findValue with results', () async {
      final key = Uint8List.fromList([1, 2, 3]);
      final peerId = PeerId(value: Uint8List.fromList(List.filled(32, 1)));
      final node = KademliaTreeNode(
        peerId,
        helpers.calculateDistance(peerId, localPeerId),
        localPeerId,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      );
      tree.buckets[tree.getBucketIndex(node.distance)].insert(peerId, node);

      when(mockRouter.sendMessage(any, any)).thenAnswer((invocation) async {
        final messageBytes = invocation.positionalArguments[1] as Uint8List;
        final ipfsMessage = IPFSMessage.fromBuffer(messageBytes);
        final response = kad.Message()
          ..type = kad.Message_MessageType.GET_VALUE
          ..record = (dht_proto.Record()
            ..value = Uint8List.fromList([4, 5, 6]));
        tree.handleResponse(int.parse(ipfsMessage.requestId), response);
      });

      final (value, peers) = await tree.findValue(key);
      expect(value, equals(Uint8List.fromList([4, 5, 6])));
      expect(peers, isEmpty);
    });

    test('findValue with no value but closer peers', () async {
      final key = Uint8List.fromList([1, 2, 3]);
      final peerId = PeerId(value: Uint8List.fromList(List.filled(32, 1)));
      final node = KademliaTreeNode(
        peerId,
        helpers.calculateDistance(peerId, localPeerId),
        localPeerId,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      );
      tree.buckets[tree.getBucketIndex(node.distance)].insert(peerId, node);

      when(mockRouter.sendMessage(any, any)).thenAnswer((invocation) async {
        final messageBytes = invocation.positionalArguments[1] as Uint8List;
        final ipfsMessage = IPFSMessage.fromBuffer(messageBytes);
        final response = kad.Message()
          ..type = kad.Message_MessageType.FIND_NODE
          ..closerPeers.add(
            kad.Peer()..id = Uint8List.fromList(List.filled(32, 2)),
          );
        tree.handleResponse(int.parse(ipfsMessage.requestId), response);
      });

      final (value, peers) = await tree.findValue(key);
      expect(value, isNull);
      expect(peers, isNotEmpty);
    });

    test('storeValue success', () async {
      final peerId = PeerId(value: Uint8List.fromList(List.filled(32, 1)));
      final key = Uint8List.fromList([1, 2, 3]);
      final val = Uint8List.fromList([4, 5, 6]);

      when(mockRouter.sendMessage(any, any)).thenAnswer((invocation) async {
        final messageBytes = invocation.positionalArguments[1] as Uint8List;
        final ipfsMessage = IPFSMessage.fromBuffer(messageBytes);
        final response = kad.Message()
          ..type = kad.Message_MessageType.PUT_VALUE;
        tree.handleResponse(int.parse(ipfsMessage.requestId), response);
      });

      final result = await tree.storeValue(peerId, key, val);
      expect(result, isTrue);
    });

    test('sendPing success', () async {
      final peerId = PeerId(value: Uint8List.fromList(List.filled(32, 1)));

      when(mockRouter.sendMessage(any, any)).thenAnswer((invocation) async {
        final messageBytes = invocation.positionalArguments[1] as Uint8List;
        final ipfsMessage = IPFSMessage.fromBuffer(messageBytes);
        final response = kad.Message()..type = kad.Message_MessageType.PING;
        tree.handleResponse(int.parse(ipfsMessage.requestId), response);
      });

      final result = await tree.sendPing(peerId);
      expect(result, isTrue);
    });
  });
}
