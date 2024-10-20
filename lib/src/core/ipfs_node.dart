// lib/src/core/ipfs_node.dart

import 'dart:async';
import 'dart:typed_data';

import 'package:p2plib/p2plib.dart' as p2p;

import 'config/config.dart';
import 'data_structures/block.dart';
import 'data_structures/link.dart';
import '../protocols/bitswap/bitswap.dart';
import '../protocols/bitswap/ledger.dart'; // Import BitLedger
import '../protocols/dht/dht_client.dart';
import '../protocols/pubsub/pubsub_client.dart';
import '../routing/content_routing.dart';
import '../routing/dnslink_resolver.dart';
import '../storage/datastore.dart';
import '../transport/circuit_relay_client.dart';
import '../transport/p2plib_router.dart';
import 'pubsub_handler.dart';

/// The main class representing an IPFS node.
class IPFSNode {
  /// Creates a new IPFS node with the given [config].
  IPFSNode(this.config) {
    _router = P2plibRouter(config);
    _datastore = Datastore(config.datastorePath);
    _ledger = BitLedger(); // Initialize BitLedger
    _bitswap = Bitswap(
        _router, _ledger, _datastore, _peerId); // Pass peerId to Bitswap
    _dht = DHTClient(this);
    _pubsub = PubSubClient(this);
    _circuitRelay = CircuitRelayClient(this);
    _contentRouting = ContentRouting(this);
    _dnslinkResolver = DNSLinkResolver();
  }

  Stream<String> get onNewContent => _newContentController.stream;

  /// The ledger used to track blocks and peers in Bitswap.
  late final BitLedger _ledger;

  /// The peer ID of this node.
  String get _peerId => _router.peerID; // Assuming P2plibRouter provides peerID

  /// The configuration for this IPFS node.
  final IPFSConfig config;

  /// The datastore used to store IPFS blocks.
  late final Datastore _datastore;

  /// The router used for network communication.
  late final P2plibRouter _router;

  /// The DHT client for finding peers and content.
  late final DHTClient _dht;

  /// The PubSub client for subscribing to and publishing messages.
  late final PubSubClient _pubsub;

  /// The circuit relay client for NAT traversal.
  late final CircuitRelayClient _circuitRelay;

  /// The content routing module.
  late final ContentRouting _contentRouting;

  /// The DNSLink resolver.
  late final DNSLinkResolver _dnslinkResolver;

  /// The metrics collector for gathering statistics.
  late final MetricsCollector
      _metricsCollector; // Assuming you have a MetricsCollector class

  /// The IPLD resolver for resolving IPLD links.
  late final IPLDResolver
      _ipldResolver; // Assuming you have an IPLDResolver class

  /// The Graphsync module for synchronizing data.
  late final Graphsync _graphsync; // Assuming you have a Graphsync class

  /// The set of pinned CIDs.
  final Set<String> pinnedCIDs = {};

  /// The stream controller for new content notifications.
  final _newContentController = StreamController<String>.broadcast();

  /// The stream controller for content update notifications.
  final _contentUpdatedController = StreamController<ContentUpdate>.broadcast();

  /// The stream controller for peer joined notifications.
  final _peerJoinedController = StreamController<String>.broadcast();

  /// The stream controller for peer left notifications.
  final _peerLeftController = StreamController<String>.broadcast();

  /// The stream controller for node events.
  final _nodeEventsController = StreamController<NodeEvent>.broadcast();

  /// The stream controller for peer events.
  final _peerEventsController = StreamController<PeerEvent>.broadcast();

  /// The stream controller for network events.
  final _networkEventsController = StreamController<NetworkEvent>.broadcast();

  /// The stream controller for bandwidth events.
  final _bandwidthEventsController =
      StreamController<BandwidthEvent>.broadcast();

  /// The stream controller for pinning events.
  final _pinningEventsController = StreamController<PinningEvent>.broadcast();

  /// The stream controller for block events.
  final _blockEventsController = StreamController<BlockEvent>.broadcast();

  /// The stream controller for datastore events.
  final _datastoreEventsController =
      StreamController<DatastoreEvent>.broadcast();

  /// The stream controller for application-specific messages.
  final _applicationMessageController =
      StreamController<ApplicationMessage>.broadcast();

  /// The peer ID of this node.
  String get peerID => _router.peerID;

