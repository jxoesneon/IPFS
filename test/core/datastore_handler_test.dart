import 'dart:typed_data';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/link.dart';
import 'package:dart_ipfs/src/core/data_structures/merkle_dag_node.dart';
import 'package:dart_ipfs/src/core/ipfs_node/datastore_handler.dart';
import 'package:dart_ipfs/src/core/storage/datastore.dart';
import 'package:dart_ipfs/src/utils/car_reader.dart';
import 'package:test/test.dart';

import '../mocks/in_memory_datastore.dart';

// Mock datastore that fails on operations
class FailingDatastore extends InMemoryDatastore {
  @override
  Future<void> init() async => throw Exception('Init failed');

  @override
  Future<void> close() async => throw Exception('Close failed');

  @override
  Future<void> put(Key key, Uint8List value) async =>
      throw Exception('Put failed');

  @override
  Future<Uint8List?> get(Key key) async => throw Exception('Get failed');

  @override
  Future<bool> has(Key key) async => throw Exception('Has failed');

  @override
  Future<void> delete(Key key) async => throw Exception('Delete failed');

  @override
  Stream<QueryEntry> query(Query q) async* {
    throw Exception('Query failed');
  }
}

void main() {
  group('DatastoreHandler Tests', () {
    late InMemoryDatastore datastore;
    late DatastoreHandler handler;

    setUp(() async {
      datastore = InMemoryDatastore();
      await datastore.init();
      handler = DatastoreHandler(datastore);
      await handler.start();
    });

    tearDown(() async {
      await handler.stop();
    });

    test('should put and get blocks', () async {
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final block = await Block.fromData(data);
      final cid = block.cid.toString();

      await handler.putBlock(block);

      expect(await handler.hasBlock(cid), isTrue);

      final retrieved = await handler.getBlock(cid);
      expect(retrieved, isNotNull);
      expect(retrieved!.data, equals(data));
      expect(retrieved!.cid.toString(), equals(cid));
    });

    test('should handle missing blocks', () async {
      final result = await handler.getBlock('nonexistent');
      expect(result, isNull);
      expect(await handler.hasBlock('nonexistent'), isFalse);
    });

    test('should persist and load pinned CIDs', () async {
      final pins = {'cid1', 'cid2', 'cid3'};

      await handler.persistPinnedCIDs(pins);

      final loadedPins = await handler.loadPinnedCIDs();
      expect(loadedPins, equals(pins));

      // Verify in underlying datastore
      expect(await datastore.has(Key('/pins/cid1')), isTrue);

      // Update pins (should clear old ones)
      await handler.persistPinnedCIDs({'cid4'});
      final updatedPins = await handler.loadPinnedCIDs();
      expect(updatedPins, equals({'cid4'}));
      expect(await datastore.has(Key('/pins/cid1')), isFalse);
    });

    test('should report status', () async {
      await handler.persistPinnedCIDs({'p1', 'p2'});

      final status = await handler.getStatus();
      expect(status['status'], equals('active'));
      expect(status['pinned_blocks'], equals(2));
    });

    test('should handle import and export of CAR files', () async {
      // Create some blocks
      final data1 = Uint8List.fromList([65, 66, 67]); // 'ABC'
      final block1 = await Block.fromData(data1);
      final cid1 = block1.cid.toString();

      await handler.putBlock(block1);

      // Export CAR
      final carData = await handler.exportCAR(cid1);
      expect(carData, isNotEmpty);

      // Clear datastore and re-import
      await datastore.close();
      datastore = InMemoryDatastore(); // Reset
      await datastore.init();
      handler = DatastoreHandler(datastore); // Reset Handler

      expect(await handler.hasBlock(cid1), isFalse);

      await handler.importCAR(carData);

      expect(await handler.hasBlock(cid1), isTrue);
      final retrieved = await handler.getBlock(cid1);
      expect(retrieved!.data, equals(data1));
    });

    test('should recursively export dag-pb blocks in CAR', () async {
      // Create a leaf block (Raw)
      final leafData = Uint8List.fromList([1, 2, 3]);
      final leafBlock = await Block.fromData(leafData); // Raw by default?
      // Block.fromData sets format? Let's assume raw.
      await handler.putBlock(leafBlock);

      // Create a parent block (ProtoNode) linking to leaf
      final parentNode = MerkleDAGNode(
        data: Uint8List(0),
        links: [
          Link(cid: leafBlock.cid, name: 'leaf', size: leafBlock.data.length),
        ],
      );
      final parentBlock = Block(
        cid: await parentNode.cid,
        data: parentNode.toBytes(),
        format: 'dag-pb',
      );
      await handler.putBlock(parentBlock);

      // Export CAR from parent
      final carData = await handler.exportCAR(parentBlock.cid.encode());
      expect(carData, isNotEmpty);

      // Verify CAR contains both blocks
      final reader = await CarReader.readCar(carData);
      expect(reader.blocks.length, equals(2));
      final cids = reader.blocks.map((b) => b.cid.encode()).toList();
      expect(cids, contains(leafBlock.cid.encode()));
      expect(cids, contains(parentBlock.cid.encode()));
    });

    test('handles putBlock error', () async {
      handler = DatastoreHandler(FailingDatastore());
      await handler.putBlock(await Block.fromData(Uint8List(0)));
    });

    test('handles getBlock error', () async {
      handler = DatastoreHandler(FailingDatastore());
      final result = await handler.getBlock('QmSomeCid');
      expect(result, isNull);
    });

    test('handles hasBlock error', () async {
      handler = DatastoreHandler(FailingDatastore());
      final result = await handler.hasBlock('QmSomeCid');
      expect(result, isFalse);
    });

    test('handles start error', () async {
      handler = DatastoreHandler(FailingDatastore());
      await handler.start(); // Should catch exception
    });

    test('handles stop error', () async {
      handler = DatastoreHandler(FailingDatastore());
      await handler.stop(); // Should catch exception
    });

    test('handles loadPinnedCIDs error', () async {
      handler = DatastoreHandler(FailingDatastore());
      final result = await handler.loadPinnedCIDs();
      expect(result, isEmpty);
    });

    test('handles persistPinnedCIDs error', () async {
      handler = DatastoreHandler(FailingDatastore());
      await handler.persistPinnedCIDs({'cid1'}); // Should catch exception
    });

    test('handles importCAR error', () async {
      handler = DatastoreHandler(FailingDatastore());
      await handler.importCAR(Uint8List(0)); // Should catch exception
    });

    test('handles exportCAR error', () async {
      handler = DatastoreHandler(FailingDatastore());
      final result = await handler.exportCAR('QmSomeCid');
      expect(result, isEmpty);
    });
  });
}
