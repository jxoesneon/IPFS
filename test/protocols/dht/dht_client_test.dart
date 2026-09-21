import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/proto/generated/dht/kademlia.pb.dart' as kad;
import 'package:dart_ipfs/src/protocols/dht/dht_client.dart';
import 'package:ipfs_libp2p/dart_libp2p.dart' as libp2p;

import 'dht_client_coverage_test.mocks.dart';

void main() {
  late DHTClient client;
  late MockRouterInterface mockRouter;
  late MockNetworkHandler mockNetworkHandler;
  late MockIPFSNode mockNode;
  late MockDHTHandler mockDhtHandler;
  late MockDatastore mockStorage;
  late MetricsCollector metrics;
  late IPFSConfig config;

  setUp(() {
    mockRouter = MockRouterInterface();
    mockNetworkHandler = MockNetworkHandler();
    mockNode = MockIPFSNode();
    mockDhtHandler = MockDHTHandler();
    mockStorage = MockDatastore();
    config = IPFSConfig();
    metrics = MetricsCollector(config);

    when(mockNetworkHandler.ipfsNode).thenReturn(mockNode);
    when(mockNetworkHandler.config).thenReturn(config);
    when(mockNode.dhtHandler).thenReturn(mockDhtHandler);
    when(mockDhtHandler.router).thenReturn(mockRouter);
    when(mockDhtHandler.storage).thenReturn(mockStorage);

    when(
      mockRouter.peerID,
    ).thenReturn('QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn');

    client = DHTClient(
      networkHandler: mockNetworkHandler,
      router: mockRouter,
      metricsCollector: metrics,
    );
  });

  /// Mocks the same-stream request/response exchange: [router].sendRequest
  /// returns [response] encoded as raw kad protobuf — the wire form every
  /// libp2p-kad-dht implementation speaks.
  void mockRawResponse(MockRouterInterface router, kad.Message response) {
    when(
      router.sendRequest(any, any, any),
    ).thenAnswer((invocation) async => response.writeToBuffer());
  }

  group('DHTClient integration spec', () {
    test('requests use raw kad protobuf on the same stream', () async {
      await client.initialize();
      final peer = PeerId.fromBase58(
        'QmP8j68w7u6vYpx4BNDPqVvR2Y6a8VvX8v8v8v8v8v8v',
      );
      final target = PeerId.fromBase58(
        'QmP8j68w7u6vYpx4BNDPqVvR2Y6a8VvX8v8v8v8v8v8w',
      );
      await client.kademliaRoutingTable.addPeer(peer, peer);

      final sentDatagrams = <Uint8List>[];
      final response = kad.Message()
        ..type = kad.Message_MessageType.FIND_NODE
        ..closerPeers.add(kad.Peer()..id = target.value);

      when(mockRouter.sendRequest(any, any, any)).thenAnswer((
        invocation,
      ) async {
        sentDatagrams.add(invocation.positionalArguments[2] as Uint8List);
        return response.writeToBuffer();
      });

      final result = await client.findPeer(target);
      expect(result, isNotNull);
      // The wire request must be a raw kad.Message — no DHTEnvelope
      // framing — so Kubo/Helia can parse it.
      final request = kad.Message.fromBuffer(sentDatagrams.first);
      expect(request.type, kad.Message_MessageType.FIND_NODE);
    });

    test('findProviders returns validated provider records', () async {
      await client.initialize();
      final peer = PeerId.fromBase58(
        'QmP8j68w7u6vYpx4BNDPqVvR2Y6a8VvX8v8v8v8v8v8v',
      );
      await client.kademliaRoutingTable.addPeer(peer, peer);

      final provider = PeerId.fromBase58(
        'QmP8j68w7u6vYpx4BNDPqVvR2Y6a8VvX8v8v8v8v8v8w',
      );
      final response = kad.Message()
        ..type = kad.Message_MessageType.GET_PROVIDERS
        ..providerPeers.add(
          kad.Peer()
            ..id = provider.value
            ..addrs.add(libp2p.MultiAddr('/ip4/127.0.0.1/tcp/4001').toBytes()),
        );

      mockRawResponse(mockRouter, response);

      final providers = await client.findProviders(
        'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn',
      );
      expect(providers, isNotEmpty);
      expect(providers.any((p) => p.toBase58() == provider.toBase58()), isTrue);
    });

    test('findProviders drops providers without valid multiaddrs', () async {
      await client.initialize();
      final peer = PeerId.fromBase58(
        'QmP8j68w7u6vYpx4BNDPqVvR2Y6a8VvX8v8v8v8v8v8v',
      );
      await client.kademliaRoutingTable.addPeer(peer, peer);

      final provider = PeerId.fromBase58(
        'QmP8j68w7u6vYpx4BNDPqVvR2Y6a8VvX8v8v8v8v8v8w',
      );
      final response = kad.Message()
        ..type = kad.Message_MessageType.GET_PROVIDERS
        ..providerPeers.add(kad.Peer()..id = provider.value);

      mockRawResponse(mockRouter, response);

      final providers = await client.findProviders(
        'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn',
      );
      expect(providers, isEmpty);
    });

    test('findProviders expands iteratively via closer peers', () async {
      await client.initialize();
      final seedPeer = PeerId.fromBase58(
        'QmP8j68w7u6vYpx4BNDPqVvR2Y6a8VvX8v8v8v8v8v8v',
      );
      final closerPeer = PeerId.fromBase58(
        'QmP8j68w7u6vYpx4BNDPqVvR2Y6a8VvX8v8v8v8v8v8w',
      );
      await client.kademliaRoutingTable.addPeer(seedPeer, seedPeer);

      final provider = PeerId.fromBase58(
        'QmP8j68w7u6vYpx4BNDPqVvR2Y6a8VvX8v8v8v8v8v8x',
      );
      var requestCount = 0;

      when(mockRouter.sendRequest(any, any, any)).thenAnswer((
        invocation,
      ) async {
        requestCount++;

        final response = kad.Message()
          ..type = kad.Message_MessageType.GET_PROVIDERS;

        // On the first request (to seedPeer), return closerPeer.
        // On the second request (to closerPeer), return provider.
        if (requestCount == 1) {
          response.closerPeers.add(kad.Peer()..id = closerPeer.value);
        } else {
          response.providerPeers.add(
            kad.Peer()
              ..id = provider.value
              ..addrs.add(
                libp2p.MultiAddr('/ip4/127.0.0.1/tcp/4001').toBytes(),
              ),
          );
        }

        return response.writeToBuffer();
      });

      final providers = await client.findProviders(
        'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn',
      );
      expect(providers, isNotEmpty);
      expect(providers.any((p) => p.toBase58() == provider.toBase58()), isTrue);
      expect(requestCount, greaterThanOrEqualTo(2));
    });

    test('findPeer iterates until target is discovered', () async {
      await client.initialize();
      final seedPeer = PeerId.fromBase58(
        'QmP8j68w7u6vYpx4BNDPqVvR2Y6a8VvX8v8v8v8v8v8v',
      );
      final target = PeerId.fromBase58(
        'QmP8j68w7u6vYpx4BNDPqVvR2Y6a8VvX8v8v8v8v8v8w',
      );
      await client.kademliaRoutingTable.addPeer(seedPeer, seedPeer);

      final response = kad.Message()
        ..type = kad.Message_MessageType.FIND_NODE
        ..closerPeers.add(kad.Peer()..id = target.value);

      mockRawResponse(mockRouter, response);

      final result = await client.findPeer(target);
      expect(result, isNotNull);
      expect(result!.toBase58(), equals(target.toBase58()));
    });

    test('addProvider encodes addresses as multiaddr bytes', () async {
      await client.initialize();
      final peer = PeerId.fromBase58(
        'QmP8j68w7u6vYpx4BNDPqVvR2Y6a8VvX8v8v8v8v8v8v',
      );
      await client.kademliaRoutingTable.addPeer(peer, peer);
      when(
        mockRouter.resolvePeerId(client.peerId.toBase58()),
      ).thenReturn(['/ip4/127.0.0.1/tcp/4001']);

      final response = kad.Message()
        ..type = kad.Message_MessageType.ADD_PROVIDER;
      mockRawResponse(mockRouter, response);

      await client.addProvider(
        'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn',
        client.peerId.toBase58(),
      );

      final captured = verify(
        mockRouter.sendMessage(
          captureAny,
          captureAny,
          protocolId: anyNamed('protocolId'),
        ),
      ).captured;
      final msg = kad.Message.fromBuffer(captured.last as Uint8List);
      expect(msg.providerPeers, isNotEmpty);
      expect(msg.providerPeers.first.addrs, isNotEmpty);

      final addr = libp2p.MultiAddr.fromBytes(
        Uint8List.fromList(msg.providerPeers.first.addrs.first),
      );
      expect(addr.toString(), '/ip4/127.0.0.1/tcp/4001');
    });

    test('reprovide enumerates stored keys and records metrics', () async {
      await client.initialize();
      when(mockStorage.query(any)).thenAnswer((_) => const Stream.empty());

      await expectLater(client.reprovide(), completes);
      verify(mockStorage.query(any)).called(1);
    });

    test('addProvider sends to closest peers in batches', () async {
      await client.initialize();
      final peers = List.generate(5, (i) {
        final bytes = Uint8List(32)..[0] = i;
        return PeerId(value: bytes);
      });
      for (final peer in peers) {
        await client.kademliaRoutingTable.addPeer(peer, peer);
      }

      final sentTo = <String>{};
      when(
        mockRouter.sendMessage(any, any, protocolId: anyNamed('protocolId')),
      ).thenAnswer((invocation) async {
        sentTo.add(invocation.positionalArguments[0] as String);
      });

      await client
          .addProvider(
            'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn',
            client.peerId.toBase58(),
          )
          .timeout(const Duration(milliseconds: 100), onTimeout: () {});

      expect(sentTo.length, greaterThanOrEqualTo(1));
    });
  });
}
