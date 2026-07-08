// test/protocols/bitswap/bitswap_http_fallback_test.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/bitswap_config.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/interfaces/i_block_store.dart';
import 'package:dart_ipfs/src/core/responses/block_response_factory.dart';
import 'package:dart_ipfs/src/protocols/bitswap/bitswap_handler.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';
import 'package:dart_ipfs/src/transport/http_gateway_client.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'bitswap_handler_coverage_test.mocks.dart';

void main() {
  group('BitswapHandler HTTP fallback', () {
    late MockIBlockStore mockBlockStore;
    late MockRouterInterface mockRouter;

    setUp(() {
      mockBlockStore = MockIBlockStore();
      mockRouter = MockRouterInterface();
      when(
        mockBlockStore.putBlock(any),
      ).thenAnswer((_) async => BlockResponseFactory.successAdd('stored'));
    });

    IPFSConfig _fallbackConfig(
      List<String> gateways, {
      bool verify = true,
      bool allowPrivate = false,
      int maxBlockSize = 2 * 1024 * 1024,
      bool enabled = true,
    }) => IPFSConfig(
      bitswap: BitswapConfig(
        enableHttpFallback: enabled,
        httpFallbackGateways: gateways,
        p2pTimeout: const Duration(milliseconds: 50),
        httpTimeout: const Duration(milliseconds: 100),
        maxHttpBlockSize: maxBlockSize,
        allowPrivateGateways: allowPrivate,
        verifyHttpBlocks: verify,
      ),
    );

    Future<Block> _validBlock() async {
      final data = Uint8List.fromList(utf8.encode('hello http fallback'));
      return Block.fromData(data);
    }

    test('returns cached block without P2P or HTTP', () async {
      final block = await _validBlock();
      when(mockBlockStore.getBlock(any)).thenAnswer(
        (_) async => BlockResponseFactory.successGet(block.toProto()),
      );
      when(mockRouter.connectedPeers).thenReturn(<String>{});

      final config = _fallbackConfig([], enabled: false);
      final handler = BitswapHandler(config, mockBlockStore, mockRouter);
      await handler.start();

      final result = await handler.wantBlock(block.cid.encode());
      expect(result, isNotNull);
      expect(result!.data, equals(block.data));
      verify(
        mockBlockStore.getBlock(block.cid.encode()),
      ).called(greaterThan(0));
      verifyNever(
        mockRouter.sendMessage(any, any, protocolId: anyNamed('protocolId')),
      );

      await handler.stop();
    });

    test('uses P2P when available and skips HTTP', () async {
      final block = await _validBlock();
      when(
        mockBlockStore.getBlock(any),
      ).thenAnswer((_) async => BlockResponseFactory.notFound());
      when(mockRouter.connectedPeers).thenReturn(<String>{'peerA'});

      final config = _fallbackConfig([]);
      final handler = BitswapHandler(config, mockBlockStore, mockRouter);
      await handler.start();

      Timer(const Duration(milliseconds: 10), () async {
        await handler.handleBlocks([block]);
      });

      final result = await handler.wantBlock(block.cid.encode());
      expect(result, isNotNull);
      expect(result!.data, equals(block.data));
      // The P2P-received block is validated and stored in the blockstore.
      verify(mockBlockStore.putBlock(any)).called(greaterThan(0));

      await handler.stop();
    });

    test('falls back to HTTP gateway after P2P failure', () async {
      final block = await _validBlock();
      final cidStr = block.cid.encode();
      when(
        mockBlockStore.getBlock(any),
      ).thenAnswer((_) async => BlockResponseFactory.notFound());
      when(mockRouter.connectedPeers).thenReturn(<String>{});

      final mockHttp = MockClient((request) async {
        if (request.url.toString() ==
            'https://ipfs.io/ipfs/$cidStr?format=raw') {
          return http.Response.bytes(block.data, 200);
        }
        return http.Response('Not Found', 404);
      });
      final httpClient = HttpGatewayClient(client: mockHttp);

      final config = _fallbackConfig(['https://ipfs.io']);
      final handler = BitswapHandler(
        config,
        mockBlockStore,
        mockRouter,
        httpGatewayClient: httpClient,
      );
      await handler.start();

      final result = await handler.wantBlock(cidStr);
      expect(result, isNotNull);
      expect(result!.data, equals(block.data));
      verify(mockBlockStore.putBlock(any)).called(1);

      await handler.stop();
    });

    test('discards HTTP block that fails CID verification', () async {
      final block = await _validBlock();
      final cidStr = block.cid.encode();
      when(
        mockBlockStore.getBlock(any),
      ).thenAnswer((_) async => BlockResponseFactory.notFound());
      when(mockRouter.connectedPeers).thenReturn(<String>{});

      final mockHttp = MockClient((request) async {
        return http.Response.bytes(Uint8List.fromList([0, 1, 2, 3]), 200);
      });
      final httpClient = HttpGatewayClient(client: mockHttp);

      final config = _fallbackConfig(['https://ipfs.io']);
      final handler = BitswapHandler(
        config,
        mockBlockStore,
        mockRouter,
        httpGatewayClient: httpClient,
      );
      await handler.start();

      final result = await handler.wantBlock(cidStr);
      expect(result, isNull);
      verifyNever(mockBlockStore.putBlock(any));

      await handler.stop();
    });

    test('retries next gateway after first fails', () async {
      final block = await _validBlock();
      final cidStr = block.cid.encode();
      when(
        mockBlockStore.getBlock(any),
      ).thenAnswer((_) async => BlockResponseFactory.notFound());
      when(mockRouter.connectedPeers).thenReturn(<String>{});

      final mockHttp = MockClient((request) async {
        final url = request.url.toString();
        if (url.contains('bad.gateway')) {
          return http.Response('Server Error', 500);
        }
        if (url.contains('good.gateway')) {
          return http.Response.bytes(block.data, 200);
        }
        return http.Response('Not Found', 404);
      });
      final httpClient = HttpGatewayClient(client: mockHttp);

      final config = _fallbackConfig([
        'https://bad.gateway',
        'https://good.gateway',
      ]);
      final handler = BitswapHandler(
        config,
        mockBlockStore,
        mockRouter,
        httpGatewayClient: httpClient,
      );
      await handler.start();

      final result = await handler.wantBlock(cidStr);
      expect(result, isNotNull);
      expect(result!.data, equals(block.data));

      await handler.stop();
    });

    test('caches verified HTTP block and returns it on next request', () async {
      final block = await _validBlock();
      final cidStr = block.cid.encode();
      var getBlockCalls = 0;
      when(mockBlockStore.getBlock(any)).thenAnswer((_) async {
        getBlockCalls++;
        if (getBlockCalls == 1) {
          return BlockResponseFactory.notFound();
        }
        return BlockResponseFactory.successGet(block.toProto());
      });
      when(mockRouter.connectedPeers).thenReturn(<String>{});

      final mockHttp = MockClient((request) async {
        return http.Response.bytes(block.data, 200);
      });
      final httpClient = HttpGatewayClient(client: mockHttp);

      final config = _fallbackConfig(['https://ipfs.io']);
      final handler = BitswapHandler(
        config,
        mockBlockStore,
        mockRouter,
        httpGatewayClient: httpClient,
      );
      await handler.start();

      final first = await handler.wantBlock(cidStr);
      expect(first, isNotNull);

      final second = await handler.wantBlock(cidStr);
      expect(second, isNotNull);
      expect(second!.data, equals(block.data));
      expect(getBlockCalls, greaterThanOrEqualTo(2));

      await handler.stop();
    });

    test(
      'verifyHttpBlocks false skips verification and stores bad block',
      () async {
        final block = await _validBlock();
        final cidStr = block.cid.encode();
        final badData = Uint8List.fromList([0, 1, 2]);
        when(
          mockBlockStore.getBlock(any),
        ).thenAnswer((_) async => BlockResponseFactory.notFound());
        when(mockRouter.connectedPeers).thenReturn(<String>{});

        final mockHttp = MockClient((request) async {
          return http.Response.bytes(badData, 200);
        });
        final httpClient = HttpGatewayClient(client: mockHttp);

        final config = _fallbackConfig(['https://ipfs.io'], verify: false);
        final handler = BitswapHandler(
          config,
          mockBlockStore,
          mockRouter,
          httpGatewayClient: httpClient,
        );
        await handler.start();

        final result = await handler.wantBlock(cidStr);
        expect(result, isNotNull);
        expect(result!.data, equals(badData));
        verify(mockBlockStore.putBlock(any)).called(1);

        await handler.stop();
      },
    );

    test('rejects private gateway unless allowed', () async {
      final block = await _validBlock();
      final cidStr = block.cid.encode();
      when(
        mockBlockStore.getBlock(any),
      ).thenAnswer((_) async => BlockResponseFactory.notFound());
      when(mockRouter.connectedPeers).thenReturn(<String>{});

      final mockHttp = MockClient((request) async {
        return http.Response.bytes(block.data, 200);
      });
      final httpClient = HttpGatewayClient(client: mockHttp);

      final deniedConfig = _fallbackConfig([
        'http://127.0.0.1:8080',
      ], allowPrivate: false);
      final deniedHandler = BitswapHandler(
        deniedConfig,
        mockBlockStore,
        mockRouter,
        httpGatewayClient: httpClient,
      );
      await deniedHandler.start();
      final denied = await deniedHandler.wantBlock(cidStr);
      expect(denied, isNull);
      await deniedHandler.stop();

      final allowedConfig = _fallbackConfig([
        'http://127.0.0.1:8080',
      ], allowPrivate: true);
      final allowedHandler = BitswapHandler(
        allowedConfig,
        mockBlockStore,
        mockRouter,
        httpGatewayClient: httpClient,
      );
      await allowedHandler.start();
      final allowed = await allowedHandler.wantBlock(cidStr);
      expect(allowed, isNotNull);
      await allowedHandler.stop();
    });

    test('rejects HTTP block larger than maxHttpBlockSize', () async {
      final block = await _validBlock();
      final cidStr = block.cid.encode();
      final bigData = Uint8List(1024);
      when(
        mockBlockStore.getBlock(any),
      ).thenAnswer((_) async => BlockResponseFactory.notFound());
      when(mockRouter.connectedPeers).thenReturn(<String>{});

      final mockHttp = MockClient((request) async {
        return http.Response.bytes(bigData, 200);
      });
      final httpClient = HttpGatewayClient(client: mockHttp);

      final config = _fallbackConfig(['https://ipfs.io'], maxBlockSize: 512);
      final handler = BitswapHandler(
        config,
        mockBlockStore,
        mockRouter,
        httpGatewayClient: httpClient,
      );
      await handler.start();

      final result = await handler.wantBlock(cidStr);
      expect(result, isNull);
      verifyNever(mockBlockStore.putBlock(any));

      await handler.stop();
    });

    test('does not use HTTP fallback when disabled', () async {
      final block = await _validBlock();
      final cidStr = block.cid.encode();
      when(
        mockBlockStore.getBlock(any),
      ).thenAnswer((_) async => BlockResponseFactory.notFound());
      when(mockRouter.connectedPeers).thenReturn(<String>{});

      var httpCalled = false;
      final mockHttp = MockClient((request) async {
        httpCalled = true;
        return http.Response.bytes(block.data, 200);
      });
      final httpClient = HttpGatewayClient(client: mockHttp);

      final config = IPFSConfig(
        bitswap: BitswapConfig(
          enableHttpFallback: false,
          httpFallbackGateways: const ['https://ipfs.io'],
          p2pTimeout: const Duration(milliseconds: 50),
        ),
      );
      final handler = BitswapHandler(
        config,
        mockBlockStore,
        mockRouter,
        httpGatewayClient: httpClient,
      );
      await handler.start();

      final result = await handler.wantBlock(cidStr);
      expect(result, isNull);
      expect(httpCalled, isFalse);

      await handler.stop();
    });

    test(
      'getBlock useHttpFallback=false skips HTTP after P2P failure',
      () async {
        final block = await _validBlock();
        final cidStr = block.cid.encode();
        when(
          mockBlockStore.getBlock(any),
        ).thenAnswer((_) async => BlockResponseFactory.notFound());
        when(mockRouter.connectedPeers).thenReturn(<String>{});

        final mockHttp = MockClient((request) async {
          return http.Response.bytes(block.data, 200);
        });
        final httpClient = HttpGatewayClient(client: mockHttp);

        final config = _fallbackConfig(['https://ipfs.io']);
        final handler = BitswapHandler(
          config,
          mockBlockStore,
          mockRouter,
          httpGatewayClient: httpClient,
        );
        await handler.start();

        final result = await handler.getBlock(cidStr, useHttpFallback: false);
        expect(result, isNull);

        await handler.stop();
      },
    );
  });
}
