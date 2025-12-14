// test/mocks/mock_integration_test.dart
import 'package:test/test.dart';
import 'package:dart_ipfs/src/protocols/dht/Interface_dht_handler.dart';
import 'package:dart_ipfs/src/storage/datastore.dart';
import 'in_memory_datastore.dart';
import 'mock_dht_handler.dart';
import 'test_helpers.dart';

/// Integration test validating that our mock infrastructure works together.
///
/// This test proves that:
/// 1. InMemoryDatastore solves the Hive blocker
/// 2. MockDHTHandler implements IDHTHandler correctly
/// 3. Mocks can be used together in integration tests
void main() {
  group('Mock Infrastructure Integration', () {
    late MockDHTHandler dhtHandler;
    late InMemoryDatastore datastore;

    setUp(() async {
      datastore = InMemoryDatastore();
      await datastore.init();

      dhtHandler = MockDHTHandler();
      await dhtHandler.start();
    });

    tearDown(() async {
      await dhtHandler.stop();
      await datastore.close();
    });

    test('InMemoryDatastore works as expected', () async {
      final block = await createTestBlock('test data');
      final cid = block.cid.toString();

      // Store block
      await datastore.put(cid, block);

      // Verify storage
      expect(await datastore.has(cid), isTrue);
      expect(datastore.numBlocks, equals(1));

      // Retrieve block
      final retrieved = await datastore.get(cid);
      expect(retrieved, isNotNull);
      expect(retrieved!.cid.toString(), equals(cid));
    });

    test('MockDHTHandler implements IDHTHandler', () {
      // Type check
      expect(dhtHandler, isA<IDHTHandler>());
    });

    test('MockDHTHandler stores and retrieves values', () async {
      final key = Key.fromString('test-key');
      final value = Value.fromString('test-value');

      await dhtHandler.putValue(key, value);
      final retrieved = await dhtHandler.getValue(key);

      expect(retrieved.toString(), equals(value.toString()));
    });

    test('MockDHTHandler tracks method calls', () async {
      final key = Key.fromString('tracked-key');
      final value = Value.fromString('tracked-value');

      await dhtHandler.putValue(key, value);
      await dhtHandler.getValue(key);

      expect(dhtHandler.wasCalled('putValue'), isTrue);
      expect(dhtHandler.wasCalled('getValue'), isTrue);
      expect(dhtHandler.getCallCount('putValue'), equals(1));
      expect(dhtHandler.getCallCount('getValue'), equals(1));
    });

    test('MockDHTHandler simulates delays', () async {
      dhtHandler.setSimulatedDelay(Duration(milliseconds: 100));

      final key = Key.fromString('delayed-key');
      final value = Value.fromString('delayed-value');

      final stopwatch = Stopwatch()..start();
      await dhtHandler.putValue(key, value);
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(100));
    });

    test('MockDHTHandler simulates errors', () async {
      dhtHandler.throwOnNext(Exception('Simulated error'));

      final key = Key.fromString('error-key');
      final value = Value.fromString('error-value');

      expect(
        () async => await dhtHandler.putValue(key, value),
        throwsA(isA<Exception>()),
      );
    });

    test('MockDHTHandler resets state correctly', () async {
      final key = Key.fromString('reset-key');
      final value = Value.fromString('reset-value');

      await dhtHandler.putValue(key, value);
      expect(dhtHandler.hasStoredValue(key), isTrue);

      dhtHandler.reset();

      expect(dhtHandler.hasStoredValue(key), isFalse);
      expect(dhtHandler.getCalls().isEmpty, isTrue);
    });

    test('Mock infrastructure works together', () async {
      // Use both mocks in combination
      final block = await createTestBlock('integration test');
      final cid = block.cid.toString();

      // Store in datastore
      await datastore.put(cid, block);

      // Use DHT handler
      final key = Key.fromString('integration-key');
      final value = Value.fromString(cid);
      await dhtHandler.putValue(key, value);

      // Verify both worked
      expect(await datastore.has(cid), isTrue);
      expect(dhtHandler.hasStoredValue(key), isTrue);
    });

    test('Multiple test blocks can be created and stored', () async {
      final blocks = await createTestBlocks(5);

      for (final block in blocks) {
        await datastore.put(block.cid.toString(), block);
      }

      expect(datastore.numBlocks, equals(5));

      final keys = await datastore.getAllKeys();
      expect(keys.length, equals(5));
    });

    test('InMemoryDatastore pin functionality works', () async {
      final block = await createTestBlock('pinned block');
      final cid = block.cid.toString();

      await datastore.put(cid, block);
      await datastore.pin(cid);

      expect(await datastore.isPinned(cid), isTrue);

      // Cannot delete pinned block
      expect(
        () async => await datastore.delete(cid),
        throwsA(isA<DatastoreError>()),
      );

      // Can delete after unpinning
      await datastore.unpin(cid);
      await datastore.delete(cid);
      expect(await datastore.has(cid), isFalse);
    });
  });

  group('Test Helpers', () {
    test('createTestBlock creates valid blocks', () async {
      final block = await createTestBlock('test');

      expect(block, isNotNull);
      expect(block.cid, isNotNull);
      expect(block.data, isNotEmpty);
    });

    test('createTestBlocks creates multiple blocks', () async {
      final blocks = await createTestBlocks(3);

      expect(blocks.length, equals(3));

      // Each block should have unique CID
      final cids = blocks.map((b) => b.cid.toString()).toSet();
      expect(cids.length, equals(3));
    });

    test('generateTestPrivateKey creates a key', () {
      final key = generateTestPrivateKey();

      expect(key, isNotNull);
      // Should be a valid IPFSPrivateKey
    });

    test('TestBlockGraph.create creates linked blocks', () async {
      final graph = await TestBlockGraph.create(4);

      expect(graph.blocks.length, equals(4));
      expect(graph.rootCID, isNotNull);
      expect(graph.rootCID, equals(graph.blocks.first.cid));
    });
  });
}
