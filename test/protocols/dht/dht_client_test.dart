// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/core/storage/datastore.dart';
import 'package:dart_ipfs/src/proto/generated/dht/dht.pb.dart' as dht_proto;
import 'package:dart_ipfs/src/proto/generated/dht/kademlia.pb.dart' as kad;
import 'package:dart_ipfs/src/protocols/dht/dht_client.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_handler.dart';
import 'package:dart_ipfs/src/transport/p2plib_router.dart';
import 'package:dart_ipfs/src/transport/router_events.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/utils/base58.dart';
import 'package:p2plib/p2plib.dart' as p2p;
import 'package:test/test.dart';

// Helper for valid PeerId (64 bytes)
Uint8List get validPeerIdBytes => Uint8List.fromList(List.filled(64, 1));

// Mocks
class MockRouterL2 implements p2p.RouterL2 {
  @override
  final Map<p2p.PeerId, p2p.Route> routes = {};
  final p2p.PeerId _selfId = p2p.PeerId(value: validPeerIdBytes);

  @override
  p2p.PeerId get selfId => _selfId;

  @override
  Iterable<p2p.FullAddress> resolvePeerId(p2p.PeerId peerId) {
    return [p2p.FullAddress(address: InternetAddress.loopbackIPv4, port: 4001)];
  }

