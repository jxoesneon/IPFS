import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'kademlia_tree_node.dart';

/// LRU cache for Kademlia tree nodes.
///
/// Uses a doubly-linked list for O(1) access and eviction.
class LRUCache {
  /// Creates a cache with the given [capacity].
  LRUCache(this.capacity) {
    assert(capacity > 0, 'Capacity must be positive');
  }

  /// Maximum number of cached nodes.
  final int capacity;

  final Map<PeerId, _Node> _cache = {};
  _Node? _head;
  _Node? _tail;

  /// Adds or updates a node in the cache.
  void put(PeerId key, KademliaTreeNode value) {
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

  /// Gets a node from the cache, returning null if not found.
  KademliaTreeNode? get(PeerId key) {
    final node = _cache[key];
    if (node != null) {
      _moveToFront(node);
      return node.value;
    }
    return null;
  }

  void _moveToFront(_Node node) {
    if (node == _head) return;

    if (node.prev != null) {
      node.prev!.next = node.next;
    }
    if (node.next != null) {
      node.next!.prev = node.prev;
    }
    if (node == _tail) {
      _tail = node.prev;
    }

    node.next = _head;
    node.prev = null;
    if (_head != null) {
      _head!.prev = node;
    }
    _head = node;
    _tail ??= node;
  }

  void _addToFront(_Node node) {
    node.next = _head;
    node.prev = null;
    if (_head != null) {
      _head!.prev = node;
    }
    _head = node;
    _tail ??= node;
  }

  void _removeLRU() {
    if (_tail != null) {
      _cache.remove(_tail!.key);
      _tail = _tail!.prev;
      if (_tail != null) {
        _tail!.next = null;
      } else {
        _head = null;
      }
    }
  }

  /// Returns the least recently used nodes.
  List<KademliaTreeNode> getLRUNodes(int count) {
    List<KademliaTreeNode> result = [];
    var current = _tail;
    while (current != null && result.length < count) {
      result.add(current.value);
      current = current.prev;
    }
    return result;
  }
}

class _Node {
  _Node(this.key, this.value);
  final PeerId key;
  KademliaTreeNode value;
  _Node? next;
  _Node? prev;
}