  /// Starts the IPFS node.
  /// Starts the IPFS node.
  Future<void> start() async {
    // 1. Initialize the datastore
    await _datastore.init();

    // 2. Start the router
    await _router.start();

    // 3. Start the Bitswap module
    await _bitswap.start();

    // 4. Start the DHT client
    await _dht.start();

    // 5. Start the PubSub client
    await _pubsub.start();

    // 6. Start the Circuit Relay client
    await _circuitRelay.start();

    // 7. Start the content routing module
    await _contentRouting.start();

    // 8. Start the metrics collector
    await _metricsCollector.start();

    // 9. Start the IPLD resolver
    await _ipldResolver.start();

    // 10. Start the Graphsync module
    await _graphsync.start();

    // 11. (Optional) Load pinned CIDs from the datastore
    final pinnedCIDs = await _datastore.loadPinnedCIDs();
    this.pinnedCIDs.addAll(pinnedCIDs);

    // 12. (Optional) Perform other initialization tasks
    // ...
  }

  /// Stops the IPFS node.
  Future<void> stop() async {
    // 1. (Optional) Persist pinned CIDs to the datastore
    await _datastore.persistPinnedCIDs(pinnedCIDs);

    // 2. Stop the Graphsync module
    await _graphsync.stop();

    // 3. Stop the IPLD resolver
    await _ipldResolver.stop();

    // 4. Stop the metrics collector
    await _metricsCollector.stop();

    // 5. Stop the content routing module
    await _contentRouting.stop();

    // 6. Stop the Circuit Relay client
    await _circuitRelay.stop();

    // 7. Stop the PubSub client
    await _pubsub.stop();

    // 8. Stop the DHT client
    await _dht.stop();

    // 9. Stop the Bitswap module
    await _bitswap.stop();

    // 10. Stop the router
    await _router.stop();

    // 11. Close the datastore
    await _datastore.close();

    // 12. (Optional) Perform other cleanup tasks
    // ...
  }

  /// Adds a file to IPFS.
  Future<String> addFile(Uint8List data) async {
    // 1. Create an IPFS 'Node' object to represent the file
    final fileNode = Node(
      nodeType: NodeType.file,
      data: data,
      links: [], // Files don't have links to other nodes
    );

    // 2. Create a Block with the file data
    final block =
        Block(data: fileNode.toBytes()); // You'll need to implement toBytes()

    // 3. Calculate the CID of the block
    final cid = await calculateCID(
        block.data); // Implement calculateCID (using multihash)

    // 4. Store the block in the datastore
    await _datastore.put(cid, block);

    // 5. (Optional) Announce the availability of the block to the network (Bitswap)
    _bitswap.provide(cid);

    // 6. Return the CID of the file
    return cid;
  }

  // Helper function to calculate the size of a directory recursively
  Future<int> calculateDirectorySize(
      Map<String, dynamic> directoryContent) async {
    var totalSize = 0;
    for (var entry in directoryContent.entries) {
      if (entry.value is Uint8List) {
        totalSize += (entry.value as Uint8List).length;
      } else if (entry.value is Map<String, dynamic>) {
        totalSize += await calculateDirectorySize(entry.value);
      }
    }
    return totalSize;
  }

  /// Adds a directory to IPFS.
  Future<String> addDirectory(Map<String, dynamic> directoryContent) async {
    // 1. Create a list to store the links to child nodes
    final links = <Link>[];

    // 2. Iterate through the directory content
    for (var entry in directoryContent.entries) {
      final name = entry.key;
      final content = entry.value;

      if (content is Uint8List) {
        // If the content is a Uint8List, it's a file
        final fileCid = await addFile(content); // Add the file recursively
        links.add(Link(name: name, cid: fileCid, size: content.length));
      } else if (content is Map<String, dynamic>) {
        // If the content is a Map, it's a subdirectory
        final subdirCid =
            await addDirectory(content); // Add the subdirectory recursively

        // Calculate the directory size recursively
        var dirSize = 0;
        for (var subEntry in content.entries) {
          if (subEntry.value is Uint8List) {
            dirSize += (subEntry.value as Uint8List).length;
          } else if (subEntry.value is Map<String, dynamic>) {
            // Recursive call to calculate size of nested directories
            dirSize += await calculateDirectorySize(subEntry.value);
          }
        }

        links.add(Link(name: name, cid: subdirCid, size: dirSize));
      } else {
        throw ArgumentError('Invalid directory content: $content');
      }
    }

    // 3. Create an IPFS 'Node' object to represent the directory
    final directoryNode = Node(
      nodeType: NodeType.directory,
      data: null, // Directories don't have data
      links: links,
    );

    // 4. Create a Block with the directory node data
    final block = Block(
        data: directoryNode.toBytes()); // You'll need to implement toBytes()

    // 5. Calculate the CID of the block
    final cid = await calculateCID(
        block.data); // Implement calculateCID (using multihash)

    // 6. Store the block in the datastore
    await _datastore.put(cid, block);

    // 7. (Optional) Announce the availability of the block to the network (Bitswap)
    _bitswap.provide(cid);

    // 8. Return the CID of the directory
    return cid;
  }

