import 'dart:collection';

/// LRU (Least Recently Used) cache for gateway responses.
///
/// Evicts oldest entries when capacity is exceeded. Thread-safe
/// for single-threaded Dart isolates.
class GatewayLruCache<K, V> {
  /// Maximum number of entries.
  final int capacity;

  final LinkedHashMap<K, V> _cache;

  /// Creates a cache with the given [capacity].
  GatewayLruCache(this.capacity)
    : assert(capacity > 0, 'Capacity must be positive'),
      _cache = LinkedHashMap();

  V? get(K key) {
    if (!_cache.containsKey(key)) return null;

    // Move to front by removing and re-inserting
    final value = _cache.remove(key);
    _cache[key] = value!;
    return value;
  }

  void put(K key, V value) {
    if (_cache.containsKey(key)) {
      _cache.remove(key);
    } else if (_cache.length >= capacity) {
      _cache.remove(_cache.keys.first); // Remove oldest entry
    }
    _cache[key] = value;
  }

  void remove(K key) {
    _cache.remove(key);
  }

  void clear() {
    _cache.clear();
  }

  bool containsKey(K key) => _cache.containsKey(key);

  int get length => _cache.length;

  Iterable<K> get keys => _cache.keys;
  Iterable<V> get values => _cache.values;
}
