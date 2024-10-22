// lib/src/protocols/dht/kademlia_tree/add_peer.dart
import 'package:ipfs/src/proto/dht/dht_messages.pb.dart';
import 'package:p2plib/p2plib.dart' as p2p;
import '../red_black_tree.dart';
import 'helpers.dart' as helpers;
import 'kademlia_node.dart';
import '../kademlia_tree.dart';
import 'bucket_management.dart';
import '/../src/proto/dht/add_peer.pb.dart';
import '/../src/proto/dht/common_kademlia.pb.dart';

extension AddPeer on KademliaTree {
  // Add a peer to the Kademlia tree
  void addPeer(p2p.PeerId peerId, p2p.PeerId associatedPeerId) {
    // Calculate the distance and bucket index
    int distance = helpers.calculateDistance(peerId, this.root!.peerId);
    int bucketIndex = helpers.getBucketIndex(distance);

    KademliaNode newNode = KademliaNode(peerId, distance, associatedPeerId);
    newNode.bucketIndex = bucketIndex;

    // Insert into the RedBlackTree
    this.buckets[bucketIndex].insert(peerId, newNode);

    // Handle bucket fullness - splitting or replacement
    if (this.buckets[bucketIndex].size > KademliaTree.kBucketSize) {
      // Access using class name
      _handleBucketFullness(bucketIndex, peerId, associatedPeerId);
    }
  }

  bool canSplitBucket(int bucketIndex) {
    // 1. Check if it's the last bucket
    if (bucketIndex == buckets.length - 1) {
      return false; // Cannot split the last bucket
    }

    // 2. Check if the distance range can be further divided
    int minDistance = 1 << (255 - bucketIndex); // Assuming 256-bit Peer IDs
    int maxDistance = (1 << (256 - bucketIndex)) - 1;

    // Check if there's a distance that would fall into a new bucket
    for (int distance = minDistance + 1; distance < maxDistance; distance++) {
      if (helpers.getBucketIndex(distance) == bucketIndex + 1) {
        return true; // Bucket can be split
      }
    }

    return false; // Distance range cannot be further divided
  }

