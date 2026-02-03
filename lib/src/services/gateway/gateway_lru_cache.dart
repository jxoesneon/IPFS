import 'dart:collection';

/// LRU (Least Recently Used) cache for gateway responses.
///
/// Evicts oldest entries when capacity is exceeded. Thread-safe
/// for single-threaded Dart isolates.
class GatewayLruCache<K, V> {
  /// Creates a cache with the given [capacity].
  GatewayLruCache(this.capacity)
    : assert(capacity > 0, 'Capacity must be positive'),
      _cache = LinkedHashMap();

  /// Maximum number of entries.
  final int capacity;

  final LinkedHashMap<K, V> _cache;

  /// Retrieves a value by key, or null if not found.
  ///
  /// Accessing a key moves it to the front (most recently used).
  V? get(K key) {
    if (!_cache.containsKey(key)) return null;

    // Move to front by removing and re-inserting
    final value = _cache.remove(key);
    _cache[key] = value as V;
    return value;
  }

  /// Inserts or updates a key-value pair.
  ///
  /// If the cache is full, the least recently used entry is evicted.
  void put(K key, V value) {
    if (_cache.containsKey(key)) {
      _cache.remove(key);
    } else if (_cache.length >= capacity) {
      _cache.remove(_cache.keys.first); // Remove oldest entry
    }
    _cache[key] = value;
  }

  /// Removes an entry by key.
  void remove(K key) {
    _cache.remove(key);
  }

  /// Clears all entries from the cache.
  void clear() {
    _cache.clear();
  }

  /// Returns true if the cache contains the given key.
  bool containsKey(K key) => _cache.containsKey(key);

  /// The number of entries currently in the cache.
  int get length => _cache.length;

  /// Returns an iterable of all keys in the cache, ordered from oldest to newest.
  Iterable<K> get keys => _cache.keys;

  /// Returns an iterable of all values in the cache, ordered from oldest to newest.
  Iterable<V> get values => _cache.values;
}
