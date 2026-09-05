import 'dart:typed_data';

import 'package:flutter_ipfs/src/cache/ipfs_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IpfsCacheManager', () {
    test('put and get returns cached bytes', () {
      final cache = IpfsCacheManager(maxEntries: 10, maxSizeBytes: 1024);
      final testData = Uint8List.fromList([1, 2, 3, 4, 5]);

      cache.put('bafytest1', testData);
      expect(cache.length, equals(1));
      expect(cache.currentSizeBytes, equals(5));
      expect(cache.get('bafytest1'), equals(testData));
    });

    test('evicts least recently used when maxEntries exceeded', () {
      final cache = IpfsCacheManager(maxEntries: 2, maxSizeBytes: 1024);
      final d1 = Uint8List.fromList([1]);
      final d2 = Uint8List.fromList([2]);
      final d3 = Uint8List.fromList([3]);

      cache.put('c1', d1);
      cache.put('c2', d2);

      // Access c1 to make c2 the LRU
      cache.get('c1');

      cache.put('c3', d3);

      expect(cache.get('c1'), isNotNull);
      expect(cache.get('c3'), isNotNull);
      expect(cache.get('c2'), isNull); // c2 was evicted
      expect(cache.length, equals(2));
    });

    test('evicts least recently used when maxSizeBytes exceeded', () {
      final cache = IpfsCacheManager(maxEntries: 10, maxSizeBytes: 10);
      final d1 = Uint8List.fromList([1, 2, 3, 4, 5, 6]); // 6 bytes
      final d2 = Uint8List.fromList([7, 8, 9, 10, 11]);   // 5 bytes (6+5 > 10)

      cache.put('c1', d1);
      expect(cache.currentSizeBytes, equals(6));

      cache.put('c2', d2); // Should evict c1
      expect(cache.get('c1'), isNull);
      expect(cache.get('c2'), equals(d2));
      expect(cache.currentSizeBytes, equals(5));
    });

    test('evict removes specific key', () {
      final cache = IpfsCacheManager();
      final data = Uint8List.fromList([10, 20]);
      cache.put('c1', data);

      final removed = cache.evict('c1');
      expect(removed, equals(data));
      expect(cache.get('c1'), isNull);
      expect(cache.length, equals(0));
      expect(cache.currentSizeBytes, equals(0));
    });

    test('clear wipes all entries', () {
      final cache = IpfsCacheManager();
      cache.put('c1', Uint8List.fromList([1]));
      cache.put('c2', Uint8List.fromList([2]));

      cache.clear();
      expect(cache.length, equals(0));
      expect(cache.currentSizeBytes, equals(0));
      expect(cache.containsKey('c1'), isFalse);
    });
  });
}
