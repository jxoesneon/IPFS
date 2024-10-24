// lib/src/protocols/dht/kademlia_tree/kademlia_node.dart
import 'package:p2plib/p2plib.dart' as p2p;
import '/../src/proto/dht/kademlia_node.pb.dart' as kademlia_node_pb;
import '/../src/proto/dht/common_kademlia.pb.dart' as common_kademlia_pb;

class KademliaNode {
  final p2p.PeerId peerId;
  final int distance; // XOR distance from the local node
  final List<KademliaNode> children; // Child nodes for branching
  int? bucketIndex; // Reference to the bucket the node belongs to

  KademliaNode(this.peerId, this.distance, p2p.PeerId associatedPeerId) : children = [];
  
  // Add any other necessary properties or methods for your node here.
  // For example, you might want to store additional data associated with the node,
  // or implement methods for updating the node's state.
}
