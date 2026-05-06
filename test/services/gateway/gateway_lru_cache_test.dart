import 'package:test/test.dart';
import 'package:dart_ipfs/src/services/gateway/gateway_lru_cache.dart';

void main() {
  group('GatewayLruCache', () {
    test('put and get', () {
      final cache = GatewayLruCache<String, int>(2);
      cache.put('a', 1);
      cache.put('b', 2);

      expect(cache.get('a'), equals(1));
      expect(cache.get('b'), equals(2));
      expect(cache.get('c'), isNull);
    });

    test('eviction', () {
      final cache = GatewayLruCache<String, int>(2);
      cache.put('a', 1);
      cache.put('b', 2);
      cache.put('c', 3); // Should evict 'a'

      expect(cache.containsKey('a'), isFalse);
      expect(cache.containsKey('b'), isTrue);
      expect(cache.containsKey('c'), isTrue);
    });

    test('update moves to front', () {
      final cache = GatewayLruCache<String, int>(2);
      cache.put('a', 1);
      cache.put('b', 2);
      cache.put('a', 11); // Update 'a', moves to newest

      cache.put('c', 3); // Should evict 'b' (oldest)
      expect(cache.containsKey('b'), isFalse);
      expect(cache.containsKey('a'), isTrue);
    });

    test('clear and remove', () {
      final cache = GatewayLruCache<String, int>(10);
      cache.put('a', 1);
      cache.remove('a');
      expect(cache.length, equals(0));

      cache.put('b', 2);
      cache.clear();
      expect(cache.length, equals(0));
    });

    test('keys and values', () {
      final cache = GatewayLruCache<String, int>(2);
      cache.put('a', 1);
      cache.put('b', 2);
      expect(cache.keys, containsAll(['a', 'b']));
      expect(cache.values, containsAll([1, 2]));
    });
  });
}
