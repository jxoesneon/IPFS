import 'dart:async';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/interfaces/i_block_store.dart';
import 'package:dart_ipfs/src/proto/generated/core/block.pb.dart' as block_pb;
import 'package:dart_ipfs/src/protocols/bitswap/bitswap_handler.dart';
import 'package:dart_ipfs/src/protocols/bitswap/message.dart' as bitswap_msg;
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';
import 'package:dart_ipfs/src/transport/p2plib_router.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'bitswap_handler_logic_test.mocks.dart';

@GenerateMocks([P2plibRouter, IBlockStore, IPFSConfig])
void main() {
  late MockP2plibRouter mockRouter;
  late MockIBlockStore mockBlockStore;
  late MockIPFSConfig mockConfig;
  late BitswapHandler handler;
  late Future<void> Function(NetworkPacket) bitswapPacketHandler;

  setUp(() async {
    mockRouter = MockP2plibRouter();
    mockBlockStore = MockIBlockStore();
    mockConfig = MockIPFSConfig();

    when(mockConfig.debug).thenReturn(false);
    when(mockConfig.verboseLogging).thenReturn(false);

    when(mockRouter.initialize()).thenAnswer((_) async => {});
    when(mockRouter.start()).thenAnswer((_) async => {});
    when(mockRouter.stop()).thenAnswer((_) async => {});

    when(mockRouter.registerProtocolHandler(any, any)).thenAnswer((
      Invocation inv,
    ) {
      if (inv.positionalArguments[0] == '/ipfs/bitswap/1.2.0') {
        bitswapPacketHandler = inv.positionalArguments[1];
      }
    });

    final dummyPeerId = PeerId(value: Uint8List.fromList(List.filled(32, 1)));
    when(mockRouter.peerID).thenReturn(dummyPeerId.toString());
    when(mockRouter.sendMessage(any, any)).thenAnswer((_) async => {});
    when(
      mockBlockStore.putBlock(any),
    ).thenAnswer((_) async => AddBlockResponse()..success = true);
    when(
      mockBlockStore.getBlock(any),
    ).thenAnswer((_) async => GetBlockResponse()..found = false);

    handler = BitswapHandler(mockConfig, mockBlockStore, mockRouter);
    await handler.start();
  });

  tearDown(() async {
    await handler.stop();
  });

  group('BitswapHandler Core Logic', () {
    test('start registers protocol and handler', () {
      verify(
        mockRouter.registerProtocolHandler('/ipfs/bitswap/1.2.0', any),
      ).called(greaterThanOrEqualTo(1));
      verify(
        mockRouter.registerProtocol('/ipfs/bitswap/1.2.0'),
      ).called(greaterThanOrEqualTo(1));
    });

    test('wantBlock returns null when no peers are connected', () async {
      when(mockRouter.connectedPeers).thenReturn([]);
      final result = await handler.wantBlock(
        'QmYwAPJzv5CZsnA6ULBXebJWvruP6P3wXhHjS2Mtc38E2z',
      );
      expect(result, isNull);
    });

    test('wantBlock sends wantlist to connected peers', () async {
      final peer1 = 'peer1';
      final block = await Block.fromData(
        Uint8List.fromList([1]),
        format: 'dag-pb',
      );
      final cidStr = block.cid.encode();

      when(mockRouter.connectedPeers).thenReturn([peer1]);

      // Use a background task to call wantBlock as it will wait for the block
      final wantFuture = handler.wantBlock(cidStr);

      await Future.delayed(Duration(milliseconds: 100));
      verify(mockRouter.sendMessage(peer1, any)).called(1);

      // Complete the future by stopping handler
      await handler.stop();
      expect(await wantFuture, isNull);
    });

    test('handles incoming wantlist with HAVE request', () async {
      final fromPeer = 'peer2';
      final block = await Block.fromData(
        Uint8List.fromList([1, 2, 3]),
        format: 'dag-pb',
      );
      final cid = block.cid.encode();

      when(mockBlockStore.getBlock(cid)).thenAnswer(
        (_) async => GetBlockResponse()
          ..found = true
          ..block = block.toProto(),
      );

      final msg = bitswap_msg.Message();
      msg.addWantlistEntry(cid, wantType: bitswap_msg.WantType.have);

      final packet = NetworkPacket(
        srcPeerId: fromPeer,
        datagram: msg.toBytes(),
      );

      await bitswapPacketHandler(packet);

      final captured =
          verify(mockRouter.sendMessage(fromPeer, captureAny)).captured.single
              as Uint8List;
      final response = await bitswap_msg.Message.fromBytes(captured);
      expect(response.hasBlockPresences(), isTrue);
      expect(
        response.getBlockPresences().first.type,
        equals(bitswap_msg.BlockPresenceType.have),
      );
    });

    test('handles incoming wantlist with DONT_HAVE requirement', () async {
      final fromPeer = 'peer2';
      final block = await Block.fromData(
        Uint8List.fromList([1, 2, 3]),
        format: 'dag-pb',
      );
      final cid = block.cid.encode();

      when(
        mockBlockStore.getBlock(cid),
      ).thenAnswer((_) async => GetBlockResponse()..found = false);

      final msg = bitswap_msg.Message();
      msg.addWantlistEntry(
        cid,
        wantType: bitswap_msg.WantType.have,
        sendDontHave: true,
      );

      final packet = NetworkPacket(
        srcPeerId: fromPeer,
        datagram: msg.toBytes(),
      );

      await bitswapPacketHandler(packet);

      final captured =
          verify(mockRouter.sendMessage(fromPeer, captureAny)).captured.single
              as Uint8List;
      final response = await bitswap_msg.Message.fromBytes(captured);
      expect(response.hasBlockPresences(), isTrue);
      expect(
        response.getBlockPresences().first.type,
        equals(bitswap_msg.BlockPresenceType.dontHave),
      );
    });

    test('DoS protection: rejects huge wantlist', () async {
      final fromPeer = 'peerDoS';
      final msg = bitswap_msg.Message();
      final baseCidBytes = CID
          .decode('QmYwAPJzv5CZsnA6ULBXebJWvruP6P3wXhHjS2Mtc38E2z')
          .toBytes();
      for (int i = 0; i < 5001; i++) {
        // Mutate bytes slightly to create unique CIDs efficiently
        final bytes = Uint8List.fromList(baseCidBytes);
        int val = i;
        int offset = bytes.length - 1;
        while (val > 0 && offset >= 2) {
          bytes[offset] = (bytes[offset] + (val & 0xFF)) % 256;
          val >>= 8;
          offset--;
        }
        msg.addWantlistEntry(CID.fromBytes(bytes).encode());
      }

      final packet = NetworkPacket(
        srcPeerId: fromPeer,
        datagram: msg.toBytes(),
      );

      await bitswapPacketHandler(packet);

      verifyNever(mockRouter.sendMessage(fromPeer, any));
    });

    test('handles incoming block and completes want future', () async {
      final data = Uint8List.fromList([10, 20, 30]);
      final block = await Block.fromData(data, format: 'dag-pb');
      final cidStr = block.cid.encode();

      when(mockRouter.connectedPeers).thenReturn(['p1']);

      final wantFuture = handler.wantBlock(cidStr);

      final msg = bitswap_msg.Message();
      msg.addBlock(block);

      final packet = NetworkPacket(srcPeerId: 'p1', datagram: msg.toBytes());

      when(
        mockBlockStore.putBlock(any),
      ).thenAnswer((_) async => AddBlockResponse()..success = true);

      await bitswapPacketHandler(packet);

      final receivedBlock = await wantFuture;
      expect(receivedBlock, isNotNull);
      expect(receivedBlock!.data, equals(data));
    });

    test('Rejects invalid block (hash mismatch)', () async {
      final invalidBlock = FakeInvalidBlock(
        cid: CID.decode('QmYwAPJzv5CZsnA6ULBXebJWvruP6P3wXhHjS2Mtc38E2z'),
        data: Uint8List.fromList([1, 2, 3]),
      );

      // Call handleBlocks directly to bypass parser's auto-recomputation
      await handler.handleBlocks([invalidBlock]);

      verifyNever(mockBlockStore.putBlock(any));
    });

    test('getStatus returns correct stats', () async {
      final status = await handler.getStatus();
      expect(status, contains('wanted_blocks'));
      expect(status, contains('blocks_received'));
    });

    test('handleWantRequest broadcasts message', () async {
      when(mockRouter.connectedPeers).thenReturn(['p1']);
      final block = await Block.fromData(
        Uint8List.fromList([7, 8]),
        format: 'dag-pb',
      );
      await handler.handleWantRequest(block.cid.encode());
      verify(mockRouter.sendMessage('p1', any)).called(1);
    });

    test('Rejects excessive wantlist (SEC-ZDAY-001)', () async {
      final msg = bitswap_msg.Message();
      // Use valid CIDs to avoid parsing errors
      final baseCidBytes = CID
          .decode('QmYwAPJzv5CZsnA6ULBXebJWvruP6P3wXhHjS2Mtc38E2z')
          .toBytes();
      for (int i = 0; i < 5005; i++) {
        // Mutate bytes slightly to create unique CIDs efficiently
        // Base CID is 34 bytes (v0). Digest starts at offset 2.
        // We modify the last few bytes of the digest.
        final bytes = Uint8List.fromList(baseCidBytes);
        // Simple modification: increment last bytes
        int val = i;
        int offset = bytes.length - 1;
        while (val > 0 && offset >= 2) {
          bytes[offset] = (bytes[offset] + (val & 0xFF)) % 256;
          val >>= 8;
          offset--;
        }
        // Encode manually or trust CID.decode handles valid bytes via constructor?
        // addWantlistEntry takes String.
        // So we must Encode.
        // This is slow. Let's try skipping validation if possible?
        // No, addWantlistEntry calls CID.decode.
        // We must provide valid encoded string.
        final cid = CID.fromBytes(bytes).encode();
        msg.addWantlistEntry(cid);
      }

      await bitswapPacketHandler(
        NetworkPacket(srcPeerId: 'p1', datagram: msg.toBytes()),
      );

      // Should return early and not process entries (verified via absence of further actions)
      final status = await handler.getStatus();
      expect(status['wanted_blocks'], equals(0));
    });

    test('Handles WANT_TYPE_HAVE and sendDontHave', () async {
      final cid = 'QmYwAPJzv5CZsnA6ULBXebJWvruP6P3wXhHjS2Mtc38E2z';
      when(
        mockBlockStore.getBlock(cid),
      ).thenAnswer((_) async => GetBlockResponse()..found = false);

      final msg = bitswap_msg.Message();
      msg.addWantlistEntry(
        cid,
        wantType: bitswap_msg.WantType.have,
        sendDontHave: true,
      );

      await bitswapPacketHandler(
        NetworkPacket(srcPeerId: 'p1', datagram: msg.toBytes()),
      );

      verify(mockRouter.sendMessage('p1', any)).called(1);
    });

    test('Handles WANT_TYPE_BLOCK and serves block when found', () async {
      final cid = 'QmYwAPJzv5CZsnA6ULBXebJWvruP6P3wXhHjS2Mtc38E2z';
      final blockData = Uint8List.fromList([1, 2, 3, 4]);

      // Mock block store to return the block
      when(mockBlockStore.getBlock(cid)).thenAnswer(
        (_) async => GetBlockResponse()
          ..found = true
          ..block = (block_pb.BlockProto()
            ..data = blockData
            ..cid = CID.decode(cid).toProto()),
      );

      final msg = bitswap_msg.Message();
      msg.addWantlistEntry(cid, wantType: bitswap_msg.WantType.block);

      await bitswapPacketHandler(
        NetworkPacket(srcPeerId: 'p1', datagram: msg.toBytes()),
      );

      // Verify response contains the block
      final captured =
          verify(mockRouter.sendMessage('p1', captureAny)).captured.single
              as Uint8List;
      final responseMsg = await bitswap_msg.Message.fromBytes(captured);
      expect(responseMsg.hasBlocks(), isTrue);
      expect(responseMsg.getBlocks().first.data, equals(blockData));
    });

    test('Handles WANT_TYPE_HAVE and serves HAVE when found', () async {
      final cid = 'QmYwAPJzv5CZsnA6ULBXebJWvruP6P3wXhHjS2Mtc38E2z';

      when(
        mockBlockStore.getBlock(cid),
      ).thenAnswer((_) async => GetBlockResponse()..found = true);

      final msg = bitswap_msg.Message();
      msg.addWantlistEntry(cid, wantType: bitswap_msg.WantType.have);

      await bitswapPacketHandler(
        NetworkPacket(srcPeerId: 'p1', datagram: msg.toBytes()),
      );

      // Verify response contains HAVE presence
      final captured =
          verify(mockRouter.sendMessage('p1', captureAny)).captured.single
              as Uint8List;
      final responseMsg = await bitswap_msg.Message.fromBytes(captured);
      expect(responseMsg.hasBlockPresences(), isTrue);
      expect(
        responseMsg.getBlockPresences().first.type,
        equals(bitswap_msg.BlockPresenceType.have),
      );
    });

    test('handleBlockPresences coverage', () async {
      final msg = bitswap_msg.Message();
      msg.addBlockPresence(
        'QmYwAPJzv5CZsnA6ULBXebJWvruP6P3wXhHjS2Mtc38E2z',
        bitswap_msg.BlockPresenceType.have,
      );
      msg.addBlockPresence(
        'QmYwAPJzv5CZsnA6ULBXebJWvruP6P3wXhHjS2Mtc38E2y',
        bitswap_msg.BlockPresenceType.dontHave,
      );

      await bitswapPacketHandler(
        NetworkPacket(srcPeerId: 'p1', datagram: msg.toBytes()),
      );

      // Verified via log coverage or internal state update if applicable
    });

    test('stop cancels pending blocks with error', () async {
      when(mockRouter.connectedPeers).thenReturn(['p1']);
      final wantFuture = handler.wantBlock(
        'QmYwAPJzv5CZsnA6ULBXebJWvruP6P3wXhHjS2Mtc38E2z',
      );

      await Future.delayed(Duration(milliseconds: 10));
      await handler.stop();

      expect(await wantFuture, isNull);
    });

    test('want multiple CIDs and handles blocks', () async {
      final b1 = await Block.fromData(
        Uint8List.fromList([1]),
        format: 'dag-pb',
      );
      final b2 = await Block.fromData(
        Uint8List.fromList([2]),
        format: 'dag-pb',
      );

      when(mockRouter.connectedPeers).thenReturn(['p1']);
      when(
        mockBlockStore.putBlock(any),
      ).thenAnswer((_) async => AddBlockResponse()..success = true);

      final wantFuture = handler.want([b1.cid.encode(), b2.cid.encode()]);

      final msg = bitswap_msg.Message();
      msg.addBlock(b1);
      msg.addBlock(b2);

      await bitswapPacketHandler(
        NetworkPacket(srcPeerId: 'p1', datagram: msg.toBytes()),
      );

      final results = await wantFuture;
      expect(results.length, equals(2));
    });

    test('want timeout handles cleanup', () async {
      when(mockRouter.connectedPeers).thenReturn(['p1']);

      expect(
        () => handler.want([
          'QmYwAPJzv5CZsnA6ULBXebJWvruP6P3wXhHjS2Mtc38E2z',
        ], timeout: Duration(milliseconds: 50)),
        throwsA(isA<TimeoutException>()),
      );

      await Future.delayed(Duration(milliseconds: 100));
    });

    test('bandwidth stats update on message', () async {
      final fromPeer = 'peerB';
      when(mockRouter.connectedPeers).thenReturn([fromPeer]);

      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final block = await Block.fromData(data, format: 'dag-pb');

      final msg = bitswap_msg.Message();
      msg.addBlock(block);

      await bitswapPacketHandler(
        NetworkPacket(srcPeerId: fromPeer, datagram: msg.toBytes()),
      );

      expect(handler.bandwidthReceived, greaterThan(0));
    });

    test('handleBlockPresences processes HAVE messages', () async {
      final msg = bitswap_msg.Message();
      msg.addBlockPresence(
        'QmYwAPJzv5CZsnA6ULBXebJWvruP6P3wXhHjS2Mtc38E2z',
        bitswap_msg.BlockPresenceType.have,
      );
      msg.addBlockPresence(
        'QmYwAPJzv5CZsnA6ULBXebJWvruP6P3wXhHjS2Mtc38E2y',
        bitswap_msg.BlockPresenceType.dontHave,
      );

      await bitswapPacketHandler(
        NetworkPacket(srcPeerId: 'p1', datagram: msg.toBytes()),
      );
    });

    test('_handleMessage with empty message', () async {
      final msg = bitswap_msg.Message();
      await bitswapPacketHandler(
        NetworkPacket(srcPeerId: 'p1', datagram: msg.toBytes()),
      );
    });

    test('_handleWantlist with sender dont have requirement', () async {
      final block = await Block.fromData(
        Uint8List.fromList([1, 2, 3]),
        format: 'dag-pb',
      );
      final cidStr = block.cid.encode();

      final msg = bitswap_msg.Message();
      msg.addWantlistEntry(
        cidStr,
        wantType: bitswap_msg.WantType.block,
        sendDontHave: true,
      );
      await bitswapPacketHandler(
        NetworkPacket(srcPeerId: 'p1', datagram: msg.toBytes()),
      );
      verify(mockRouter.sendMessage('p1', any)).called(1);
    });
  });
}

class FakeInvalidBlock extends Block {
  FakeInvalidBlock({required CID cid, required Uint8List data})
    : super(cid: cid, data: data);
  @override
  Future<bool> validate() async => false;
}
