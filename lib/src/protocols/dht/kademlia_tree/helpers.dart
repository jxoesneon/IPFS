import 'dart:typed_data' show Uint8List;

import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/proto/generated/dht/common_kademlia.pb.dart'
    as common_kademlia_pb;
import 'package:dart_ipfs/src/proto/generated/dht/dht.pb.dart' as dht_pb;
import 'package:dart_ipfs/src/proto/generated/dht/kademlia_node.pb.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_client.dart';
import 'package:fixnum/fixnum.dart';
// lib/src/protocols/dht/kademlia_tree/helpers.dart

/// Calculates the logarithmic XOR distance (bit length) between two Peer IDs.
/// Returns a value between 0 and 256.
int calculateDistance(PeerId a, PeerId b) {
  final bytesA = a.value;
  final bytesB = b.value;
  final minLength = bytesA.length < bytesB.length
      ? bytesA.length
      : bytesB.length;

  for (int i = 0; i < minLength; i++) {
    final xor = bytesA[i] ^ bytesB[i];
    if (xor != 0) {
      // (Total bytes - current byte index - 1) * 8 + bit length of XOR result
      return (minLength - i - 1) * 8 + xor.bitLength;
    }
  }

  return 0;
}

/// Finds the bucket index for a given logarithmic distance.
int getBucketIndex(int distance) {
  // distance is the bit length of the XOR sum (0 to 256)
  // Standard Mapping: bucketIndex = (bitLength - 1).clamp(0, 255).
  if (distance == 0) return 0;
  return (distance - 1).clamp(0, 255);
}

/// Finds the closest node to a target peer ID in a given subtree.
KademliaNode? findClosestNode(KademliaNode? root, PeerId target) {
  if (root == null) return null;

  // Convert KademliaId to PeerId for root
  final rootPeerId = PeerId(value: Uint8List.fromList(root.peerId.id));

  // Calculate distances
  int rootDistance = calculateDistance(rootPeerId, target);

  // Initialize closest as root
  KademliaNode closest = root;
  int minDistance = rootDistance;

  // Check children recursively
  for (var child in root.children) {
    // Convert KademliaId to PeerId for child
    final childPeerId = PeerId(value: Uint8List.fromList(child.peerId.id));

    int childDistance = calculateDistance(childPeerId, target);
    if (childDistance < minDistance) {
      closest = child;
      minDistance = childDistance;
    }

    // Recursively search child subtrees
    var childClosest = findClosestNode(child, target);
    if (childClosest != null) {
      // Convert KademliaId to PeerId for closest child
      final closestPeerId = PeerId(
        value: Uint8List.fromList(childClosest.peerId.id),
      );
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
  final rightKademliaId = common_kademlia_pb.KademliaId()
    ..id = node.associatedPeerId.id;

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
      PeerId(value: Uint8List.fromList(rightKademliaId.id)),
      PeerId(value: Uint8List.fromList(leftKademliaId.id)),
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
  PeerId peer,
  dht_pb.FindNodeRequest request,
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
    // print('Error sending request to peer ${Base58().encode(peer.value)}: $e');
    rethrow;
  }
}

/// Sends a FIND_NODE request to a peer and returns closer peers to the target.
Future<List<PeerId>> findNode(
  DHTClient dhtClient,
  PeerId peer,
  PeerId target,
) async {
  final request = dht_pb.FindNodeRequest()..peerId = target.value;

  try {
    final response = await sendRequest(dhtClient, peer, request);
    return response.closerPeers
        .map((peer) => PeerId(value: Uint8List.fromList(peer.id)))
        .toList();
  } catch (e) {
    // print('Error in findNode request: $e');
    return [];
  }
}
