import 'dart:collection';
import 'dart:typed_data';

/// In-memory LRU cache for content-addressed IPFS data (e.g. decoded images, text).
///
/// Since IPFS data identified by CID is immutable, cached entries never become stale.
/// Cache eviction occurs on a Least-Recently-Used (LRU) basis when capacity limits
/// are reached.
class IpfsCacheManager {
  IpfsCacheManager({
    this.maxEntries = 100,
    this.maxSizeBytes = 50 * 1024 * 1024, // 50 MB
  });

  /// Maximum number of items in the cache.
  final int maxEntries;

  /// Maximum total bytes across all cached items.
  final int maxSizeBytes;

  final LinkedHashMap<String, Uint8List> _cache = LinkedHashMap<String, Uint8List>();
  int _currentSizeBytes = 0;

  /// Returns the singleton default cache instance.
  static final IpfsCacheManager defaultCache = IpfsCacheManager();

  /// Returns cached bytes for [key] (typically a CID or CID/subpath), or 
ull.
  Uint8List? get(String key) {
    final value = _cache.remove(key);
    if (value != null) {
      // Re-insert at the end to mark as most recently used
      _cache[key] = value;
      return value;
    }
    return null;
  }

  /// Stores [bytes] in cache for [key].
  void put(String key, Uint8List bytes) {
    if (bytes.length > maxSizeBytes) {
      // Item exceeds maximum cache size entirely, do not cache
      return;
    }

    // If key already exists, remove old size
    final existing = _cache.remove(key);
    if (existing != null) {
      _currentSizeBytes -= existing.length;
    }

    // Evict least recently used entries if needed
    while (_cache.isNotEmpty &&
        (_cache.length >= maxEntries || _currentSizeBytes + bytes.length > maxSizeBytes)) {
      final oldestKey = _cache.keys.first;
      final evicted = _cache.remove(oldestKey);
      if (evicted != null) {
        _currentSizeBytes -= evicted.length;
      }
    }

    _cache[key] = bytes;
    _currentSizeBytes += bytes.length;
  }

  /// Removes an entry by [key].
  Uint8List? evict(String key) {
    final removed = _cache.remove(key);
    if (removed != null) {
      _currentSizeBytes -= removed.length;
    }
    return removed;
  }

  /// Clears all entries from the cache.
  void clear() {
    _cache.clear();
    _currentSizeBytes = 0;
  }

  /// Current number of items in cache.
  int get length => _cache.length;

  /// Current total bytes stored in cache.
  int get currentSizeBytes => _currentSizeBytes;

  /// Whether [key] is currently cached.
  bool containsKey(String key) => _cache.containsKey(key);
}
