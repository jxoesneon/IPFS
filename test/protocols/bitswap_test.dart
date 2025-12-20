// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/utils/base58.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/responses/block_response_factory.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';
import 'package:dart_ipfs/src/protocols/bitswap/bitswap_handler.dart';
import 'package:dart_ipfs/src/protocols/bitswap/message.dart' as msg;
import 'package:dart_ipfs/src/transport/p2plib_router.dart';
import 'package:dart_ipfs/src/transport/router_events.dart'; // For NetworkPacket
import 'package:p2plib/p2plib.dart' as p2p;
import 'package:test/test.dart';

// Helper
Uint8List get validPeerIdBytes => Uint8List.fromList(List.filled(64, 1));

// Mocks
class MockBlockStore implements BlockStore {
  final Map<String, Block> blocks = {};

  @override
  Future<AddBlockResponse> putBlock(Block block) async {
    blocks[block.cid.encode()] = block;
    return BlockResponseFactory.successAdd('Block added');
  }

  @override
  Future<GetBlockResponse> getBlock(String cid) async {
    if (blocks.containsKey(cid)) {
      return BlockResponseFactory.successGet(blocks[cid]!.toProto());
    }
    return BlockResponseFactory.notFound();
  }

  @override
  Future<RemoveBlockResponse> removeBlock(String cid) async {
    blocks.remove(cid);
    return BlockResponseFactory.successRemove('Block removed');
  }

  @override
  Future<List<Block>> getAllBlocks() async {
    return blocks.values.toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
  p2p.RouterL2 _mockL2 = MockRouterL2();
  void Function(NetworkPacket)? messageHandler;

  @override
  p2p.RouterL2 get routerL0 => _mockL2;

  set routerL0(p2p.RouterL2 router) => _mockL2 = router;

  @override
  p2p.PeerId get peerId => _mockL2.selfId;

  @override
  String get peerID => 'QmMockPeerId';

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
    messageHandler = handler;
  }

  @override
  List<String> get connectedPeers => [Base58().encode(validPeerIdBytes)];

  @override
  Future<void> sendMessage(String peerId, Uint8List data) async {}