  /// Gets a block from IPFS.
  Future<Uint8List?> get(String cid, {String path = ''}) async {
    // 1. Retrieve the block from the datastore
    var block = await _datastore.get(cid);
    if (block == null) {
      // If the block is not found locally, try to fetch it from the network
      // (using Bitswap)
      try {
        block = await _bitswap.wantBlock(
            cid); // Assuming Bitswap.wantBlock fetches and returns the block
      } catch (e) {
        // Handle the error appropriately (e.g., log it, throw a custom exception)
        print('Error fetching block from network: $e');
        return null;
      }
    }

    // 2. Deserialize the block data into a Node object
    final node =
        Node.fromBytes(block.data); // You'll need to implement fromBytes()

    // 3. If a path is provided, traverse the DAG to find the requested file
    if (path.isNotEmpty) {
      final pathSegments = path.split('/');
      var currentNode = node;
      for (var segment in pathSegments) {
        final link =
            currentNode.links.firstWhereOrNull((link) => link.name == segment);
        if (link == null) {
          // Path segment not found
          return null;
        }
        // Fetch the block for the next node in the path
        final nextBlock = await _datastore.get(link.cid);
        if (nextBlock == null) {
          // Block not found locally, try fetching from the network (TODO as above)
          return null;
        }
        currentNode = Node.fromBytes(nextBlock.data);
      }
      // If the final node is a file, return its data
      if (currentNode.nodeType == NodeType.file) {
        return currentNode.data;
      } else {
        // If the final node is a directory, return null (or consider returning a directory listing)
        return null;
      }
    } else {
      // If no path is provided, and the node is a file, return its data
      if (node.nodeType == NodeType.file) {
        return node.data;
      } else {
        // If the node is a directory, return null (or consider returning a directory listing)
        return null;
      }
    }
  }

  /// Lists the contents of a directory in IPFS.
  Future<List<Link>> ls(String cid) async {
    // 1. Retrieve the block from the datastore
    var block = await _datastore.get(cid);
    if (block == null) {
      // If the block is not found locally, try to fetch it from the network
      // (using Bitswap)
      try {
        block = await _bitswap.wantBlock(
            cid); // Assuming Bitswap.wantBlock fetches and returns the block
      } catch (e) {
        // Handle the error appropriately (e.g., log it, throw a custom exception)
        print('Error fetching block from network: $e');
        return [];
      }
    }

    // 2. Deserialize the block data into a Node object
    final node = Node.fromBytes(block.data);

    // 3. If the node is a directory, return its links
    if (node.nodeType == NodeType.directory) {
      return node.links;
    } else {
      // If the node is not a directory, return an empty list (or throw an error)
      return [];
    }
  }

  /// Pins a CID to prevent it from being garbage collected.
  Future<void> pin(String cid) async {
    // 1. Check if the CID is already pinned
    if (_node.pinnedCIDs.contains(cid)) {
      return; // Already pinned
    }

    // 2. (Optional) Fetch the block from the network if it's not locally available
    if (!_datastore.has(cid)) {
      try {
        await _bitswap.wantBlock(cid); // Fetch the block using Bitswap
      } catch (e) {
        // Handle the error appropriately (e.g., log it, throw a custom exception)
        print('Error fetching block from network: $e');
        return;
      }
    }

    // 3. Add the CID to the set of pinned CIDs
    _node.pinnedCIDs.add(cid);

    // 4. Persist the pinned CIDs to the datastore (or other persistent storage)
    await _datastore.persistPinnedCIDs(_node.pinnedCIDs);

    // 5. (Optional) Recursively pin the links of the pinned node if it's a directory
    final block = await _datastore.get(cid);
    if (block != null) {
      final node = Node.fromBytes(block.data);
      if (node.nodeType == NodeType.directory) {
        for (var link in node.links) {
          await pin(link.cid); // Recursively pin child nodes
        }
      }
    }
  }

