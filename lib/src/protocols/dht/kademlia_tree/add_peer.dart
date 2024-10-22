// lib/src/protocols/dht/kademlia_tree/
import 'dart:math';

import 'package:ipfs/src/proto/dht/dht_messages.pb.dart';
import 'package:p2plib/p2plib.dart' as p2p;
import '../red_black_tree.dart';
import 'helpers.dart' as helpers;
import 'kademlia_node.dart';
import '../kademlia_tree.dart';
import 'bucket_management.dart';
import '/../src/proto/dht/add_peer.pb.dart';
import '/../src/proto/dht/common_kademlia.pb.dart';
import 'dart:async';

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

    // Define _lookupSuccessHistory (adjust type as needed)
    Map<p2p.PeerId, List<bool>> _lookupSuccessHistory = {};

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

  Future<void> _handleBucketFullness(
      int bucketIndex, p2p.PeerId peerId, p2p.PeerId associatedPeerId) async {
    if (canSplitBucket(bucketIndex)) {
      // 1. Create a new bucket
      this.buckets.add(RedBlackTree<p2p.PeerId, KademliaNode>(
          compare: (p2p.PeerId a, p2p.PeerId b) =>
              a.toString().compareTo(b.toString())));

      // 2. Move nodes to appropriate buckets
      final originalBucket = this.buckets[bucketIndex];
      final newBucketIndex = bucketIndex + 1; // Index of the new bucket

      for (var nodeEntry in originalBucket.entries) {
        var node = nodeEntry.value;
        int distance =
            helpers.calculateDistance(node.peerId, this.root!.peerId);
        int newBucketIndexForNode = helpers.getBucketIndex(distance);

        if (newBucketIndexForNode == newBucketIndex) {
          originalBucket.delete(node.peerId);
          this.buckets[newBucketIndex].insert(node.peerId, node);
          node.bucketIndex = newBucketIndex;
        }
      }
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
            await _isNodeActive(leastRecentlySeenNode)) {
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
    final completer = Completer<PingResponse>();

    this.router.onMessage((message) {
      if (message is PingResponse && message.peerId == peerId) {
        completer.complete(message);
      }
    });

    return completer.future;
  }

  Future<bool> _isNodeActive(KademliaNode node) async {
    // 1. Last seen time
    final now = DateTime.now();
    final lastSeenTime = this.lastSeen[node.peerId];
    final activityactivityThreshold =
        Duration(minutes: 10); // Define your activityThreshold here

    if (lastSeenTime == null ||
        now.difference(lastSeenTime) > activityactivityThreshold) {
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
      ]).then((result) =>
          result is PingResponse); // Check if result is a PingResponse
    } catch (error) {
      print(
          'Error checking for ping response: $error'); // Handle potential errors
    }

    if (!pingResponseReceived) {
      return false; // No response within timeout, consider node inactive
    }

    // 3. Successful communication during lookups:
    final lookupHistory = lookupSuccessHistory[node.peerId] ?? [];

    final recentLookups =
        lookupHistory.take(10).toList(); // Consider the last 10 lookups
    final weightedSuccesses = recentLookups.asMap().entries.fold<double>(
      0,
      (sum, entry) {
        final weight = pow(0.8, entry.key); // Exponential decay for weight
        return sum + (entry.value ? weight : 0);
      },
    );

    final minimumConsecutiveSuccesses = 3;
    final hasConsecutiveSuccesses = recentLookups
        .sublist(0, minimumConsecutiveSuccesses)
        .every((success) => success);

    final isActiveBasedOnLookups = weightedSuccesses >= 2.0 &&
        hasConsecutiveSuccesses; // Adjust activityThresholds as needed

    if (!isActiveBasedOnLookups) {
      return false; // Node is inactive based on lookup history
    }

    // Calculate activity score based on additional metrics
    double activityScore = 0;
    activityScore += _calculateBandwidthScore(node);
    activityScore += _calculateConnectionStabilityScore(node);
    // Define the activityThreshold
    const double activityThreshold = 2.0; // Adjust as needed

    final isActive = now.difference(lastSeenTime) < Duration(minutes: 5) &&
        activityScore >= activityThreshold;

    return isActive;
  }

double _calculateConnectionStabilityScore(KademliaNode node) {
  // 1. Get connection stability statistics for the node
  final connectionStats = this.connectionStats[node.peerId]; // Assuming you have a connectionStats map

  if (connectionStats == null) {
    return 0; // No stats available, assign a neutral score
  }

  // 2. Calculate a score based on connection drops or disconnections
  // You can adjust the weights and formula to fit your specific needs
  final connectionStabilityScore = 1 - (connectionStats.disconnections / connectionStats.totalConnections); // Example: score based on disconnection rate

  // 3. Apply a normalization or scaling factor if necessary
  // This ensures that the score is within a desired range
  // Example: scaling to a score between 0 and 1
  // final normalizedScore = min(connectionStabilityScore / maxStability, 1.0);

  return connectionStabilityScore;
}




double _calculateBandwidthScore(KademliaNode node) {
  // 1. Get bandwidth statistics for the node
  final nodeStats = this.nodeStats[node.peerId]; // Assuming you have a nodeStats map

  if (nodeStats == null) {
    return 0; // No stats available, assign a neutral score
  }

  // 2. Calculate a score based on bandwidth sent and received
  // You can adjust the weights and formula to fit your specific needs
  final bandwidthScore = (nodeStats.bandwidthSent + nodeStats.bandwidthReceived) / 1000000; // Example: score based on total bandwidth in MB

  // 3. Apply a normalization or scaling factor if necessary
  // This ensures that the score is within a desired range
  // Example: scaling to a score between 0 and 1
  // final normalizedScore = min(bandwidthScore / maxBandwidth, 1.0);

  return bandwidthScore;
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
