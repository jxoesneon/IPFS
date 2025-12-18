import 'package:p2plib/p2plib.dart' as p2p;

/// State of a node in the Kademlia DHT.
enum KademliaNodeState {
  /// Node is responsive.
  active,

  /// Node hasn't responded recently.
  stale,

  /// Node has failed to respond.
  failed,
}

/// A node in the Kademlia tree representing a peer.
///
/// Tracks distance from the local node, connection state,
/// latency, and failure count for eviction decisions.
class KademliaTreeNode {

  /// Creates a Kademlia tree node.
  KademliaTreeNode(
    this.peerId,
    this.distance,
    this._associatedPeerId, {
    required int lastSeen,
  }) : assert(peerId.value.isNotEmpty, 'PeerId cannot be empty'),
       assert(distance >= 0, 'Distance must be non-negative'),
       _lastSeen = lastSeen,
       children = [];
  /// The peer identifier.
  final p2p.PeerId peerId;

  /// XOR distance from this node to the routing table's owner.
  final int distance;

  /// Child nodes in the tree structure.
  final List<KademliaTreeNode> children;

  final p2p.PeerId _associatedPeerId;
  int _lastSeen;
  int? bucketIndex;
  KademliaNodeState _state = KademliaNodeState.active;
  int _lastRtt = 0;
  int _failedRequests = 0;

  /// Maximum failures before marking as failed.
  static const int MAX_FAILURES = 5;

  /// Kademlia protocol version.
  static const String PROTOCOL_VERSION = '/ipfs/kad/1.0.0';

  /// Standard k-bucket size.
  static const int K = 20;

  int get lastSeen => _lastSeen;

  set lastSeen(int value) {
    _lastSeen = value;
  }

  p2p.PeerId get associatedPeerId => _associatedPeerId;

  KademliaNodeState get state => _state;

  set state(KademliaNodeState value) {
    _state = value;
  }

  int get lastRtt => _lastRtt;

  set lastRtt(int value) {
    _lastRtt = value;
  }

  void incrementFailedRequests() {
    _failedRequests++;
    if (_failedRequests >= MAX_FAILURES) {
      _state = KademliaNodeState.failed;
    } else if (_failedRequests >= MAX_FAILURES / 2) {
      _state = KademliaNodeState.stale;
    }
  }

  void resetFailedRequests() {
    _failedRequests = 0;
    _state = KademliaNodeState.active;
  }

  int get failedRequests => _failedRequests;
}
