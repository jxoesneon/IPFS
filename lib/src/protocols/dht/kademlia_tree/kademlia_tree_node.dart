import 'package:dart_ipfs/src/core/types/peer_id.dart';

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
    this.associatedPeerId, {
    required this.lastSeen,
  }) : assert(peerId.value.isNotEmpty, 'PeerId cannot be empty'),
       assert(distance >= 0, 'Distance must be non-negative'),
       children = [];

  /// The peer identifier.
  final PeerId peerId;

  /// XOR distance from this node to the routing table's owner.
  final int distance;

  /// Child nodes in the tree structure.
  final List<KademliaTreeNode> children;

  /// The associated peer ID.
  final PeerId associatedPeerId;

  /// When this node was last seen (milliseconds since epoch).
  int lastSeen;

  /// The k-bucket index for this node.
  int? bucketIndex;

  /// Current state of this node.
  KademliaNodeState state = KademliaNodeState.active;

  /// Last round-trip time in milliseconds.
  int lastRtt = 0;

  int _failedRequests = 0;

  /// Maximum failures before marking as failed.
  static const int maxFailures = 5;

  /// Kademlia protocol version.
  static const String protocolVersion = '/ipfs/kad/1.0.0';

  /// Standard k-bucket size.
  static const int K = 20;

  /// Increments the failed request count and updates state.
  void incrementFailedRequests() {
    _failedRequests++;
    if (_failedRequests >= maxFailures) {
      state = KademliaNodeState.failed;
    } else if (_failedRequests >= maxFailures / 2) {
      state = KademliaNodeState.stale;
    }
  }

  /// Resets the failed request count and marks as active.
  void resetFailedRequests() {
    _failedRequests = 0;
    state = KademliaNodeState.active;
  }

  /// Number of failed requests for this node.
  int get failedRequests => _failedRequests;
}

