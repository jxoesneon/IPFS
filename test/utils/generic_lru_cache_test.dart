// test/utils/generic_lru_cache_test.dart
//
// Tests for generic LRU cache utilities

import 'dart:async';
import 'package:dart_ipfs/src/utils/generic_lru_cache.dart';
import 'package:test/test.dart';

void main() {
  group('GenericLRUCache', () {
    group('basic operations', () {
      test('puts and gets values', () {
        final cache = GenericLRUCache<String, int>(capacity: 10);

        cache.put('one', 1);
        cache.put('two', 2);

        expect(cache.get('one'), equals(1));
        expect(cache.get('two'), equals(2));
      });

      test('returns null for missing keys', () {
        final cache = GenericLRUCache<String, int>(capacity: 10);

        expect(cache.get('missing'), isNull);
      });

      test('updates existing values', () {
        final cache = GenericLRUCache<String, int>(capacity: 10);

        cache.put('key', 1);
        cache.put('key', 2);

        expect(cache.get('key'), equals(2));
        expect(cache.length, equals(1));
      });

      test('reports correct length', () {
        final cache = GenericLRUCache<String, int>(capacity: 10);

        cache.put('a', 1);
        cache.put('b', 2);
        cache.put('c', 3);

        expect(cache.length, equals(3));
        expect(cache.isEmpty, isFalse);
      });
    });

    group('eviction', () {
      test('evicts LRU when at capacity', () {
        final cache = GenericLRUCache<String, int>(capacity: 3);

        cache.put('a', 1);
        cache.put('b', 2);
        cache.put('c', 3);
        cache.put('d', 4); // Should evict 'a'

        expect(cache.get('a'), isNull);
        expect(cache.get('b'), equals(2));
        expect(cache.get('c'), equals(3));
        expect(cache.get('d'), equals(4));
      });

      test('get updates LRU order', () {
        final cache = GenericLRUCache<String, int>(capacity: 3);

        cache.put('a', 1);
        cache.put('b', 2);
        cache.put('c', 3);
        cache.get('a'); // Touch 'a' - now most recent
        cache.put('d', 4); // Should evict 'b'

        expect(cache.get('a'), equals(1));
        expect(cache.get('b'), isNull);
      });

      test('calls onEvict callback', () {
        String? evictedKey;
        int? evictedValue;

        final cache = GenericLRUCache<String, int>(
          capacity: 2,
          onEvict: (key, value) {
            evictedKey = key;
            evictedValue = value;
          },
        );

        cache.put('a', 1);
        cache.put('b', 2);
        cache.put('c', 3); // Should evict 'a'

        expect(evictedKey, equals('a'));
        expect(evictedValue, equals(1));
      });
    });

    group('remove', () {
      test('removes existing key', () {
        final cache = GenericLRUCache<String, int>(capacity: 10);

        cache.put('key', 42);
        final removed = cache.remove('key');

        expect(removed, equals(42));
        expect(cache.get('key'), isNull);
      });

      test('returns null for missing key', () {
        final cache = GenericLRUCache<String, int>(capacity: 10);

        expect(cache.remove('missing'), isNull);
      });
    });

    group('clear', () {
      test('removes all entries', () {
        final cache = GenericLRUCache<String, int>(capacity: 10);

        cache.put('a', 1);
        cache.put('b', 2);
        cache.clear();

        expect(cache.isEmpty, isTrue);
        expect(cache.get('a'), isNull);
      });

      test('calls onEvict for all entries', () {
        final evicted = <String>[];

        final cache = GenericLRUCache<String, int>(
          capacity: 10,
          onEvict: (key, _) => evicted.add(key),
        );

        cache.put('a', 1);
        cache.put('b', 2);
        cache.clear();

        expect(evicted, containsAll(['a', 'b']));
      });
    });

    group('getOrCompute', () {
      test('returns cached value if exists', () async {
        final cache = GenericLRUCache<String, int>(capacity: 10);
        cache.put('key', 42);

        var computed = false;
        final value = await cache.getOrCompute('key', () async {
          computed = true;
          return 99;
        });

        expect(value, equals(42));
        expect(computed, isFalse);
      });

      test('computes and caches if missing', () async {
        final cache = GenericLRUCache<String, int>(capacity: 10);

        final value = await cache.getOrCompute('key', () async => 42);

        expect(value, equals(42));
        expect(cache.get('key'), equals(42));
      });
    });

    group('containsKey', () {
      test('returns true for existing keys', () {
        final cache = GenericLRUCache<String, int>(capacity: 10);
        cache.put('exists', 1);

        expect(cache.containsKey('exists'), isTrue);
        expect(cache.containsKey('missing'), isFalse);
      });
    });
  });

  group('TimedLRUCache', () {
    test('expires entries after TTL', () async {
      final cache = TimedLRUCache<String, int>(capacity: 10, ttl: const Duration(milliseconds: 50));

      cache.put('key', 42);
      expect(cache.get('key'), equals(42));

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(cache.get('key'), isNull);
    });

    test('fresh entries are not expired', () async {
      final cache = TimedLRUCache<String, int>(capacity: 10, ttl: const Duration(seconds: 10));

      cache.put('key', 42);

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(cache.get('key'), equals(42));
    });
  });
}
