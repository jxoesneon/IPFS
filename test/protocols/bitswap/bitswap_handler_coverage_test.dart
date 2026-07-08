import 'dart:async';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dart_ipfs/src/protocols/bitswap/bitswap_handler.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/interfaces/i_block_store.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/protocols/bitswap/message.dart' as message;
import 'package:dart_ipfs/src/transport/router_events.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';

import 'bitswap_handler_coverage_test.mocks.dart';

@GenerateNiceMocks([MockSpec<IBlockStore>(), MockSpec<RouterInterface>()])
void main() {
  late BitswapHandler handler;
  late MockIBlockStore mockBlockStore;
  late MockRouterInterface mockRouter;
  late IPFSConfig config;

  setUp(() {
    mockBlockStore = MockIBlockStore();
    mockRouter = MockRouterInterface();
    config = IPFSConfig();
    handler = BitswapHandler(config, mockBlockStore, mockRouter);

    // Default to a local block miss so tests that exercise P2P/HTTP paths
    // do not trigger unstubbed mock fakes.
    when(
      mockBlockStore.getBlock(any),
    ).thenAnswer((_) async => GetBlockResponse(found: false));
  });

  group('BitswapHandler', () {
    test('start/stop lifecycle', () async {
      await handler.start();
      expect(await handler.getStatus(), containsPair('wanted_blocks', 0));
      await handler.stop();
    });

    test('wantBlock requests block and completes', () async {
      await handler.start();
      final blockData = Uint8List.fromList([1, 2, 3]);
      final cid = await CID.computeForData(blockData);
      final cidStr = cid.encode();

      when(mockRouter.connectedPeers).thenReturn({'peerA'});

      // Simulate incoming block via handler
      Timer(Duration(milliseconds: 100), () async {
        final block = Block(cid: cid, data: blockData);
        await handler.handleBlocks([block]);
      });

      final result = await handler.wantBlock(cidStr);
      expect(result, isNotNull);
      expect(result!.data, equals([1, 2, 3]));
    });

    test('handlePacket processes incoming wantlist', () async {
      await handler.start();
      final capturedHandler =
          verify(
                mockRouter.registerProtocolHandler(any, captureAny),
              ).captured.last
              as Function(NetworkPacket);

      final blockData = Uint8List.fromList([4, 5, 6]);
      final cid = await CID.computeForData(blockData);
      final cidStr = cid.encode();

      final msg = message.Message();
      msg.addWantlistEntry(
        cidStr,
        priority: 10,
        wantType: message.WantType.block,
      );

      final packet = NetworkPacket(srcPeerId: 'peerA', datagram: msg.toBytes());

      final mockResponse = GetBlockResponse(
        found: true,
        block: (Block(cid: cid, data: blockData)).toProto(),
      );
      when(mockBlockStore.getBlock(any)).thenAnswer((_) async => mockResponse);
      when(mockRouter.peerID).thenReturn('localPeer');

      await capturedHandler(packet);

      verify(
        mockRouter.sendMessage(
          'peerA',
          any,
          protocolId: anyNamed('protocolId'),
        ),
      ).called(1);
    });

    test('handlePacket processes incoming HAVE wantlist', () async {
      await handler.start();
      final capturedHandler =
          verify(
                mockRouter.registerProtocolHandler(any, captureAny),
              ).captured.last
              as Function(NetworkPacket);

      final blockData = Uint8List.fromList([7, 8, 9]);
      final cid = await CID.computeForData(blockData);
      final cidStr = cid.encode();

      final msg = message.Message();
      msg.addWantlistEntry(
        cidStr,
        priority: 10,
        wantType: message.WantType.have,
      );

      final packet = NetworkPacket(srcPeerId: 'peerB', datagram: msg.toBytes());

      when(
        mockBlockStore.getBlock(any),
      ).thenAnswer((_) async => GetBlockResponse(found: true));
      when(mockRouter.peerID).thenReturn('localPeer');

      await capturedHandler(packet);

      verify(
        mockRouter.sendMessage(
          'peerB',
          any,
          protocolId: anyNamed('protocolId'),
        ),
      ).called(1);
    });

    test('wantBlock timeout', () async {
      await handler.start();
      final cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      when(mockRouter.connectedPeers).thenReturn({'peerA'});

      // want() rethrows TimeoutException when no peer responds within timeout.
      await expectLater(
        handler.want([cid], timeout: const Duration(milliseconds: 100)),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('handleBlocks rejects invalid blocks', () async {
      final cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      final block = Block(
        cid: CID.decode(cid),
        data: Uint8List.fromList([1, 2, 3, 4]),
      ); // Wrong data for this CID

      await handler.handleBlocks([block]);

      verifyNever(mockBlockStore.putBlock(any));
    });

    test('want multiple blocks', () async {
      await handler.start();
      final data1 = Uint8List.fromList([1, 1, 1]);
      final cid1 = await CID.computeForData(data1);
      final data2 = Uint8List.fromList([2, 2, 2]);
      final cid2 = await CID.computeForData(data2);

      when(mockRouter.connectedPeers).thenReturn({'peerA'});

      Timer(Duration(milliseconds: 100), () async {
        await handler.handleBlocks([
          Block(cid: cid1, data: data1),
          Block(cid: cid2, data: data2),
        ]);
      });

      final results = await handler.want([cid1.encode(), cid2.encode()]);
      expect(results.length, equals(2));
      expect(results[0].data, equals(data1));
      expect(results[1].data, equals(data2));
    });

    test('handleMessage with blocks updates ledger', () async {
      await handler.start();
      final data = Uint8List.fromList([1, 2, 3]);
      final cid = await CID.computeForData(data);

      final msg = message.Message();
      msg.addBlock(Block(cid: cid, data: data));

      final packet = NetworkPacket(srcPeerId: 'peerA', datagram: msg.toBytes());
      final capturedHandler =
          verify(
                mockRouter.registerProtocolHandler(any, captureAny),
              ).captured.last
              as Function(NetworkPacket);

      await capturedHandler(packet);

      expect(handler.bandwidthReceived, equals(3));
    });

    test('handleBlockPresences logging', () async {
      await handler.start();
      final msg = message.Message();
      msg.addBlockPresence('QmSomeCid', message.BlockPresenceType.have);

      final packet = NetworkPacket(srcPeerId: 'peerA', datagram: msg.toBytes());
      final capturedHandler =
          verify(
                mockRouter.registerProtocolHandler(any, captureAny),
              ).captured.last
              as Function(NetworkPacket);

      await capturedHandler(packet);
      // Verify no crash
    });

    test('handleWantRequest broadcasts', () async {
      await handler.start();
      when(mockRouter.connectedPeers).thenReturn({'peerA'});

      await handler.handleWantRequest('QmSomeCid');
      verify(
        mockRouter.sendMessage(
          'peerA',
          any,
          protocolId: anyNamed('protocolId'),
        ),
      ).called(1);
    });

    test('stop clears pending blocks with error', () async {
      await handler.start();
      final cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      when(mockRouter.connectedPeers).thenReturn({'peerA'});

      final future = handler.wantBlock(cid);
      await Future.delayed(Duration(milliseconds: 50));
      await handler.stop();

      final result = await future;
      expect(result, isNull); // wantBlock catches error and returns null
    });

    test('handleWantlist rejects excessive entries', () async {
      await handler.start();
      final capturedHandler =
          verify(
                mockRouter.registerProtocolHandler(any, captureAny),
              ).captured.last
              as Function(NetworkPacket);

      final msg = message.Message();
      for (int i = 0; i < 5001; i++) {
        msg.addWantlistEntry('QmSomeCid$i', priority: 1);
      }

      final packet = NetworkPacket(srcPeerId: 'peerA', datagram: msg.toBytes());
      await capturedHandler(packet);

      verifyNever(mockRouter.sendMessage('peerA', any));
    });

    test('want throws StateError if no peers', () async {
      await handler.start();
      when(mockRouter.connectedPeers).thenReturn({});

      await expectLater(handler.want(['QmSomeCid']), throwsStateError);
    });

    test('handleWantlist sends DONT_HAVE if requested', () async {
      await handler.start();
      final capturedHandler =
          verify(
                mockRouter.registerProtocolHandler(any, captureAny),
              ).captured.last
              as Function(NetworkPacket);

      // Clear previous calls like registerProtocol, initialize, etc.
      clearInteractions(mockRouter);
      when(mockRouter.peerID).thenReturn('local');

      final blockData = Uint8List.fromList([7, 8, 9]);
      final cid = await CID.computeForData(blockData);
      final cidStr = cid.encode();

      final msg = message.Message();
      msg.addWantlistEntry(
        cidStr,
        priority: 10,
        wantType: message.WantType.have,
        sendDontHave: true,
      );

      final packet = NetworkPacket(srcPeerId: 'peerB', datagram: msg.toBytes());

      when(
        mockBlockStore.getBlock(any),
      ).thenAnswer((_) async => GetBlockResponse(found: false));

      await capturedHandler(packet);

      verify(
        mockRouter.sendMessage(
          'peerB',
          any,
          protocolId: anyNamed('protocolId'),
        ),
      ).called(1);
    });

    test('start when already running returns early', () async {
      await handler.start();
      await handler.start(); // Should return early without error
      expect(await handler.getStatus(), containsPair('wanted_blocks', 0));
    });

    test('stop when not running returns early', () async {
      await handler.stop(); // Should not throw
    });

    test('start error handling', () async {
      when(mockRouter.initialize()).thenThrow(Exception('Init error'));
      await expectLater(handler.start(), throwsException);
    });

    test('stop error handling', () async {
      when(mockRouter.stop()).thenThrow(Exception('Stop error'));
      await handler.stop(); // Should catch error and not throw
    });

    test('want when not running throws StateError', () async {
      await expectLater(handler.want(['QmSomeCid']), throwsStateError);
    });

    test('want with duplicate CID', () async {
      await handler.start();
      final data = Uint8List.fromList([1, 2, 3]);
      final cid = await CID.computeForData(data);
      final cidStr = cid.encode();
      when(mockRouter.connectedPeers).thenReturn({'peerA'});

      // Request the same CID twice - second should skip adding duplicate
      Timer(Duration(milliseconds: 100), () async {
        await handler.handleBlocks([Block(cid: cid, data: data)]);
      });

      final results = await handler.want([cidStr, cidStr]);
      expect(
        results.length,
        equals(1),
      ); // Only one result since duplicate was skipped
    });

    test('handleWantRequest error handling', () async {
      await handler.start();
      when(mockRouter.connectedPeers).thenReturn({});

      await expectLater(
        handler.handleWantRequest('QmSomeCid'),
        throwsStateError,
      );
    });

    test('wantBlock when not running throws StateError', () async {
      await expectLater(handler.wantBlock('QmSomeCid'), throwsStateError);
    });

    test('wantBlock error handling returns null', () async {
      await handler.start();
      when(mockRouter.connectedPeers).thenReturn({});

      final result = await handler.wantBlock('QmSomeCid');
      expect(result, isNull);
    });

    test('handleWantlist with empty wantlist', () async {
      await handler.start();
      final capturedHandler =
          verify(
                mockRouter.registerProtocolHandler(any, captureAny),
              ).captured.last
              as Function(NetworkPacket);

      final msg = message.Message();
      // Empty wantlist

      final packet = NetworkPacket(srcPeerId: 'peerA', datagram: msg.toBytes());
      when(mockRouter.peerID).thenReturn('localPeer');

      await capturedHandler(packet); // Should handle empty wantlist gracefully
    });
  });
}
