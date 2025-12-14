import 'package:test/test.dart';
import 'mock_block_store.dart';
import 'test_helpers.dart'; // Reuse for createTestBlock

void main() {
  group('MockBlockStore', () {
    late MockBlockStore store;

    setUp(() async {
      store = MockBlockStore();
      await store.start();
    });

    tearDown(() async {
      await store.stop();
    });

    test('lifecycle operations record calls', () async {
      store.reset(); // clear start call
      await store.start();
      expect(store.isStarted, isTrue);
      expect(store.wasCalled('start'), isTrue);

      await store.stop();
      expect(store.isStarted, isFalse);
      expect(store.wasCalled('stop'), isTrue);
    });

    test('putBlock returns success and records call', () async {
      final block = await createTestBlock('data');
      final response = await store.putBlock(block);

      expect(response.success, isTrue);
      expect(store.wasCalled('putBlock'), isTrue);
      expect(store.blockCount, 1);
    });

    test('getBlock returns block if exists', () async {
      final block = await createTestBlock('data');
      await store.putBlock(block);

      final response = await store.getBlock(block.cid.toString());

      expect(response.found, isTrue);
      expect(response.block.data, equals(block.data));
    });

    test('getBlock returns not found if missing', () async {
      final response = await store.getBlock('zMissing');
      expect(response.found, isFalse);
    });

    test('removeBlock removes and returns success', () async {
      final block = await createTestBlock('remove');
      await store.putBlock(block);

      final response = await store.removeBlock(block.cid.toString());
      expect(response.success, isTrue);
      expect(store.blockCount, 0);
    });

    test('removeBlock returns error if not found', () async {
      final response = await store.removeBlock('zMissing');
      expect(response.success, isFalse);
      expect(response.message, contains('Block not found'));
    });

    test('operations fail when not started', () async {
      await store.stop();
      final block = await createTestBlock('fail');

      final putResp = await store.putBlock(block);
      expect(putResp.success, isFalse);
      expect(putResp.message, contains('not started'));

      final getResp = await store.getBlock('any');
      expect(getResp.found, isFalse);
      // Not found is the standard response for missing/error in getBlock logic seen in mock_block_store.dart

      final rmResp = await store.removeBlock('any');
      expect(rmResp.success, isFalse);
      expect(rmResp.message, contains('not started'));
    });

    test('reset clears all state', () async {
      await store.putBlock(await createTestBlock('data'));
      expect(store.blockCount, 1);

      store.reset();

      expect(store.blockCount, 0);
      expect(store.isStarted, isFalse);
      expect(store.getCalls(), isEmpty);
    });

    test('getStatus returns correct metadata', () async {
      await store.putBlock(await createTestBlock('data'));

      final status = await store.getStatus();
      expect(status['started'], isTrue);
      expect(status['blockCount'], 1);
      expect(status['cids'], hasLength(1));
    });
  });
}
