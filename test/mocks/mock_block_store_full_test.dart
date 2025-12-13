// test/mocks/mock_block_store_full_test.dart
import 'package:test/test.dart';
import '../mocks/mock_block_store.dart';
import '../mocks/test_helpers.dart';

/// Comprehensive tests for MockBlockStore mock infrastructure.
void main() {
  group('MockBlockStore Comprehensive Tests', () {
    late MockBlockStore store;

    setUp() async {
      store = MockBlockStore();
      await store.start();
    }

    tearDown() async {
      await store.stop();
    }

    group('Initialization', () {
      test('initializes in started state', () {
        expect(store.isStarted, isTrue);
      });

      test('blockCount starts at zero', () {
        expect(store.blockCount, equals(0));
      });

      test('getCalls starts empty', () {
        expect(store.getCalls(), isEmpty);
      });
    });

    group('putBlock Operations', () {
      test('putBlock succeeds when started', () async {
        final block = await createTestBlock('test');

        final response = await store.putBlock(block);

        expect(response.success, isTrue);
        expect(store.blockCount, equals(1));
      });

      test('putBlock fails when stopped', () async {
        await store.stop();
        final block = await createTestBlock('stopped');

        final response = await store.putBlock(block);

        expect(response.success, isFalse);
      });

      test('putBlock increments blockCount', () async {
        expect(store.blockCount, equals(0));

        await store.putBlock(await createTestBlock('1'));
        expect(store.blockCount, equals(1));

        await store.putBlock(await createTestBlock('2'));
        expect(store.blockCount, equals(2));
      });

      test('putBlock handles duplicate CIDs idempotently', () async {
        final block = await createTestBlock('duplicate');

        await store.putBlock(block);
        await store.putBlock(block);

        expect(store.blockCount, equals(1));
      });
    });

    group('getBlock Operations', () {
      test('getBlock returns found for existing block', () async {
        final block = await createTestBlock('exists');
        await store.putBlock(block);

        final response = await store.getBlock(block.cid.toString());

        expect(response.found, isTrue);
        expect(response.block.cid.toString(), equals(block.cid.toString()));
      });

      test('getBlock returns not found for missing block', () async {
        final response = await store.getBlock('QmNonExistent');

        expect(response.found, isFalse);
      });

      test('getBlock works when stopped', () async {
        final block = await createTestBlock('before stop');
        await store.putBlock(block);
        await store.stop();

        final response = await store.getBlock(block.cid.toString());

        expect(response.found, isTrue);
      });
    });

    group('removeBlock Operations', () {
      test('removeBlock succeeds for existing block', () async {
        final block = await createTestBlock('remove me');
        await store.putBlock(block);

        final response = await store.removeBlock(block.cid.toString());

        expect(response.success, isTrue);
        expect(store.blockCount, equals(0));
      });

      test('removeBlock fails for non-existent block', () async {
        final response = await store.removeBlock('QmFake');

        expect(response.success, isFalse);
      });

      test('removeBlock fails when stopped', () async {
        await store.stop();

        final response = await store.removeBlock('QmAny');

        expect(response.success, isFalse);
      });
    });

    group('hasBlock Operations', () {
      test('hasBlock returns true for existing block', () async {
        final block = await createTestBlock('check');
        await store.putBlock(block);

        final has = await store.hasBlock(block.cid.toString());

        expect(has, isTrue);
      });

      test('hasBlock returns false for missing block', () async {
        final has = await store.hasBlock('QmMissing');

        expect(has, isFalse);
      });
    });

    group('getAllBlocks Operations', () {
      test('getAllBlocks returns all stored blocks', () async {
        final blocks = await createTestBlocks(3);
        for (final block in blocks) {
          await store.putBlock(block);
        }

        final allBlocks = await store.getAllBlocks();

        expect(allBlocks.length, equals(3));
      });

      test('getAllBlocks returns empty when no blocks', () async {
        final allBlocks = await store.getAllBlocks();

        expect(allBlocks, isEmpty);
      });
    });

    group('Call Tracking', () {
      test('wasCalled tracks method invocations', () async {
        expect(store.wasCalled('putBlock'), isFalse);

        await store.putBlock(await createTestBlock('track'));

        expect(store.wasCalled('putBlock'), isTrue);
      });

      test('getCallCount returns accurate counts', () async {
        await store.getBlock('test1');
        await store.getBlock('test2');
        await store.getBlock('test3');

        expect(store.getCallCount('getBlock'), equals(3));
      });

      test('getCalls returns all operations', () async {
        await store.putBlock(await createTestBlock('op'));
        await store.getBlock('test');

        final calls = store.getCalls();
        expect(calls, isNotEmpty);
        expect(calls.length, greaterThanOrEqualTo(2));
      });
    });

    group('Lifecycle Management', () {
      test('stop changes started state', () async {
        expect(store.isStarted, isTrue);

        await store.stop();

        expect(store.isStarted, isFalse);
      });

      test('start after stop works', () async {
        await store.stop();
        await store.start();

        expect(store.isStarted, isTrue);

        final block = await createTestBlock('restart');
        final response = await store.putBlock(block);
        expect(response.success, isTrue);
      });

      test('reset clears all state', () async {
        await store.putBlock(await createTestBlock('clear'));
        await store.getBlock('test');

        store.reset();

        expect(store.blockCount, equals(0));
        expect(store.getCalls(), isEmpty);
        expect(store.isStarted, isFalse);
      });
    });

    group('Helper Methods', () {
      test('setupBlock adds block directly', () async {
        final block = await createTestBlock('setup');

        store.setupBlock(block.cid.toString(), block);

        expect(await store.hasBlock(block.cid.toString()), isTrue);
      });
    });

    group('Concurrent Operations', () {
      test('concurrent putBlock operations', () async {
        final blocks = await createTestBlocks(10);
        final futures = blocks.map((b) => store.putBlock(b));

        await Future.wait(futures);

        expect(store.blockCount, equals(10));
      });

      test('concurrent getBlock operations', () async {
        final block = await createTestBlock('concurrent');
        await store.putBlock(block);

        final futures = List.generate(
          5,
          (_) => store.getBlock(block.cid.toString()),
        );

        final responses = await Future.wait(futures);

        expect(responses.every((r) => r.found), isTrue);
      });
    });
  });
}