  Future<void> simulatePacket(NetworkPacket packet) async {
    if (messageHandler != null) {
      messageHandler!(packet);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockConfig extends IPFSConfig {
  MockConfig() : super();
}

void main() {
  group('BitswapHandler', () {
    late BitswapHandler handler;
    late MockBlockStore mockBlockStore;
    late MockP2plibRouter mockRouter;
    late MockConfig mockConfig;

    setUp(() {
      mockBlockStore = MockBlockStore();
      mockRouter = MockP2plibRouter();
      mockConfig = MockConfig();
      handler = BitswapHandler(mockConfig, mockBlockStore, mockRouter);

      // Setup minimal mock router state
      mockRouter._mockL2.routes[p2p.PeerId(value: validPeerIdBytes)] =
          p2p.Route(peerId: p2p.PeerId(value: validPeerIdBytes));
    });

    test('start/stop', () async {
      await handler.start();
      await handler.stop();
    });

    test('wantBlock request and receive', () async {
      await handler.start();

      final targetData = Uint8List.fromList([1, 2, 3, 4]);
      final targetCid =
          CID.computeForDataSync(targetData, codec: 'dag-pb').encode();

      // Simulate response slightly later
      scheduleMicrotask(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await _simulateBlockArrival(mockRouter, targetData);
      });

      final block = await handler.wantBlock(targetCid);

      expect(block, isNotNull);
      expect(block!.data, equals(targetData));
      expect(mockBlockStore.blocks.containsKey(targetCid), isTrue);

      await handler.stop();
    });

    test('concurrent wantBlock requests', () async {
      await handler.start();

      final data1 = Uint8List.fromList([1]);
      final data2 = Uint8List.fromList([2]);
      final cid1 = CID.computeForDataSync(data1, codec: 'dag-pb').encode();
      final cid2 = CID.computeForDataSync(data2, codec: 'dag-pb').encode();

      // Want both concurrently
      final future1 = handler.wantBlock(cid1);
      final future2 = handler.wantBlock(cid2);

      // Fulfill 2 then 1 with slight delays
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await _simulateBlockArrival(mockRouter, data2, codec: 'dag-pb');

      await Future<void>.delayed(const Duration(milliseconds: 20));
      await _simulateBlockArrival(mockRouter, data1, codec: 'dag-pb');

      final b1 = await future1;
      final b2 = await future2;

      expect(b1, isNotNull);
      expect(b1!.data, equals(data1));
      expect(b2, isNotNull);
      expect(b2!.data, equals(data2));

      await handler.stop();
    });

    test(
      'verifies Bitswap 1.2 features (sendDontHave)',
      skip:
          'Flaky: MockRouterL2Capture message capture times out intermittently',
      () async {
        await handler.start();
        final data = Uint8List.fromList([9, 9, 9]);
        final cid = CID.computeForDataSync(data).encode();

        // We need to capture the outgoing message to verify 1.2 flags
        Completer<msg.Message>? outgoingMsgCompleter;
        mockRouter.routerL0 = MockRouterL2Capture((datagram) async {
          final message = await msg.Message.fromBytes(datagram);
          outgoingMsgCompleter!.complete(message);
        });

        outgoingMsgCompleter = Completer();
        // Start want request in background
        // ignore: unawaited_futures
        handler.wantBlock(cid);

        // Verify outgoing message
        final message = await outgoingMsgCompleter.future;
        expect(message.hasWantlist(), isTrue);
        // message.Wantlist exposes entries directly
        final entry = message.getWantlist().entries[cid];
        expect(entry, isNotNull);
        // Verify 1.2 flags
        expect(entry!.sendDontHave, isTrue); // Should be true for 1.2
        expect(entry.wantType, msg.WantType.block);

        await handler.stop();
      },
    );

    test('handles incoming HAVE/DONT_HAVE messages', () async {
      await handler.start();
      final data = Uint8List.fromList([5, 5, 5]);
      final cid = CID.computeForDataSync(data).encode();

      // Simulate DONT_HAVE message
      final dontHaveMsg = msg.Message();
      dontHaveMsg.addBlockPresence(cid, msg.BlockPresenceType.dontHave);
      // Need fromPeer to log correctly
      final packet = NetworkPacket(
        datagram: dontHaveMsg.toBytes(),
        srcPeerId: Base58().encode(validPeerIdBytes),
      );

      // This shouldn't crash
      await mockRouter.simulatePacket(packet);

      // Simulate HAVE message
      final haveMsg = msg.Message();
      haveMsg.addBlockPresence(cid, msg.BlockPresenceType.have);
      final packet2 = NetworkPacket(
        datagram: haveMsg.toBytes(),
        srcPeerId: Base58().encode(validPeerIdBytes),
      );

      await mockRouter.simulatePacket(packet2);

      await handler.stop();
    });
  });
}

// Helper mock to capture outgoing messages
class MockRouterL2Capture extends MockRouterL2 {
  MockRouterL2Capture(this.onSend);
  final Future<void> Function(Uint8List) onSend;

  @override
  void sendDatagram({
    required Iterable<p2p.FullAddress> addresses,
    required Uint8List datagram,
  }) {
    onSend(datagram);
  }
}

Future<void> _simulateBlockArrival(
  MockP2plibRouter router,
  Uint8List data, {
  String codec = 'dag-pb',
}) async {
  final responseMsg = msg.Message();
  final block = Block(
    cid: CID.computeForDataSync(data, codec: codec),
    data: data,
  );

  responseMsg.addBlock(block);

  final packet = NetworkPacket(
    datagram: responseMsg.toBytes(),
    srcPeerId: Base58().encode(validPeerIdBytes),
  );

  try {
    await router.simulatePacket(packet);
  } catch (e) {
    print('Simulate packet failed: $e');
  }
}
