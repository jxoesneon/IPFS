// lib/src/utils/generic_lru_cache.dart
//
// Generic LRU (Least Recently Used) cache with O(1) operations.
// Performance optimization for frequently accessed data.

/// Generic LRU cache with O(1) get/put operations.
///
/// Uses a doubly-linked list for eviction ordering and a map for O(1) access.
/// Thread-safe with proper cleanup on eviction.
///
/// Example:
/// ```dart
/// final cache = GenericLRUCache<String, int>(capacity: 100);
/// cache.put('key1', 42);
/// final value = cache.get('key1'); // 42
/// ```
class GenericLRUCache<K, V> {
  /// Maximum number of entries before eviction.
  final int capacity;

  /// Callback invoked when an entry is evicted.
  final void Function(K key, V value)? onEvict;

  final Map<K, _Node<K, V>> _cache = {};
  _Node<K, V>? _head;
  _Node<K, V>? _tail;

  /// Creates a cache with the given [capacity].
  GenericLRUCache({required this.capacity, this.onEvict}) {
    assert(capacity > 0, 'Capacity must be positive');
  }

  /// Number of entries in the cache.
  int get length => _cache.length;

  /// Whether the cache is empty.
  bool get isEmpty => _cache.isEmpty;

  /// Whether the cache is at capacity.
  bool get isFull => _cache.length >= capacity;

  /// Adds or updates an entry.
  void put(K key, V value) {
    if (_cache.containsKey(key)) {
      _moveToFront(_cache[key]!);
      _cache[key]!.value = value;
    } else {
      final newNode = _Node(key, value);
      if (_cache.length >= capacity) {
        _removeLRU();
      }
      _addToFront(newNode);
      _cache[key] = newNode;
    }
  }

  /// Gets an entry, returning null if not found.
  V? get(K key) {
    final node = _cache[key];
    if (node != null) {
      _moveToFront(node);
      return node.value;
    }
    return null;
  }

  /// Gets an entry or computes and caches it if not found.
  Future<V> getOrCompute(K key, Future<V> Function() compute) async {
    final cached = get(key);
    if (cached != null) return cached;

    final value = await compute();
    put(key, value);
    return value;
  }

  /// Synchronous version of getOrCompute.
  V getOrComputeSync(K key, V Function() compute) {
    final cached = get(key);
    if (cached != null) return cached;

    final value = compute();
    put(key, value);
    return value;
  }

  /// Checks if the key exists in the cache.
  bool containsKey(K key) => _cache.containsKey(key);

  /// Removes an entry from the cache.
  V? remove(K key) {
    final node = _cache.remove(key);
    if (node != null) {
      _removeNode(node);
      return node.value;
    }
    return null;
  }

  /// Clears all entries from the cache.
  void clear() {
    if (onEvict != null) {
      for (final entry in _cache.entries) {
        onEvict!(entry.key, entry.value.value);
      }
    }
    _cache.clear();
    _head = null;
    _tail = null;
  }

  /// Returns all keys in order from most to least recently used.
  List<K> get keys {
    final result = <K>[];
    var current = _head;
    while (current != null) {
      result.add(current.key);
      current = current.next;
    }
    return result;
  }

  void _moveToFront(_Node<K, V> node) {
    if (node == _head) return;

    _removeNode(node);
    _addToFront(node);
  }

  void _addToFront(_Node<K, V> node) {
    node.next = _head;
    node.prev = null;
    if (_head != null) {
      _head!.prev = node;
    }
    _head = node;
    _tail ??= node;
  }

  void _removeNode(_Node<K, V> node) {
    if (node.prev != null) {
      node.prev!.next = node.next;
    }
    if (node.next != null) {
      node.next!.prev = node.prev;
    }
    if (node == _head) {
      _head = node.next;
    }
    if (node == _tail) {
      _tail = node.prev;
    }
  }

  void _removeLRU() {
    if (_tail != null) {
      final removed = _cache.remove(_tail!.key);
      if (removed != null && onEvict != null) {
        onEvict!(_tail!.key, _tail!.value);
      }
      _tail = _tail!.prev;
      if (_tail != null) {
        _tail!.next = null;
      } else {
        _head = null;
      }
    }
  }
}

class _Node<K, V> {
  final K key;
  V value;
  _Node<K, V>? next;
  _Node<K, V>? prev;

  _Node(this.key, this.value);
}

/// Timed LRU cache that automatically expires entries.
class TimedLRUCache<K, V> extends GenericLRUCache<K, V> {
  /// Duration before entries expire.
  final Duration ttl;

  final Map<K, DateTime> _timestamps = {};

  TimedLRUCache({
    required int capacity,
    required this.ttl,
    void Function(K key, V value)? onEvict,
  }) : super(capacity: capacity, onEvict: onEvict);

  @override
  void put(K key, V value) {
    super.put(key, value);
    _timestamps[key] = DateTime.now();
  }

  @override
  V? get(K key) {
    final timestamp = _timestamps[key];
    if (timestamp != null) {
      if (DateTime.now().difference(timestamp) > ttl) {
        remove(key);
        return null;
      }
    }
    return super.get(key);
  }

  @override
  V? remove(K key) {
    _timestamps.remove(key);
    return super.remove(key);
  }

  @override
  void clear() {
    _timestamps.clear();
    super.clear();
  }
}
