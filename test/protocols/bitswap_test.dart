import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:p2plib/p2plib.dart' as p2p;
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/protocols/bitswap/bitswap_handler.dart';
import 'package:dart_ipfs/src/transport/p2plib_router.dart';
import 'package:dart_ipfs/src/protocols/bitswap/message.dart' as msg;
import 'package:dart_ipfs/src/core/responses/block_response_factory.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';
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
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
  Function(p2p.Packet)? messageHandler;

  @override
  p2p.RouterL2 get routerL0 => _mockL2;

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
  void addMessageHandler(String protocolId, void Function(p2p.Packet) handler) {
    messageHandler = handler;
  }

  Future<void> simulatePacket(p2p.Packet packet) async {
    if (messageHandler != null) {
      await messageHandler!(packet);
    }
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
        await Future.delayed(Duration(milliseconds: 50));
        _simulateBlockArrival(mockRouter, targetData);
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
      await Future.delayed(Duration(milliseconds: 20));
      await _simulateBlockArrival(mockRouter, data2, codec: 'dag-pb');

      await Future.delayed(Duration(milliseconds: 20));
      await _simulateBlockArrival(mockRouter, data1, codec: 'dag-pb');

      final b1 = await future1;
      final b2 = await future2;

      expect(b1, isNotNull);
      expect(b1!.data, equals(data1));
      expect(b2, isNotNull);
      expect(b2!.data, equals(data2));

      await handler.stop();
    });
  });
}

Future<void> _simulateBlockArrival(MockP2plibRouter router, Uint8List data,
    {String codec = 'dag-pb'}) async {
  final responseMsg = msg.Message();
  final block =
      Block(cid: CID.computeForDataSync(data, codec: codec), data: data);

  responseMsg.addBlock(block);

  final packet = p2p.Packet(
    datagram: responseMsg.toBytes(),
    header: p2p.PacketHeader(id: 1234, issuedAt: 0),
    srcFullAddress:
        p2p.FullAddress(address: InternetAddress.loopbackIPv4, port: 1234),
  );
  packet.srcPeerId = p2p.PeerId(value: validPeerIdBytes);

  try {
    await router.simulatePacket(packet);
  } catch (e) {
    print('Simulate packet failed: $e');
  }
}
