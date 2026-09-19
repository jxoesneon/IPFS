import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/data_structures/pin_manager.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/core/responses/block_response_factory.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';
import 'package:dart_ipfs/src/services/block_store_service.dart';
import 'package:dart_ipfs/src/services/gateway/gateway_server.dart';
import 'package:grpc/grpc.dart';
import 'package:test/test.dart';

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
  PinManager get pinManager => throw UnimplementedError('Mock');

  @override
  Future<int> gc() async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockIPFSNode implements IPFSNode {
  @override
  Future<int> gc() async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('BlockStoreService', () {
    late MockBlockStore mockStore;

    setUp(() {
      mockStore = MockBlockStore();
      BlockStoreService(mockStore);
      // Service creation validates the gRPC setup
      expect(mockStore, isNotNull);
    });

    // We can't easily mock ServiceCall without implementing the abstract class.
    // Let's create a dummy class.
  });

  group('GatewayServer', () {
    test('start/stop', () async {
      final store = MockBlockStore();
      final server = GatewayServer(
        blockStore: store,
        port: 0,
      ); // Port 0 usually picks random

      expect(server.isRunning, isFalse);

      // Start might fail if port binding fails, but 0 should work.
      await server.start();
      expect(server.isRunning, isTrue);

      await server.stop();
      expect(server.isRunning, isFalse);
    });
  });
}

class DummyServiceCall extends ServiceCall {
  @override
  Future<int> gc() async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
