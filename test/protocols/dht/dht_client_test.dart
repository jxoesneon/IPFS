import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:p2plib/p2plib.dart' as p2p;
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_client.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_handler.dart';
import 'package:dart_ipfs/src/transport/p2plib_router.dart';
import 'package:dart_ipfs/src/storage/datastore.dart';
import 'package:dart_ipfs/src/proto/generated/dht/kademlia.pb.dart' as kad;
import 'package:test/test.dart';

// Helper for valid PeerId (64 bytes)
Uint8List get validPeerIdBytes => Uint8List.fromList(List.filled(64, 1));

// Mocks
class MockRouterL2 implements p2p.RouterL2 {
  final Map<p2p.PeerId, p2p.Route> routes = {};
  p2p.PeerId _selfId = p2p.PeerId(value: validPeerIdBytes);

  @override
  p2p.PeerId get selfId => _selfId;

  @override
  Iterable<p2p.FullAddress> resolvePeerId(p2p.PeerId peerId) {
    return [p2p.FullAddress(address: InternetAddress.loopbackIPv4, port: 4001)];
  }

  @override
  void sendDatagram(
      {required Iterable<p2p.FullAddress> addresses,
      required Uint8List datagram}) {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockP2plibRouter implements P2plibRouter {
  final MockRouterL2 _mockL2 = MockRouterL2();
  Function(p2p.Packet)? _handler;
  Function(Uint8List)? onSendDatagram;

  @override
  p2p.RouterL2 get routerL0 => _mockL2;

  @override
  p2p.PeerId get peerId => _mockL2.selfId;

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
  void addMessageHandler(String protocolId, Function(p2p.Packet) handler) {
    _handler = handler;
  }

  @override
  void removeMessageHandler(String protocolId) {
    _handler = null;
  }

  @override
  Future<void> sendDatagram(
      {required List<String> addresses, required Uint8List datagram}) async {
    onSendDatagram?.call(datagram);
  }

  @override
  List<String> resolvePeerId(p2p.PeerId peerId) {
    return ['127.0.0.1:4001'];
  }

  void simulatePacket(p2p.Packet packet) {
    _handler?.call(packet);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockDatastore implements Datastore {
  @override
  Future<List<String>> getAllKeys() async => [];

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockDHTHandler implements DHTHandler {
  final P2plibRouter router;
  final Datastore _mockStorage = MockDatastore();

  MockDHTHandler(this.router);

  @override
  Datastore get storage => _mockStorage;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockIPFSNode implements IPFSNode {
  final MockDHTHandler _dhtHandler;
  MockIPFSNode(this._dhtHandler);

  @override
  DHTHandler get dhtHandler => _dhtHandler;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockNetworkHandler implements NetworkHandler {
  @override
  late IPFSNode ipfsNode;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

      client =
          DHTClient(networkHandler: mockNetworkHandler, router: mockRouter);
    });

    test('initialize', () async {
      await client.initialize();
      expect(client, isNotNull);
    });

    test('findProviders', () async {
      await client.initialize();

      final cid = 'QmTestHash';

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
                header: p2p.PacketHeader(id: 0, issuedAt: 0),
                srcFullAddress: p2p.FullAddress(
                    address: InternetAddress.loopbackIPv4, port: 4001));
            responsePacket.srcPeerId = p2p.PeerId(value: validPeerIdBytes);

            // Inject response
            mockRouter.simulatePacket(responsePacket);
          }
        } catch (e) {
          print('Error in mock sendDatagram: $e');
        }
      };

      // Add a peer to routing table so we have someone to query
      final otherPeerIdBytes = Uint8List.fromList(List.filled(64, 2));
      final otherPeerId = p2p.PeerId(value: otherPeerIdBytes);
      await client.kademliaRoutingTable.addPeer(otherPeerId, otherPeerId);

      final providers = await client.findProviders(cid);

      expect(providers, isNotEmpty);
      expect(providers.first.value, equals(validPeerIdBytes));
    });
  });
}
