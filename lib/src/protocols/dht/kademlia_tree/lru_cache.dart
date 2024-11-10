import 'package:p2plib/p2plib.dart' as p2p;
import 'kademlia_tree_node.dart';

class LRUCache {
  final int capacity;
  final Map<p2p.PeerId, _Node> _cache = {};
  _Node? _head;
  _Node? _tail;

  LRUCache(this.capacity) {
    assert(capacity > 0, 'Capacity must be positive');
  }

  void put(p2p.PeerId key, KademliaTreeNode value) {
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

  KademliaTreeNode? get(p2p.PeerId key) {
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
    if (_tail == null) {
      _tail = node;
    }
  }

  void _addToFront(_Node node) {
    node.next = _head;
    node.prev = null;
    if (_head != null) {
      _head!.prev = node;
    }
    _head = node;
    if (_tail == null) {
      _tail = node;
    }
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
  final p2p.PeerId key;
  KademliaTreeNode value;
  _Node? next;
  _Node? prev;

  _Node(this.key, this.value);
}