  // Helper function to handle bucket fullness (splitting or replacement)
  void _handleBucketFullness(
      int bucketIndex, p2p.PeerId peerId, p2p.PeerId associatedPeerId) {
    if (canSplitBucket(bucketIndex)) {
      // TODO: Implement split bucket logic
    } else {
      // Apply replacement strategy
      KademliaNode? leastRecentlySeenNode =
          _findLeastRecentlySeenNode(bucketIndex);
      bool newNodeWasContact = _wasNodeContactInRecentLookup(peerId);

      if (newNodeWasContact) {
        // Replace the least recently seen node
        if (leastRecentlySeenNode != null) {
          buckets[bucketIndex].delete(leastRecentlySeenNode.peerId);
          KademliaNode newNode = KademliaNode(
              peerId,
              helpers.calculateDistance(peerId, root!.peerId),
              associatedPeerId);
          newNode.bucketIndex = bucketIndex;
          buckets[bucketIndex].insert(peerId, newNode);
        }
      } else {
        // Check node activity
        if (leastRecentlySeenNode != null &&
            _isNodeActive(leastRecentlySeenNode)) {
          // Drop the new node if the least recently seen is active
          return;
        } else {
          // Replace the least recently seen node
          if (leastRecentlySeenNode != null) {
            buckets[bucketIndex].delete(leastRecentlySeenNode.peerId);
          }
          KademliaNode newNode = KademliaNode(
              peerId,
              helpers.calculateDistance(peerId, root!.peerId),
              associatedPeerId);
          newNode.bucketIndex = bucketIndex;
          buckets[bucketIndex].insert(peerId, newNode);
        }
      }
    }
  }

// Helper functions
  KademliaNode? _findLeastRecentlySeenNode(int bucketIndex) {
    if (buckets[bucketIndex].isEmpty) {
      return null; // Bucket is empty, no nodes to find
    }

    KademliaNode? leastRecentlySeenNode;
    DateTime? oldestLastSeenTime;

    // Iterate through nodes in the bucket
    for (var nodeEntry in buckets[bucketIndex].entries) {
      var node = nodeEntry.value;
      DateTime? lastSeenTime =
          this.lastSeen[node.peerId]; // Access using 'this._lastSeen'

      if (lastSeenTime == null) {
        // If the node has no last seen time, consider it as the least recently seen
        leastRecentlySeenNode = node;
        break; // No need to check further
      } else if (oldestLastSeenTime == null ||
          lastSeenTime.isBefore(oldestLastSeenTime)) {
        // If this node's last seen time is older than the current oldest, update
        oldestLastSeenTime = lastSeenTime;
        leastRecentlySeenNode = node;
      }
    }

    return leastRecentlySeenNode;
  }

bool _wasNodeContactInRecentLookup(p2p.PeerId peerId) {
  // Access _recentContacts from the KademliaTree instance
  return this.recentContacts.contains(peerId); 
  }

Future<PingResponse> _receivePingResponse(p2p.PeerId peerId) async {
  // Assuming you have a stream of incoming messages from p2plib:
  final incomingMessageStream = p2p.incomingMessages; // Replace with your actual stream

  // Filter the stream to find a ping response from the specified peerId
  final pingResponse = await incomingMessageStream.firstWhere(
    (message) => message is PingResponse && message.peerId == peerId,
  );

  return pingResponse;
}



bool _isNodeActive(KademliaNode node) {
  // 1. Last seen time
  final now = DateTime.now();
  final lastSeenTime = this.lastSeen[node.peerId];
  final activityThreshold = Duration(minutes: 10); // Define your threshold here

  if (lastSeenTime == null || now.difference(lastSeenTime) > activityThreshold) {
    return false; // Node is inactive
  }

  // 2. Response to ping messages:
  bool pingSentSuccessfully = _sendPingMessage(node.peerId); // Placeholder

  if (!pingSentSuccessfully) {
    return false; // Ping failed, consider node inactive
  }

  // Check for ping response within a timeout period
  bool pingResponseReceived = false;
  try {
  // Use Future.any to wait for either a ping response or a timeout
  pingResponseReceived = await Future.any([
    _receivePingResponse(node.peerId), // Function to receive ping responses
    Future.delayed(Duration(seconds: 5)), // Timeout after 5 seconds
  ]).then((result) => result is PingResponse); // Check if result is a PingResponse
  } catch (error) {
    print('Error checking for ping response: $error'); // Handle potential errors
  }

  if (!pingResponseReceived) {
    return false; // No response within timeout, consider node inactive
  }


  // 3. Successful communication during lookups:
  final lookupHistory = _lookupSuccessHistory[node.peerId] ?? [];

  // TODO: Adjust the criteria for considering a node active based on lookup history
  // For example, you might check if the last 'n' lookups were successful,
  // or if a certain percentage of recent lookups were successful.
  // Here's a simple example:
  final recentLookups = lookupHistory.take(5); // Consider the last 5 lookups
  final successfulLookups = recentLookups.where((success) => success).length;
  final isActiveBasedOnLookups = successfulLookups >= 3; // Active if at least 3 successful

  if (!isActiveBasedOnLookups) {
    return false; // Node is inactive based on lookup history
  }

  // 4. Other relevant metrics or signals:
  //    - TODO: Consider any other metrics or signals that might indicate node activity in your environment.
  //    - For example, you might track the node's bandwidth usage, connection stability, or other relevant data.

  // Placeholder implementation (replace with your actual logic):
  //final now = DateTime.now(); // Already defined above
  //final lastSeenTime = this.lastSeen[node.peerId]; // Already defined above
  final isActive = lastSeenTime != null && now.difference(lastSeenTime) < Duration(minutes: 5);

  return isActive;
}

// Placeholder function for sending ping messages
bool _sendPingMessage(p2p.PeerId peerId) {
  // TODO: Replace with your actual ping sending logic using your network library
  // Example:
  // try {
  //   yourNetworkLibrary.sendMessage(peerId, pingMessage);
  //   return true; // Ping sent successfully
  // } catch (error) {
  //   print('Error sending ping message: $error');
  //   return false; // Ping failed
  // }
  print('Sending ping message to $peerId'); // Placeholder
  return true; // Assume ping sent successfully for this placeholder
}

}
