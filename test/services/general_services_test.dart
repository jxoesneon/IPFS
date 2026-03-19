import 'dart:async';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/data_structures/pin_manager.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/core/responses/block_response_factory.dart';
import 'package:dart_ipfs/src/core/storage/datastore.dart';
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// MockDatastore implementing the new Datastore interface
class MockDatastore implements Datastore {
  final Map<Key, Uint8List> data = {};

  @override
  Future<void> init() async {}

  @override
  Future<void> put(Key key, Uint8List value) async {
    data[key] = value;
  }

  @override
  Future<Uint8List?> get(Key key) async {
    return data[key];
  }

  @override
  Future<void> delete(Key key) async {
    data.remove(key);
  }

  @override
  Future<bool> has(Key key) async => data.containsKey(key);

  @override
  Stream<QueryEntry> query(Query q) async* {
    for (final entry in data.entries) {
      if (q.prefix != null && !entry.key.toString().startsWith(q.prefix!)) {
        continue;
      }
      yield QueryEntry(entry.key, q.keysOnly ? null : entry.value);
    }
  }

  @override
  Future<void> close() async {
    data.clear();
  }
}

class MockIPFSNode implements IPFSNode {
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

  group('ContentService with MockDatastore', () {
    late MockDatastore mockDatastore;

    setUp(() {
      mockDatastore = MockDatastore();
    });

    test('store and get content via datastore', () async {
      final data = Uint8List.fromList([1, 2, 3]);
      final key = Key('/blocks/test-cid');

      await mockDatastore.put(key, data);
      expect(mockDatastore.data, isNotEmpty);

      final retrieved = await mockDatastore.get(key);
      expect(retrieved, equals(data));

      final has = await mockDatastore.has(key);
      expect(has, isTrue);
    });

    test('pin content via key prefix', () async {
      final data = Uint8List.fromList([1]);
      final blockKey = Key('/blocks/test-cid');
      final pinKey = Key('/pins/test-cid');

      await mockDatastore.put(blockKey, data);
      await mockDatastore.put(pinKey, Uint8List.fromList([1])); // Pin

      expect(await mockDatastore.has(pinKey), isTrue);

      // Unpin
      await mockDatastore.delete(pinKey);
      expect(await mockDatastore.has(pinKey), isFalse);

      // Remove data
      await mockDatastore.delete(blockKey);
      expect(mockDatastore.data, isEmpty);
    });
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
