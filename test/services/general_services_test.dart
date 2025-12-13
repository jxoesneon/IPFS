import 'dart:async';
import 'dart:typed_data';
import 'package:dart_ipfs/src/services/block_store_service.dart';
import 'package:dart_ipfs/src/services/content_service.dart';
import 'package:dart_ipfs/src/services/gateway/gateway_server.dart';
import 'package:dart_ipfs/src/storage/datastore.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:grpc/grpc.dart';
import 'package:test/test.dart';

import 'package:dart_ipfs/src/core/responses/block_response_factory.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';

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

class MockDatastore implements Datastore {
  final Map<String, Uint8List> data = {};
  final Set<String> pinned = {};

  @override
  Future<void> put(String key, Block value) async {
    data[key] = value.data;
  }

  @override
  Future<Block?> get(String key) async {
    if (!data.containsKey(key)) return null;
    return Block(cid: CID.decode(key), data: data[key]!);
  }

  @override
  Future<void> delete(String key) async {
    data.remove(key);
  }

  @override
  Future<void> pin(String key) async {
    pinned.add(key);
  }

  @override
  Future<void> unpin(String key) async {
    pinned.remove(key);
  }

  @override
  Future<bool> isPinned(String key) async => pinned.contains(key);

  @override
  Future<bool> has(String key) async => data.containsKey(key);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockIPFSNode implements IPFSNode {
  // implements IPFSNode means we don't call super
  // But we need to define all members that might be called or use noSuchMethod.

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('BlockStoreService', () {
    late BlockStoreService service;
    late MockBlockStore mockStore;
    late ServiceCall mockCall; // Usually can be null for tests if not used

    setUp(() {
      mockStore = MockBlockStore();
      service = BlockStoreService(mockStore);
      // Hack: mock call can be null if not used by implementation?
      // Library expects ServiceCall, but maybe we can mock it.
      // Or pass null if type allows (it doesn't usually).
      // We'll see if we can pass a dummy.
    });

    // We can't easily mock ServiceCall without implementing the abstract class.
    // Let's create a dummy class.
  });

  group('ContentService', () {
    late ContentService service;
    late MockDatastore mockDatastore;

    setUp(() {
      mockDatastore = MockDatastore();
      service = ContentService(mockDatastore);
    });

    test('store and get content', () async {
      final data = Uint8List.fromList([1, 2, 3]);
      final cid = await service.storeContent(data);

      expect(mockDatastore.data, isNotEmpty);

      final retrieved = await service.getContent(cid);
      expect(retrieved, equals(data));

      final has = await service.hasContent(cid);
      expect(has, isTrue);
    });

    test('pin content', () async {
      final data = Uint8List.fromList([1]);
      final cid = await service.storeContent(data);

      await service.pinContent(cid);
      expect(mockDatastore.pinned, contains(cid.encode()));

      final removed = await service.removeContent(cid);
      expect(removed, isFalse); // Can't remove pinned

      await service.unpinContent(cid);
      expect(mockDatastore.pinned, isEmpty);

      await service.removeContent(cid);
      expect(mockDatastore.data, isEmpty);
    });
  });

  group('GatewayServer', () {
    test('start/stop', () async {
      final store = MockBlockStore();
      final server = GatewayServer(
          blockStore: store, port: 0); // Port 0 usually picks random

      expect(server.isRunning, isFalse);

      // Start might fail if port binding fails, but 0 should work.
      await server.start();
      expect(server.isRunning, isTrue);
      // print(server.url);

      await server.stop();
      expect(server.isRunning, isFalse);
    });
  });

  /*
  group('RPCServer', () {
     // Mocking IPFSNode for RPCHandlers is complex because handlers access many fields.
     // We might skip deep unit testing of RPCServer logic and focus on start/stop.
     // But RPCHandlers constructor will try to access node fields? 
     // RPCHandlers(node).
     // I'll skip if it requires huge mock setup.
  });
  */
}

class DummyServiceCall extends ServiceCall {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