  @override
  void sendDatagram({
    required Iterable<p2p.FullAddress> addresses,
    required Uint8List datagram,
  }) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockP2plibRouter implements P2plibRouter {
  final MockRouterL2 _mockL2 = MockRouterL2();
  void Function(NetworkPacket)? _handler;
  void Function(Uint8List)? onSendDatagram;

  /// Optional: Function that takes request bytes and returns response bytes
  /// Used to auto-respond to network requests for testing
  Uint8List Function(Uint8List request)? responseGenerator;

  @override
  p2p.RouterL2 get routerL0 => _mockL2;

  @override
  p2p.PeerId get peerId => _mockL2.selfId;

  @override
  String get peerID => Base58().encode(_mockL2.selfId.value);

  @override
  Map<p2p.PeerId, p2p.Route> get routes => _mockL2.routes;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  void registerProtocol(String protocolId) {}

  @override
  void registerProtocolHandler(
    String protocolId,
    void Function(NetworkPacket) handler,
  ) {
    _handler = handler;
  }

  @override
  void removeMessageHandler(String protocolId) {
    _handler = null;
  }

  @override
  Future<void> sendMessage(
    String peerId,
    Uint8List message, {
    String? protocolId,
  }) async {
    // In mock, we can just trigger onSendDatagram directly
    onSendDatagram?.call(message);

    // If responseGenerator is set, auto-generate and inject response
    if (responseGenerator != null && _handler != null) {
      final responseBytes = responseGenerator!(message);
      final responsePacket = NetworkPacket(
        srcPeerId: peerId, // Use the proper peerId we sent to
        datagram: responseBytes,
      );
      // Inject response asynchronously to simulate network
      // ignore: unawaited_futures
      Future.microtask(() => _handler?.call(responsePacket));
    }
  }

  @override
  Future<void> sendDatagram({
    required List<String> addresses,
    required Uint8List datagram,
  }) async {
    // Logic moved to sendMessage or similar
    onSendDatagram?.call(datagram);
  }

  @override
  List<String> resolvePeerId(String peerIdStr) {
    return ['127.0.0.1:4001'];
  }

  void simulatePacket(p2p.Packet packet) {
    // Convert p2p.Packet to NetworkPacket
    final networkPacket = NetworkPacket(
      srcPeerId: Base58().encode(packet.srcPeerId.value),
      datagram: packet.datagram,
    );
    _handler?.call(networkPacket);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockDatastore implements Datastore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockDHTHandler implements DHTHandler {
  MockDHTHandler(this.router);
  @override
  final P2plibRouter router;
  final Datastore _mockStorage = MockDatastore();

  @override
  Datastore get storage => _mockStorage;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockIPFSNode implements IPFSNode {
  MockIPFSNode(this._dhtHandler);
  final MockDHTHandler _dhtHandler;

  @override
  DHTHandler get dhtHandler => _dhtHandler;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockNetworkHandler implements NetworkHandler {
  @override
  late IPFSNode ipfsNode;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('DHTClient', () {
    late DHTClient client;
    late MockP2plibRouter mockRouter;
    late MockNetworkHandler mockNetworkHandler;
    late MockIPFSNode mockNode;

    setUp(() {
      mockRouter = MockP2plibRouter();
      mockNetworkHandler = MockNetworkHandler();
      // Setup dependencies
      mockNode = MockIPFSNode(MockDHTHandler(mockRouter));
      mockNetworkHandler.ipfsNode = mockNode;

      // Populate routes so initialize doesn't fail
      mockRouter._mockL2.routes[p2p.PeerId(value: validPeerIdBytes)] =
          p2p.Route(peerId: p2p.PeerId(value: validPeerIdBytes));

      client = DHTClient(
        networkHandler: mockNetworkHandler,
        router: mockRouter,
      );
    });

    test('initialize', () async {
      await client.initialize();
      expect(client, isNotNull);
    });

    test('findProviders', () async {
      await client.initialize();

      // Create a valid CID
      final data = Uint8List.fromList([1, 2, 3, 4]);
      final cidObj = await CID.fromContent(data);
      final cid = cidObj.encode();

      mockRouter.onSendDatagram = (data) {
        try {
          final msg = kad.Message.fromBuffer(data);
          if (msg.type == kad.Message_MessageType.GET_PROVIDERS) {
            // Simulate response
            final response = kad.Message()
              ..type = kad.Message_MessageType.GET_PROVIDERS
              ..providerPeers.add(kad.Peer()..id = validPeerIdBytes);

            final responsePacket = p2p.Packet(
              datagram: response.writeToBuffer(),
              header: const p2p.PacketHeader(id: 0, issuedAt: 0),
              srcFullAddress: p2p.FullAddress(
                address: InternetAddress.loopbackIPv4,
                port: 4001,
              ),
            );
            responsePacket.srcPeerId = p2p.PeerId(
              value: Uint8List.fromList(List.filled(64, 2)),
            );

            // Inject response
            mockRouter.simulatePacket(responsePacket);
          }
        } catch (e) {
          print('Error in mock sendDatagram: $e');
        }
      };

      // Add a peer to routing table so we have someone to query
      final otherPeerIdBytes = Uint8List.fromList(List.filled(64, 2));
      final otherPeerId = PeerId(value: otherPeerIdBytes);
      await client.kademliaRoutingTable.addPeer(otherPeerId, otherPeerId);

      final providers = await client.findProviders(cid);

      expect(providers, isNotEmpty);
      expect(providers.first.value, equals(validPeerIdBytes));
    });

    test('storeValue method exists with correct signature', () async {
      await client.initialize();

      // Verify method exists and returns Future<bool>
      final key = Uint8List.fromList([1, 2, 3, 4]);
      final value = Uint8List.fromList([5, 6, 7, 8]);

      // Don't add peers to routing table - method should return false immediately
      final result = await client.storeValue(key, value);
      expect(result, isFalse); // No peers = false
    });

    test('getValue method exists with correct signature', () async {
      await client.initialize();

      final key = Uint8List.fromList([1, 2, 3, 4]);

      // Don't add peers to routing table - method should return null immediately
      final result = await client.getValue(key);
      expect(result, isNull); // No peers = null
    });

    test('checkValueOnPeer returns true when peer has value', () async {
      await client.initialize();

      final key = Uint8List.fromList([1, 2, 3, 4]);
      final value = Uint8List.fromList([5, 6, 7, 8]);

      // Set up auto-response: respond with a record containing the value
      mockRouter.responseGenerator = (requestBytes) {
        final record = dht_proto.Record()
          ..key = key
          ..value = value;
        final response = kad.Message()
          ..type = kad.Message_MessageType.GET_VALUE
          ..record = record;
        return response.writeToBuffer();
      };

      final peer = PeerId(value: Uint8List.fromList(List.filled(64, 5)));

      final hasValue = await client.checkValueOnPeer(peer, key);
      expect(hasValue, isTrue);
    });

    test('checkValueOnPeer returns false when peer has no value', () async {
      await client.initialize();

      final key = Uint8List.fromList([1, 2, 3, 4]);

      // Set up auto-response: respond with empty record (no value)
      mockRouter.responseGenerator = (requestBytes) {
        final response = kad.Message()
          ..type = kad.Message_MessageType.GET_VALUE;
        // No record set
        return response.writeToBuffer();
      };

      final peer = PeerId(value: Uint8List.fromList(List.filled(64, 5)));

      final hasValue = await client.checkValueOnPeer(peer, key);
      expect(hasValue, isFalse);
    });
  });
}
