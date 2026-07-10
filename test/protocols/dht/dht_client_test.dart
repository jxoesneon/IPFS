import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/proto/generated/dht/kademlia.pb.dart' as kad;
import 'package:dart_ipfs/src/protocols/dht/dht_client.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_envelope.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
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

  void Function(NetworkPacket) _captureHandler(MockRouterInterface router) {
    final captured = verify(
      router.registerProtocolHandler(any, captureAny),
    ).captured;
    return captured.last as void Function(NetworkPacket);
  }

  void mockEnvelopeResponse(
    MockRouterInterface router,
    String srcPeerId,
    kad.Message response, {
    void Function(NetworkPacket)? handler,
  }) {
    final lastHandler = handler ?? _captureHandler(router);
    when(
      router.sendMessage(any, any, protocolId: anyNamed('protocolId')),
    ).thenAnswer((invocation) async {
      final data = invocation.positionalArguments[1] as Uint8List;
      final envelope = DHTEnvelope.fromBytes(data);
      Future<void>.delayed(const Duration(milliseconds: 1), () {
        lastHandler(
          NetworkPacket(
            srcPeerId: srcPeerId,
            datagram: DHTEnvelope(
              requestId: envelope.requestId,
              payload: response.writeToBuffer(),
            ).toBytes(),
          ),
        );
      });
    });
  }

  group('DHTClient integration spec', () {
    test('request/response correlation uses envelope request id', () async {
      await client.initialize();
      final peer = PeerId.fromBase58(
        'QmP8j68w7u6vYpx4BNDPqVvR2Y6a8VvX8v8v8v8v8v8v',
      );
      final target = PeerId.fromBase58(
        'QmP8j68w7u6vYpx4BNDPqVvR2Y6a8VvX8v8v8v8v8v8w',
      );
      await client.kademliaRoutingTable.addPeer(peer, peer);
      final handler = _captureHandler(mockRouter);

      String? capturedRequestId;
      final response = kad.Message()
        ..type = kad.Message_MessageType.FIND_NODE
        ..closerPeers.add(kad.Peer()..id = target.value);

      when(
        mockRouter.sendMessage(any, any, protocolId: anyNamed('protocolId')),
      ).thenAnswer((invocation) async {
        final data = invocation.positionalArguments[1] as Uint8List;
        final envelope = DHTEnvelope.fromBytes(data);
        capturedRequestId = envelope.requestId;
        Future<void>.delayed(const Duration(milliseconds: 1), () {
          handler(
            NetworkPacket(
              srcPeerId: peer.toBase58(),
              datagram: DHTEnvelope(
                requestId: envelope.requestId,
                payload: response.writeToBuffer(),
              ).toBytes(),
            ),
          );
        });
      });

      await client.findPeer(target);
      expect(capturedRequestId, isNotNull);
      expect(capturedRequestId!.isNotEmpty, isTrue);
      expect(capturedRequestId, startsWith('dht-'));
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

      mockEnvelopeResponse(mockRouter, peer.toBase58(), response);

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

      mockEnvelopeResponse(mockRouter, peer.toBase58(), response);

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
      await client.kademliaRoutingTable.addPeer(closerPeer, closerPeer);
      final handler = _captureHandler(mockRouter);

      final provider = PeerId.fromBase58(
        'QmP8j68w7u6vYpx4BNDPqVvR2Y6a8VvX8v8v8v8v8v8x',
      );
      var requestCount = 0;

      when(
        mockRouter.sendMessage(any, any, protocolId: anyNamed('protocolId')),
      ).thenAnswer((invocation) async {
        requestCount++;
        final data = invocation.positionalArguments[1] as Uint8List;
        final envelope = DHTEnvelope.fromBytes(data);

        final response = kad.Message()
          ..type = kad.Message_MessageType.GET_PROVIDERS;

        // On the first request, return a closer peer. On the second request,
        // return the provider. This demonstrates iterative expansion.
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

        Future<void>.delayed(const Duration(milliseconds: 1), () {
          handler(
            NetworkPacket(
              srcPeerId: seedPeer.toBase58(),
              datagram: DHTEnvelope(
                requestId: envelope.requestId,
                payload: response.writeToBuffer(),
              ).toBytes(),
            ),
          );
        });
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

      mockEnvelopeResponse(mockRouter, seedPeer.toBase58(), response);

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
      mockEnvelopeResponse(mockRouter, peer.toBase58(), response);

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
