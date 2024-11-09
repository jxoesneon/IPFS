import 'package:p2plib/p2plib.dart' as p2p;

class KademliaNode {
  final p2p.PeerId peerId;
  final int distance;
  final List<KademliaNode> children;
  final p2p.PeerId _associatedPeerId;
  final int _lastSeen;
  int? bucketIndex;

  KademliaNode(
    this.peerId,
    this.distance,
    this._associatedPeerId, {
    required int lastSeen,
  })  : _lastSeen = lastSeen,
        children = [];

  int get lastSeen => _lastSeen;

  p2p.PeerId get associatedPeerId => _associatedPeerId;
}
