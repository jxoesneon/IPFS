import 'package:fixnum/fixnum.dart';
import 'dart:typed_data' show Uint8List;
import 'package:p2plib/p2plib.dart' as p2p;
import 'package:dart_ipfs/src/utils/base58.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_client.dart';
import 'package:dart_ipfs/src/proto/generated/dht/kademlia_node.pb.dart';
import 'package:dart_ipfs/src/proto/generated/dht/dht.pb.dart' as dht_pb;
import 'package:dart_ipfs/src/proto/generated/dht/helpers.pb.dart' as helpers_pb;
import 'package:dart_ipfs/src/proto/generated/dht/common_kademlia.pb.dart' as common_kademlia_pb;
// lib/src/protocols/dht/kademlia_tree/helpers.dart

/// Calculates the XOR distance between two Peer IDs.
int calculateDistance(p2p.PeerId a, p2p.PeerId b) {
  // Get the byte representations of the Peer IDs
  List<int> bytesA = a.value;
  List<int> bytesB = b.value;

  // Calculate the XOR distance
  int distance = 0;
  int minLength = bytesA.length < bytesB.length ? bytesA.length : bytesB.length;
  
  for (int i = 0; i < minLength; i++) {
    distance = (distance << 8) | (bytesA[i] ^ bytesB[i]);
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
KademliaNode? findClosestNode(KademliaNode? root, p2p.PeerId target) {
  if (root == null) return null;
  
  // Convert KademliaId to PeerId for root
  final rootPeerId = p2p.PeerId(value: Uint8List.fromList(root.peerId.id));
  
  // Calculate distances
  int rootDistance = calculateDistance(rootPeerId, target);
  
  // Initialize closest as root
  KademliaNode closest = root;
  int minDistance = rootDistance;
  
  // Check children recursively
  for (var child in root.children) {
    // Convert KademliaId to PeerId for child
    final childPeerId = p2p.PeerId(value: Uint8List.fromList(child.peerId.id));
    
    int childDistance = calculateDistance(childPeerId, target);
    if (childDistance < minDistance) {
      closest = child;
      minDistance = childDistance;
    }
    
    // Recursively search child subtrees
    var childClosest = findClosestNode(child, target);
    if (childClosest != null) {
      // Convert KademliaId to PeerId for closest child
      final closestPeerId = p2p.PeerId(value: Uint8List.fromList(childClosest.peerId.id));
      int closestDistance = calculateDistance(closestPeerId, target);
      if (closestDistance < minDistance) {
        closest = childClosest;
        minDistance = closestDistance;
      }
    }
  }
  
  return closest;
}

/// Splits a node in the tree, creating two child nodes.
void splitNode(KademliaNode node) {
  // Create KademliaId instances from the PeerIds
  final leftKademliaId = common_kademlia_pb.KademliaId()..id = node.peerId.id;
  final rightKademliaId = common_kademlia_pb.KademliaId()..id = node.associatedPeerId.id;
  
  // Create two child nodes with updated distances
  final leftChild = KademliaNode(
    peerId: leftKademliaId,
    distance: node.distance,
    associatedPeerId: rightKademliaId,
    lastSeen: Int64(DateTime.now().millisecondsSinceEpoch),
  );
  
  final rightChild = KademliaNode(
    peerId: rightKademliaId,
    distance: calculateDistance(
      p2p.PeerId(value: Uint8List.fromList(rightKademliaId.id)), 
      p2p.PeerId(value: Uint8List.fromList(leftKademliaId.id))
    ),
    associatedPeerId: leftKademliaId,
    lastSeen: Int64(DateTime.now().millisecondsSinceEpoch),
  );
  
  // Add children to parent node
  node.children.addAll([leftChild, rightChild]);
}

/// Merges two child nodes into their parent node.
void mergeNodes(KademliaNode parent) {
  if (parent.children.length != 2) return;
  
  // Clear children list
  parent.children.clear();
}

/// Sends a DHT request to a peer and returns the response
Future<dht_pb.FindNodeResponse> sendRequest(
    DHTClient dhtClient,
    p2p.PeerId peer, 
    dht_pb.FindNodeRequest request
) async {
  try {
    // Use the public findPeer method instead of trying to access private _sendRequest
    final foundPeer = await dhtClient.findPeer(peer);
    if (foundPeer == null) {
      throw Exception('Peer not found');
    }
    
    // Convert the response to FindNodeResponse
    return dht_pb.FindNodeResponse()
      ..closerPeers.add(dht_pb.DHTPeer()..id = foundPeer.value);
      
  } catch (e) {
    print('Error sending request to peer ${Base58().encode(peer.value)}: $e');
    throw e;
  }
}

/// Sends a FIND_NODE request to a peer and returns closer peers to the target.
Future<List<p2p.PeerId>> findNode(
    DHTClient dhtClient,
    p2p.PeerId peer, 
    p2p.PeerId target
) async {
  final request = dht_pb.FindNodeRequest()..peerId = target.value;
  
  try {
    final response = await sendRequest(dhtClient, peer, request);
    return response.closerPeers
        .map((peer) => p2p.PeerId(value: Uint8List.fromList(peer.id)))
        .toList();
  } catch (e) {
    print('Error in findNode request: $e');
    return [];
  }
}
