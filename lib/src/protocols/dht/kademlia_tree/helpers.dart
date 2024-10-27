// lib/src/protocols/dht/kademlia_tree/helpers.dart
import 'package:p2plib/p2plib.dart' as p2p;
import '../../../proto/generated/dht/helpers.pb.dart' as helpers_pb;
import '../../../proto/generated/dht/common_kademlia.pb.dart' as common_kademlia_pb;

/// Calculates the XOR distance between two Peer IDs.
int calculateDistance(p2p.PeerId a, p2p.PeerId b) {
  // Get the byte representations of the Peer IDs
  List<int> bytesA = a.bytes;
  List<int> bytesB = b.bytes;

  // Calculate the XOR distance
  int distance = 0;
  int minLength = bytesA.length < bytesB.length ? bytesA.length : bytesB.length;
  for (int i = 0; i < minLength; i++) {
    distance = distance | (bytesA[i] ^ bytesB[i]) << (8 * (minLength - 1 - i));
  }

  return distance;
}

/// Finds the bucket index for a given distance.
int getBucketIndex(int distance) {
  // Assuming 256 buckets (for 256-bit Peer IDs)
  // and the distance is represented as an integer
  if (distance == 0) return 0;
  int bucketIndex = 255 - (distance.bitLength - 1);
  return bucketIndex;
}

/// Finds the closest node to a target peer ID in a given subtree.
// ... (Implementation for _findClosestNode) ...

/// Splits a node in the tree, creating two child nodes.
// ... (Implementation for _splitNode) ...

/// Merges two child nodes into their parent node.
// ... (Implementation for _mergeNodes) ...

/// Sends a FIND_NODE request to a peer and returns closer peers to the target.
// ... (Implementation for _findNode) ...
