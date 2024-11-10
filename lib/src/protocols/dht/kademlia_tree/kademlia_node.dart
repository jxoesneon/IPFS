import 'package:p2plib/p2plib.dart' as p2p;

enum KademliaNodeState {
  active, // Node is responsive
  stale, // Node hasn't responded recently
  failed // Node has failed to respond
}

class KademliaNode {
  final p2p.PeerId peerId;

  /// Distance is calculated as the XOR metric between this node's ID and the target ID
  /// following Kademlia specification
  final int distance;
  final List<KademliaNode> children;
  final p2p.PeerId _associatedPeerId;
  int _lastSeen;
  int? bucketIndex;
  KademliaNodeState _state = KademliaNodeState.active;
  int _lastRtt = 0; // Initialize with default value
  int _failedRequests = 0;
  static const int MAX_FAILURES = 5; // Max failures before marking as failed

  static const String PROTOCOL_VERSION = '/ipfs/kad/1.0.0';
  static const int K = 20; // Standard Kademlia k-bucket size

  KademliaNode(
    this.peerId,
    this.distance,
    this._associatedPeerId, {
    required int lastSeen,
  })  : assert(peerId.value.length > 0, 'PeerId cannot be empty'),
        assert(distance >= 0, 'Distance must be non-negative'),
        _lastSeen = lastSeen,
        children = [];

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
