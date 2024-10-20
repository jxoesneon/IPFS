// lib/src/protocols/dht/kademlia_tree.dart

import 'package:p2plib/p2plib.dart' as p2p;

/// Represents a Kademlia tree for efficient peer routing and lookup.
class KademliaTree {
  // 1. Node Structure
  /// Represents a node in the Kademlia tree.
  class _KademliaNode {
    final p2p.PeerId peerId;
    final int distance; // XOR distance from the local node
    final List<_KademliaNode> children; // Child nodes for branching
    int? bucketIndex; // Reference to the bucket the node belongs to

    _KademliaNode(this.peerId, this.distance) : children = [];
  }

  // 2. Tree Structure
  _KademliaNode? _root; // Root node of the tree
  List<RedBlackTree<_KademliaNode>> _buckets = []; // List of k-buckets

  // 3. Constructor
  KademliaTree(p2p.PeerId localPeerId) {
    _root = _KademliaNode(localPeerId, 0); 
    // Pre-allocate buckets (e.g., for 256-bit Peer IDs, you might have 256 buckets)
    for (int i = 0; i < 256; i++) {
      _buckets.add([]); 
    }
  }


  // 4. Core Kademlia Operations
  /// Adds a peer to the Kademlia tree.
  void addPeer(p2p.PeerId peerId, p2p.PeerId associatedPeerId) {
    int distance = _calculateDistance(peerId, _root!.peerId); // Calculate distance
    int bucketIndex = _getBucketIndex(distance); // Get bucket index

    // Create a new KademliaNode for the peer
    _KademliaNode newNode = _KademliaNode(peerId, distance);
    newNode.bucketIndex = bucketIndex;

    // Traverse the tree to find the appropriate position
    _KademliaNode? currentNode = _root;
    while (currentNode != null) {
      int currentDistance = _calculateDistance(peerId, currentNode.peerId); 

      // Determine the next node to traverse based on the distance
      if (currentDistance < currentNode.distance) {
        if (currentNode.children.isNotEmpty) {
          // Traverse to the left child if the distance is smaller
          currentNode = currentNode.children[0]; 
        } else {
          // If no left child, we've found the insertion point
          break; 
        }
      } else {
        if (currentNode.children.length > 1) {
          // Traverse to the right child if the distance is larger or equal
          currentNode = currentNode.children[1]; 
        } else {
          // If no right child, we've found the insertion point
          break;
        }
      }
    }

  // 4. Core Kademlia Operations
  /// Adds a peer to the Kademlia tree.
  void addPeer(p2p.PeerId peerId, p2p.PeerId associatedPeerId) {
    // ... (Calculate distance, Get bucket index, Create new node, Traverse tree) ...
    // Insert the new node into the tree or bucket
    if (currentNode == null) {
      _buckets[bucketIndex].insert(newNode);
    } else {
      // Insert the new node into the tree structure
      int currentDistance = _calculateDistance(peerId, currentNode.peerId);

      // Determine the child index based on the distance
      int childIndex = currentDistance < currentNode.distance ? 0 : 1;

      // Add the new node as a child of the current node
      currentNode.children.insert(childIndex, newNode); 
    }

    // Handle bucket fullness (consider splitting or replacement strategies)
    if (_buckets[bucketIndex].length > kBucketSize) {
      // Check if the bucket can be split
      if (bucketIndex < _buckets.length - 1) {
        // Split the bucket if it's not the last bucket
        splitBucket(bucketIndex);
        // Re-add the new peer after splitting (it might go into a new bucket)
        addPeer(peerId, associatedPeerId);
      } else {
        // If it's the last bucket and it's full, apply replacement strategy
        _KademliaNode? leastRecentlySeenNode = _findLeastRecentlySeenNode(bucketIndex);

        if (leastRecentlySeenNode != null) {
          // Remove the least recently seen node
          removePeer(leastRecentlySeenNode.peerId);

          // Add the new node
          _buckets[bucketIndex].insert(newNode); // Assuming you're using RedBlackTree
        } else {
          // No suitable node to replace, drop the new peer
          print('Bucket is full and cannot be split. Dropping new peer.');
        }
      }
    }
  }
  
  /// Finds the least recently seen node in a bucket.
  _KademliaNode? _findLeastRecentlySeenNode(int bucketIndex) {
    _KademliaNode? leastRecentlySeenNode;
    DateTime? leastRecentlySeenTime;

    for (var node in _buckets[bucketIndex]) { // Assuming you're using RedBlackTree
      DateTime? lastSeenTime = _lastSeen[node.peerId]; 
      if (lastSeenTime != null &&
          (leastRecentlySeenTime == null || lastSeenTime.isBefore(leastRecentlySeenTime))) {
        leastRecentlySeenNode = node;
        leastRecentlySeenTime = lastSeenTime;
      }
    }

    return leastRecentlySeenNode;
  }


  /// Removes a peer from the Kademlia tree.
  void removePeer(p2p.PeerId peerId) {
    int distance = _calculateDistance(peerId, _root!.peerId);
    int bucketIndex = _getBucketIndex(distance);

    // Traverse the tree to find the node associated with the peer ID
    _KademliaNode? currentNode = _root;
    _KademliaNode? parentNode; // Keep track of the parent node

    while (currentNode != null) {
      if (currentNode.peerId == peerId) {
        // Found the node to remove
        break;
      }

      parentNode = currentNode;
      int currentDistance = _calculateDistance(peerId, currentNode.peerId);

      // Determine the next node to traverse based on the distance
      currentNode = currentDistance < currentNode.distance
          ? currentNode.children.isNotEmpty? currentNode.children[0] : null
          : currentNode.children.length > 1 ? currentNode.children[1] : null;
    }

    // Remove the node from the tree (if found)
    if (currentNode != null) {
      if (parentNode == null) {
        // Removing the root node (special case)
        _root = null; // Or handle differently based on your requirements
      } else {
        // Remove the node from its parent's children list
        parentNode.children.remove(currentNode);
      }

      // Remove the node from its bucket
      _buckets[bucketIndex].remove(currentNode);
    }

    // Handle bucket emptiness (consider merging with other buckets)
    if (_buckets[bucketIndex].isEmpty) {
      // Check if the bucket can be merged with an adjacent bucket
      if (bucketIndex > 0 && bucketIndex < _buckets.length - 1) {
        // Try merging with the previous bucket
        if (_buckets[bucketIndex - 1].length + _buckets[bucketIndex + 1].length <= kBucketSize) {
          // Merge with the previous bucket if the combined size is within the limit
          _buckets[bucketIndex - 1].addAll(_buckets[bucketIndex + 1]);
          _buckets.removeAt(bucketIndex + 1);
          _buckets.removeAt(bucketIndex);

          // Update bucketIndex for nodes in the merged bucket
          for (var node in _buckets[bucketIndex - 1]) {
            node.bucketIndex = bucketIndex - 1;
          }
        } else {
            //if merging with previous not possible, try merging with next
            if (_buckets[bucketIndex + 1].length <= kBucketSize) {
                _buckets[bucketIndex + 1].addAll(_buckets[bucketIndex-1]);
                _buckets.removeAt(bucketIndex - 1);
                _buckets.removeAt(bucketIndex-1);
                for (var node in _buckets[bucketIndex + 1]) {
                    node.bucketIndex = bucketIndex + 1;
                }
            }
            //if not possible, do not do anything
        }
      }
    }
  }


  /// Retrieves the associated peer ID for a given peer.
  p2p.PeerId? getAssociatedPeer(p2p.PeerId peerId) {
    // Traverse the tree to find the node associated with the peer ID
    _KademliaNode? currentNode = _root;
    while (currentNode != null) {
      if (currentNode.peerId == peerId) {
        // Found the node, return the associated peer ID (if available)
        return currentNode.peerId; // Assuming associatedPeerId is stored within the node itself
      }

      int distance = _calculateDistance(peerId, currentNode.peerId);

      // Determine the next node to traverse based on the distance
      currentNode = distance < currentNode.distance
          ? currentNode.children.isNotEmpty ? currentNode.children[0] : null
          : currentNode.children.length > 1 ? currentNode.children[1] : null;
    }

    // Node not found, return null
    return null;
  }

  /// Finds the k closest peers to a target peer ID.
  List<p2p.PeerId> findClosestPeers(p2p.PeerId target, int k) {
    // Create a priority queue to store peers based on distance
    PriorityQueue<_KademliaNode> queue = PriorityQueue<_KademliaNode>(
      (_KademliaNode a, _KademliaNode b) =>
          _calculateDistance(target, a.peerId)
              .compareTo(_calculateDistance(target, b.peerId)),
    );

    // Add the root node to the queue
    if (_root != null) {
      queue.add(_root!);
    }

    // Traverse the tree, prioritizing closer branches
    List<p2p.PeerId> closestPeers = [];
    while (queue.isNotEmpty && closestPeers.length < k) {
      _KademliaNode currentNode = queue.removeFirst();
      closestPeers.add(currentNode.peerId);

      // Add child nodes to the queue
      queue.addAll(currentNode.children);
    }

    return closestPeers;
  }

  /// Performs an iterative node lookup for a target peer ID.
  Future<List<p2p.PeerId>> nodeLookup(p2p.PeerId target) async {
    // 1. Start with initial peers (closest peers to the target)
    int k = 20; // Number of closest peers to consider in each iteration (adjustable)
    List<p2p.PeerId> closestPeers = findClosestPeers(target, k);

    // 2. Iteratively query peers and update the closestPeers list
    while (true) {
      List<p2p.PeerId> newClosestPeers = [];
      for (var peerId in closestPeers) {
        // Query the peer identified by peerId for closer peers to the target
        try {
          // Assuming you have a method to send a FIND_NODE request
          List<p2p.PeerId> queriedPeers = await _findNode(peerId, target); 
          newClosestPeers.addAll(queriedPeers);
        } catch (e) {
          // Handle potential errors during peer querying (e.g., timeout, network error)
          print('Error querying peer $peerId: $e');
        }
      }

      // 3. Sort and select the k closest peers
      newClosestPeers
          .sort((a, b) => _calculateDistance(target, a).compareTo(_calculateDistance(target, b)));
      newClosestPeers = newClosestPeers.take(k).toList();

      // 4. Check for convergence or target found
      if (newClosestPeers.equals(closestPeers) || newClosestPeers.contains(target)) {
        // Node lookup has converged or the target has been found
        break;
      }

      // 5. Update the closestPeers list for the next iteration
      closestPeers = newClosestPeers;
    }

    // 6. Return the closestPeers list
    return closestPeers;
  }

  /// Refreshes the Kademlia tree by periodically checking and updating buckets.
  void refresh() {
    // 1. Iterate through buckets and check the last seen time of each peer
    for (var bucket in _buckets) {
      for (var node in bucket) {
        // Check if the peer has been seen recently
        DateTime? lastSeenTime = _lastSeen[node.peerId];
        if (lastSeenTime != null &&
            DateTime.now().difference(lastSeenTime) > refreshTimeout) {
          // 2. Evict stale peers
          removePeer(node.peerId);
          _lastSeen.remove(node.peerId); // Remove from last seen records
        } else {
          // If the peer has been seen recently, or is new, update last seen time
          _lastSeen[node.peerId] = DateTime.now();
        }
      }
    }
  }
    
    //timeout for refresh
    final refreshTimeout = Duration(minutes: 30);

  /// Splits a bucket when it becomes full.
  void splitBucket(int bucketIndex) {
    // 1. Create a new bucket
    _buckets.insert(bucketIndex + 1, []);

  /// Splits a bucket when it becomes full.
  void splitBucket(int bucketIndex) {
    // 1. Create a new bucket (a new Red-Black Tree)
    _buckets.insert(bucketIndex + 1, RedBlackTree<_KademliaNode>(
        // Assuming you have a RedBlackTree class
        compare: (_KademliaNode a, _KademliaNode b) =>
            a.peerId.compareTo(b.peerId)));

    // 2. Move peers from the original bucket to the new bucket based on their distances
    // Get all nodes from the original bucket
    List<_KademliaNode> nodesToMove = _buckets[bucketIndex].toList();

    // Iterate and move nodes to the new bucket if they belong there
    for (var node in nodesToMove) {
      if (_getBucketIndex(node.distance) == bucketIndex + 1) {
        _buckets[bucketIndex].remove(node); // Remove from original bucket
        _buckets[bucketIndex + 1].insert(node); // Insert into new bucket
        node.bucketIndex = bucketIndex + 1; // Update bucket index
      }
    }

    print('Bucket $bucketIndex split into $bucketIndex and ${bucketIndex + 1}'); // Log the split
    refresh(); // Trigger a refresh
    // Edge case: Empty bucket
    if (_buckets[bucketIndex].isEmpty) {
      return; // Bucket is empty, no need to split
    }

    // Edge case: Root bucket
    if (bucketIndex == 0) {
      // Handle root bucket split (e.g., create new root node)
      // ... (logic to handle root bucket split) ...
    }

    // Edge case: Last bucket
    if (bucketIndex == _buckets.length - 1) {
      // Handle last bucket split (e.g., prevent further splits or apply alternative logic)
      // ... (logic to handle last bucket split) ...
    }

    // 1. Create a new bucket (a new Red-Black Tree)
    _buckets.insert(bucketIndex + 1, RedBlackTree<_KademliaNode>(
        // Assuming you have a RedBlackTree class
        compare: (_KademliaNode a, _KademliaNode b) =>
            a.peerId.compareTo(b.peerId)));

    // 2. Move peers from the original bucket to the new bucket based on their distances
    // Get all nodes from the original bucket
    List<_KademliaNode> nodesToMove = _buckets[bucketIndex].toList();

    // Iterate and move nodes to the new bucket if they belong there
    for (var node in nodesToMove) {
      if (_getBucketIndex(node.distance) == bucketIndex + 1) {
        _buckets[bucketIndex].remove(node); // Remove from original bucket
        _buckets[bucketIndex + 1].insert(node); // Insert into new bucket
        node.bucketIndex = bucketIndex + 1; // Update bucket index
      }
    }
    print('Bucket $bucketIndex split into $bucketIndex and ${bucketIndex + 1}'); // Log the split
    refresh();
    // Check for further splits if needed
    if (_buckets[bucketIndex + 1].length > kBucketSize && 
        bucketIndex + 1 < _buckets.length - 1) { // Check if new bucket is full and can be split further
      splitBucket(bucketIndex + 1); // Recursively split the new bucket
    }
  }


  /// Merges two buckets when they become underpopulated.
  void mergeBuckets(int bucketIndex1, int bucketIndex2) {
    // 1. Ensure bucketIndex1 is the smaller index (for consistency)
    if (bucketIndex1 > bucketIndex2) {
      int temp = bucketIndex1;
      bucketIndex1 = bucketIndex2;
      bucketIndex2 = temp;
    }

    // 2. Check if the buckets are adjacent and can be merged
    if (bucketIndex2 == bucketIndex1 + 1 && 
        _buckets[bucketIndex1].length + _buckets[bucketIndex2].length <= kBucketSize) {

      // 3. Move peers from bucketIndex2 to bucketIndex1
      for (var node in _buckets[bucketIndex2].toList()) {
        _buckets[bucketIndex1].insert(node); // Assuming you're using RedBlackTree
        node.bucketIndex = bucketIndex1; // Update bucket index
      }

      // 4. Remove the empty bucketIndex2
      _buckets.removeAt(bucketIndex2);
    }
    //if not possible, do not do anything
  }


  // 5. Helper Methods

  /// Calculates the XOR distance between two Peer IDs.
  int _calculateDistance(p2p.PeerId a, p2p.PeerId b) {
    // Get the byte representations of the Peer IDs
    List<int> bytesA = a.bytes;
    List<int> bytesB = b.bytes;

    // Calculate the XOR distance
    int distance = 0;
    int minLength = bytesA.length < bytesB.length ? bytesA.length : bytesB.length;
    for (int i = 0; i < minLength; i++) {
      distance = distance | (bytesA[i] ^ bytesB[i]) << (8*(minLength - 1 - i) );
    }


    return distance;
  }

  /// Finds the bucket index for a given distance.
  int _getBucketIndex(int distance) {
    // Assuming 256 buckets (for 256-bit Peer IDs)
    // and the distance is represented as an integer
    if(distance==0) return 0;
    int bucketIndex = 255 - (distance.bitLength - 1);
    return bucketIndex;
  }

  /// Finds the closest node to a target peer ID in a given subtree.
  _KademliaNode? _findClosestNode(p2p.PeerId target, _KademliaNode? currentNode) {
    if (currentNode == null) {
      return null; // Base case: empty subtree
    }

    _KademliaNode? closestNode = currentNode;
    int closestDistance = _calculateDistance(target, currentNode.peerId);

    // Recursively search left and right subtrees
    for (var child in currentNode.children) {
      _KademliaNode? candidateNode = _findClosestNode(target, child);
      if (candidateNode != null) {
        int candidateDistance = _calculateDistance(target, candidateNode.peerId);
        if (candidateDistance < closestDistance) {
          closestNode = candidateNode;
          closestDistance = candidateDistance;
        }
      }
    }

    return closestNode;
  }

  /// Splits a node in the tree, creating two child nodes.
  void _splitNode(_KademliaNode node) {
    // 1. Determine the split point (e.g., midpoint of the node's distance range)
    int splitPoint = node.distance ~/ 2; // Example: using half the distance

    // 2. Create two new child nodes
    _KademliaNode leftChild = _KademliaNode(null, splitPoint); // Adjust node creation as needed
    _KademliaNode rightChild = _KademliaNode(null, node.distance); // Adjust node creation as needed


    // 3. Redistribute child nodes (if applicable)
    // Assuming node.children is a list of child nodes
    for (var child in node.children) {
      if (_calculateDistance(child.peerId!, node.peerId!) < splitPoint) {
        leftChild.children.add(child);
      } else {
        rightChild.children.add(child);
      }
    }
    
    // 4. Update the original node's children
    node.children = [leftChild, rightChild];


    // Update metadata for child nodes (if applicable)
    leftChild.updateMetadata( /* ... */ ); // Example: updating distance range
    rightChild.updateMetadata( /* ... */ );

    // Update metadata for the original node (if applicable)
    node.updateMetadata( /* ... */ );

    // Handle Red-Black Tree properties (if applicable)
    leftChild.color = NodeColor.RED;
    rightChild.color = NodeColor.RED;

    // Check for violations and perform rotations/adjustments
    if (node.color == NodeColor.RED) { 
      // Potential violation (red node with red children)

      // Get parent and grandparent of the original node
      _KademliaNode? parent = node.parent;
      _KademliaNode? grandparent = parent?.parent;

      if (grandparent != null) { // Ensure grandparent exists
        // Get uncle (sibling of parent)
        _KademliaNode? uncle = grandparent.children[0] == parent
            ? grandparent.children[1] // If parent is left child, uncle is right child
            : grandparent.children[0]; // If parent is right child, uncle is left child

        if (uncle?.color == NodeColor.RED) {
          // Case 1: Uncle is red (recoloring)
          parent!.color = NodeColor.BLACK;
          uncle!.color = NodeColor.BLACK;
          grandparent.color = NodeColor.RED;
          // Recursively check for violations on grandparent
          _checkAndAdjustRedBlackProperties(grandparent); 
        } else {
          // Case 2/3: Uncle is black (rotations and recoloring)
          if (parent == grandparent.children[0] && node == parent.children[1]) { // if this node is the original node
            // Case 2: Node is right child of left child of grandparent (left rotation)
            _rotateLeft(parent);
            // Update references to now node is the parent
            node = parent;
            parent = node.parent;
          } else if (parent == grandparent.children[1] && node == parent.children[0]) {
            // Case 3: Node is left child of right child of grandparent (right rotation)
            _rotateRight(parent);
            node = parent;
            parent = node.parent;
          }

          // Case 2/3 (after rotation if necessary): Recoloring and rotation on grandparent
          parent!.color = NodeColor.BLACK;
          grandparent.color = NodeColor.RED;

          if (node == parent.children[0]) { // if this node is the original node
            // Node is left child of parent, rotate right on grandparent
            _rotateRight(grandparent);
          } else {
            // Node is right child of parent, rotate left on grandparent
            _rotateLeft(grandparent);
          }
        }
      }
    } else {
      print('No violation, tree properties are maintained')
    }

    // Trigger bucket refresh (if applicable)
    refreshBucket(node.bucketIndex); // Assuming you have a bucket-specific refresh method

    // Log or print node split information
    print('Node split: ${node.peerId} -> ${leftChild.peerId}, ${rightChild.peerId}');

    // Handle edge cases
      if (node == _buckets[node.bucketIndex].root) {
      // Logic to update bucket's root pointer
      // Choose one of the new child nodes as the new root
      _buckets[node.bucketIndex].root = leftChild.distance < rightChild.distance ? leftChild : rightChild;
    } else if (node.children.isEmpty) {
      // Skip the split
      return; 
    } else if (splitPoint - node.distance < threshold || node.distance - splitPoint < threshold) {
      // 1. Identify adjacent node or bucket
      // This might involve checking the parent node or the neighboring buckets in the Kademlia tree
      _KademliaNode? adjacentNode = _findAdjacentNode(node); // Assuming you have a helper function to find adjacent nodes
      int? adjacentBucketIndex = _findAdjacentBucketIndex(node.bucketIndex); // Assuming you have a helper function to find adjacent buckets

      // 2. Check merging conditions
      // Ensure that merging is allowed based on your tree structure, bucket organization, and distance ranges
      bool canMergeWithAdjacentNode = adjacentNode != null &&
          _calculateDistance(node.peerId, adjacentNode.peerId) < mergeDistanceThreshold && // Check distance between nodes
          node.children.length + adjacentNode.children.length <= maxCombinedChildren; // Check combined children count

      // Example conditions for merging with adjacent bucket:
      bool canMergeWithAdjacentBucket = adjacentBucketIndex != null &&
          _buckets[node.bucketIndex].length + _buckets[adjacentBucketIndex].length <= kBucketSize; // Check combined bucket size

      // 3. Perform the merge
      if (adjacentNode != null && canMergeWithAdjacentNode) {
        // Merge with adjacent node
        // 1. Combine children
        node.children.addAll(adjacentNode.children); // Add adjacent node's children to current node's children
        
        // 2. Update distances
        node.distance = _calculateMergedNodeDistance(node, adjacentNode); 

        // 3. Maintain Red-Black Tree properties
        // If necessary, perform rotations or color adjustments to maintain the Red-Black Tree properties
        // ... (logic to maintain Red-Black Tree properties, e.g., using rotateLeft, rotateRight, recolor) ...
        _checkAndAdjustRedBlackProperties(node);

        // 4. Remove adjacent node from the tree
        // This might involve updating the parent node's children or other tree structure adjustments
        _removeNodeFromTree(adjacentNode); // Assuming you have a helper function to remove nodes from the tree

      } else if (adjacentBucketIndex != null && canMergeWithAdjacentBucket) {
        // Merge with adjacent bucket
        // 1. Move nodes from current bucket to adjacent bucket
        for (var nodeToMove in _buckets[node.bucketIndex].toList()) { // Assuming you have a toList method to get all nodes in a bucket
          _buckets[adjacentBucketIndex].insert(nodeToMove);  // Assuming you have an insert method in your bucket structure
          nodeToMove.bucketIndex = adjacentBucketIndex;     // Update bucket index of the moved node
        }

        // 2. Remove the current bucket (now empty)
        _buckets.removeAt(node.bucketIndex);

        // 3. Maintain Red-Black Tree properties in the adjacent bucket
        // If necessary, perform rotations or color adjustments to maintain the Red-Black Tree properties
        // ... (logic to maintain Red-Black Tree properties in the adjacent bucket) ...
        _checkAndAdjustRedBlackProperties(_buckets[adjacentBucketIndex].root);
      }
    } 

  }

  /// Merges two child nodes into their parent node.
  void _mergeNodes(_KademliaNode parent, _KademliaNode child1, _KademliaNode child2) {
    // 1. Combine child nodes' data
    // Assuming you have a way to access and combine data stored in the nodes
    // For example, if you're storing peer IDs:
    parent.peerId = child1.peerId; // Or choose whichever peerId is appropriate for the merging logic

    // If you're storing distance ranges:
    parent.distance = _calculateMergedNodeDistance(child1, child2);

    // Logic to combine other relevant data
    if (parent.data is Map && child1.data is Map && child2.data is Map) {
      // Assuming 'data' stores a map of key-value pairs for other relevant data
      (parent.data as Map).addAll((child1.data as Map));
      (parent.data as Map).addAll((child2.data as Map));
    } else if (parent.data is List && child1.data is List && child2.data is List) {
      // Assuming 'data' stores a list of items
      (parent.data as List).addAll((child1.data as List));
      (parent.data as List).addAll((child2.data as List));
    } else {
      parent.data = child1.data; 
    }

    // 2. Update parent-child relationships
    parent.children.remove(child1);
    parent.children.remove(child2);

    // 3. Maintain Red-Black Tree properties
    _checkAndAdjustRedBlackProperties(parent);
  }
  
  int _calculateMergedNodeDistance(_KademliaNode node1, _KademliaNode node2) {
    // Distance is a single integer representing the upper bound of the range
    // and you want to encompass both nodes' ranges
    return node1.distance > node2.distance ? node1.distance : node2.distance; 
  }



  /// Sends a FIND_NODE request to a peer and returns closer peers to the target.
  Future<List<p2p.PeerId>> _findNode(p2p.PeerId peerId, p2p.PeerId target) async {
    try {
      // 1. Construct FIND_NODE request
      // This would involve creating a message or data structure according to your IPFS or libp2p implementation
      var request = _createFindNodeRequest(target); // Assuming you have a helper function to create the request

      // 2. Send request to the peer
      // Use your IPFS or libp2p implementation to send the request to the peer identified by 'peerId'
      var response = await _sendMessageToPeer(peerId, request); // Assuming you have a helper function to send messages

      // 3. Parse response and extract closer peers
      // This would involve parsing the response message and extracting the list of peer IDs
      List<p2p.PeerId> closerPeers = _extractCloserPeersFromResponse(response); // Assuming you have a helper function to extract peers

      return closerPeers;
    } catch (e) {
      // Handle potential errors during network communication
      print('Error sending FIND_NODE request to peer $peerId: $e');
      return []; // Return an empty list in case of errors
    }
  }
}