  /// Unpins a CID.
  Future<void> unpin(String cid) async {
    // 1. Check if the CID is actually pinned
    if (!_node.pinnedCIDs.contains(cid)) {
      return; // Not pinned, nothing to do
    }

    // 2. Remove the CID from the set of pinned CIDs
    _node.pinnedCIDs.remove(cid);

    // 3. Persist the updated set of pinned CIDs
    await _datastore.persistPinnedCIDs(_node.pinnedCIDs);

    // 4. (Optional) Recursively unpin the links of the unpinned node if it's a directory
    final block = await _datastore.get(cid);
    if (block != null) {
      final node = Node.fromBytes(block.data);
      if (node.nodeType == NodeType.directory) {
        for (var link in node.links) {
          await unpin(link.cid); // Recursively unpin child nodes
        }
      }
    }
  }

  /// Resolves an IPNS name to its corresponding CID.
  Future<String> resolveIPNS(String ipnsName) async {
    // 1. Validate the IPNS name (ensure it's a valid peer ID)
    if (!isValidPeerID(ipnsName)) {
      // You'll need to implement isValidPeerID
      throw ArgumentError('Invalid IPNS name: $ipnsName');
    }

    // 2. Resolve the IPNS name using the DHT
    String? resolvedCid;
    try {
      resolvedCid = await _dht
          .getValue(ipnsName); // Assuming DHTClient has a getValue method
    } catch (e) {
      // Handle potential errors during DHT resolution
      print('Error resolving IPNS name through DHT: $e');
      // You might want to rethrow the error or return null
    }

    // 3. If the DHT resolution fails, try alternative resolution methods
    // (e.g., using a public IPNS resolver)
    if (resolvedCid == null) {
      // Try resolving using a public IPNS resolver (e.g., ipfs.io)
      try {
        final url = Uri.parse('https://ipfs.io/ipns/$ipnsName');
        final response =
            await http.get(url); // You'll need to import the http package
        if (response.statusCode == 200) {
          // Extract the CID from the response body (the response will be a redirect)
          resolvedCid = extractCIDFromResponse(
              response.body); // You'll need to implement this function
        } else {
          print(
              'Error resolving IPNS name using public resolver: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        print('Error resolving IPNS name using public resolver: $e');
      }

      // If all resolution methods fail, throw an error
      if (resolvedCid == null) {
        throw Exception('Failed to resolve IPNS name: $ipnsName');
      }
    }

    // 4. Return the resolved CID
    return resolvedCid;
  }

  /// Publishes an IPNS record.
  Future<void> publishIPNS(String cid, {required String keyName}) async {
    // 1. Get the IPNS key pair from the keystore
    final keyPair = _keystore
        .getKeyPair(keyName); // You'll need to implement Keystore.getKeyPair()

    // 2. Validate the CID
    if (!isValidCID(cid)) {
      // You'll need to implement isValidCID()
      throw ArgumentError('Invalid CID: $cid');
    }

    // 3. Publish the IPNS record using the key pair
    try {
      await _dht.putValue(
          keyPair.publicKey, cid); // Assuming DHTClient has a putValue method
    } catch (e) {
      // Handle potential errors during publishing
      print('Error publishing IPNS record: $e');
      // You might want to rethrow the error
    }
  }

  /// Imports a CAR file.
  Future<void> importCAR(Uint8List carFile) async {
    // 1. Parse the CAR file
    final car = await CarReader.readCar(
        carFile); // You'll need to implement CarReader.readCar()

    // 2. Store the blocks from the CAR file in the datastore
    for (var block in car.blocks) {
      await _datastore.put(block.cid, block);
    }

    // 3. (Optional) Announce the availability of the blocks to the network (Bitswap)
    for (var block in car.blocks) {
      _bitswap.provide(block.cid);
    }
  }

  /// Exports a CAR file for the given CID.
  Future<Uint8List> exportCAR(String cid) async {
    // 1. Create a list to store the blocks
    final blocks = <Block>[];

    // 2. Retrieve the root block with the given CID
    final rootBlock = await _datastore.get(cid);
    if (rootBlock == null) {
      throw ArgumentError('Block with CID $cid not found');
    }
    blocks.add(rootBlock);

    // 3. (Optional) Recursively retrieve the blocks of linked nodes
    // This is necessary to include all the child nodes in the CAR file
    await _recursiveGetBlocks(rootBlock, blocks);

    // 4. Create a CAR file with the collected blocks
    final carData = await CarWriter.writeCar(
        blocks); // You'll need to implement CarWriter.writeCar()

    // 5. Return the CAR file data
    return carData;
  }

  // Helper function to recursively retrieve blocks of linked nodes
  Future<void> _recursiveGetBlocks(Block block, List<Block> blocks) async {
    final node = Node.fromBytes(block.data);
    if (node.nodeType == NodeType.directory) {
      for (var link in node.links) {
        final childBlock = await _datastore.get(link.cid);
        if (childBlock != null) {
          blocks.add(childBlock);
          await _recursiveGetBlocks(childBlock, blocks); // Recursive call
        }
      }
    }
  }

  /// Finds providers for a CID.
  Future<List<p2p.Peer>> findProviders(
    String cid, {
    String?
        providerServiceURL, // Add optional parameter for provider service URL
  }) async {
    // 1. Use the DHT to find providers
    final providers = await _dht.findProviders(cid);

    // 2. If the DHT doesn't find enough providers, use other methods
    if (providers.length < minProviders) {
      // a. Ask connected peers
      final connectedPeers = _router.connectedPeers;
      for (var peer in connectedPeers) {
        try {
          // Define and send a "FIND_PROVIDERS" message to the peer
          final request = encodeFindProvidersRequest(cid);
          await _router.sendMessage(peer, request);

          // Receive and parse the response containing provider Peer IDs
          final response = await _router.receiveMessage(peer);
          final providerPeerIDs = decodeFindProvidersResponse(response);

          // Convert the provider Peer IDs to p2p.Peer objects and add them to the providers list
          for (var peerID in providerPeerIDs) {
            final providerPeer = p2p.Peer.fromId(peerID);
            providers.add(providerPeer);
          }
        } catch (e) {
          print('Error finding providers from peer $peer: $e');
        }
      }

      // b. (Optional) Use a provider record service (if provided)
      if (providerServiceURL != null) {
        try {
          final url = Uri.parse('$providerServiceURL/providers/$cid');
          final response = await http.get(url);
          if (response.statusCode == 200) {
            final providerPeerIDs =
                decodeProviderServiceResponse(response.body);
            for (var peerID in providerPeerIDs) {
              final providerPeer = p2p.Peer.fromId(peerID);
              providers.add(providerPeer);
            }
          } else {
            print(
                'Error querying provider service: ${response.statusCode} - ${response.body}');
          }
        } catch (e) {
          print('Error querying provider service: $e');
        }
      }
    }

    // 3. Deduplicate the list of providers
    final uniqueProviders = providers.toSet().toList();

    // 4. Return the list of providers
    return uniqueProviders;
  }

  /// Requests a block from the network using Bitswap.
  Future<void> requestBlock(String cid, p2p.Peer peer) async {
    return _bitswap.requestBlock(cid, peer);
  }

  /// Subscribes to a PubSub topic.
  Future<void> subscribe(String topic) async {
    // 1. Validate the topic name (if necessary)
    // You might want to validate the topic name against a specific format or pattern

    // 2. Subscribe to the topic using the PubSub client
    try {
      await _pubsub.subscribe(topic);
    } catch (e) {
      // Handle potential errors during subscription
      print('Error subscribing to topic $topic: $e');
      // Re-throw the exception to propagate it to the caller
      rethrow;
    }

    // 3. Handle incoming messages on the topic
    _pubsub.onMessage(topic, (message) {
      // Process the incoming message
      try {
        // Decode the message (if necessary)
        final decodedMessage = decodeMessage(message);

        // Handle the message based on its content
        handlePubsubMessage(
          _bitswap, // Pass Bitswap instance
          _dht, // Pass DHTClient instance
          _newContentController,
          _contentUpdatedController,
          _peerJoinedController,
          _peerLeftController,
          _nodeEventsController,
          _peerEventsController,
          _networkEventsController,
          _bandwidthEventsController,
          _pinningEventsController,
          _blockEventsController,
          _datastoreEventsController,
          _applicationMessageController,
          topic,
          decodedMessage,
        );
      } catch (e) {
        print('Error handling PubSub message: $e');
      }
    });
  }

  /// Publishes a message to a PubSub topic.
  Future<void> publish(String topic, String message) async {
    // TODO: Implement PubSub publishing logic
    throw UnimplementedError();
  }

  /// Resolves a DNSLink to its corresponding CID.
  Future<String> resolveDNSLink(String domainName) async {
    // TODO: Implement DNSLink resolution logic
    throw UnimplementedError();
  }

  /// Gets the node's statistics.
  Future<NodeStats> stats() async {
    // TODO: Implement node statistics logic
    throw UnimplementedError();
  }
}
