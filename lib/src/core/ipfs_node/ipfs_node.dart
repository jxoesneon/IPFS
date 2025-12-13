// src/core/ipfs_node/ipfs_node.dart
import 'dart:async';
import 'dart:typed_data';
import 'pubsub_handler.dart';
import 'network_handler.dart';
import 'datastore_handler.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:dart_ipfs/src/utils/base58.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:dart_ipfs/src/network/router.dart';
import 'package:dart_ipfs/src/storage/datastore.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/pin.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_handler.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_client.dart';
import 'package:dart_ipfs/src/core/data_structures/link.dart';
import 'package:dart_ipfs/src/core/data_structures/peer.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/protocols/ipns/ipns_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/mdns_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipld_handler.dart';
import 'package:dart_ipfs/src/proto/generated/core/pin.pb.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/security/security_manager.dart';
import 'package:dart_ipfs/src/core/data_structures/directory.dart';
import 'package:dart_ipfs/src/core/ipfs_node/auto_nat_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/dns_link_handler.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/ipfs_node/bootstrap_handler.dart';
import 'package:dart_ipfs/src/protocols/bitswap/bitswap_handler.dart';
import 'package:dart_ipfs/src/core/data_structures/merkle_dag_node.dart';
import 'package:dart_ipfs/src/core/ipfs_node/content_routing_handler.dart';
import 'package:dart_ipfs/src/core/di/service_container.dart';
import 'package:dart_ipfs/src/core/builders/ipfs_node_builder.dart';
import 'package:dart_ipfs/src/protocols/graphsync/graphsync_handler.dart';

/// The central node orchestrating all IPFS operations.
///
/// [IPFSNode] is the main class for interacting with the IPFS network.
/// It manages storage, networking, and protocol handlers, providing
/// a high-level API for content operations.
///
/// **Creating a Node:**
/// ```dart
/// // Offline mode (local storage only)
/// final node = await IPFSNode.create(IPFSConfig(offline: true));
/// await node.start();
///
/// // P2P mode (full network participation)
/// final node = await IPFSNode.create(IPFSConfig(offline: false));
/// await node.start();
/// print('Peer ID: ${node.peerID}');
/// ```
///
/// **Adding Content:**
/// ```dart
/// final cid = await node.addFile(fileBytes);
/// print('Added content: $cid');
/// ```
///
/// **Retrieving Content:**
/// ```dart
/// final data = await node.get(cid);
/// ```
///
/// **Lifecycle:**
/// Always call [start] before using the node and [stop] when done:
/// ```dart
/// await node.start();
/// try {
///   // Use the node...
/// } finally {
///   await node.stop();
/// }
/// ```
///
/// See also:
/// - [IPFS] for a simpler high-level wrapper
/// - [IPFSConfig] for configuration options
/// - [IPFSNodeBuilder] for advanced node construction
class IPFSNode {
  final ServiceContainer _container;
  final Logger _logger;
  final StreamController<String> _newContentController =
      StreamController<String>.broadcast();

  IPFSNode.fromContainer(this._container) : _logger = Logger('IPFSNode') {
    _logger.debug('Creating IPFS Node from container');

    // Validate required services
    _validateRequiredServices();
  }

  static Future<IPFSNode> create(IPFSConfig config) async {
    final builder = IPFSNodeBuilder(config);
    return await builder.build();
  }

  // Public API Getters for external access
  
  /// Get the peer ID of this node
  String get peerId {
    try {
      if (!_container.isRegistered(NetworkHandler)) return 'offline';
      final networkHandler = _container.get<NetworkHandler>();
      return networkHandler.ipfsNode.peerID;
    } catch (e) {
      _logger.warning('Failed to get peerId: $e');
      return 'unknown';
    }
  }
  
  /// Get the addresses this node is listening on
  List<String> get addresses {
    try {
      // Return multiaddrs as strings
      return ['/ip4/127.0.0.1/tcp/4001/p2p/$peerId'];
    } catch (e) {
      _logger.warning('Failed to get addresses: $e');
      return [];
    }
  }
  
  /// Get the block store
  BlockStore get blockStore {
    return _container.get<BlockStore>();
  }
  
  /// Get the DHT client
  DHTClient get dhtClient {
    if (!_container.isRegistered(DHTHandler)) {
      throw StateError('DHT client not available (offline mode)');
    }
    try {
      final dhtHandler = _container.get<DHTHandler>();
      return dhtHandler.dhtClient;
    } catch (e) {
      throw StateError('DHT client not available: $e');
    }
  }
  
  /// Get list of connected peers
  List<String> get connectedPeers {
    try {
      // Return empty list for now, would need to track in NetworkHandler
      return [];
    } catch (e) {
      _logger.warning('Failed to get connected peers: $e');
      return [];
    }
  }

  // Convenience API Methods
  
  /// Get content by CID (alias for get method)
  Future<Uint8List?> cat(String cid) async {
    return await get(cid);
  }
  
  /// Connect to a peer by multiaddr
  Future<void> connectToPeer(String multiaddr) async {
    try {
      // This would need proper multiaddr parsing and connection logic
      _logger.info('Connecting to peer: $multiaddr');
      // For now, just log - actual implementation needs network handler
    } catch (e) {
      _logger.error('Failed to connect to peer: $e');
      throw Exception('Failed to connect to peer: $e');
    }
  }
  
  /// Disconnect from a peer
  Future<void> disconnectFromPeer(String peerId) async {
    try {
      _logger.info('Disconnecting from peer: $peerId');
      // Implementation would go through network handler
    } catch (e) {
      _logger.error('Failed to disconnect from peer: $e');
    }
  }
  
  /// Resolve IPNS name to CID
  Future<String> resolveIPNS(String name) async {
    try {
      final dhtHandler = _container.get<DHTHandler>();
      final cid = await dhtHandler.resolveIPNS(name);
      return cid;
    } catch (e) {
      _logger.error('Failed to resolve IPNS: $e');
      rethrow;
    }
  }

  Future<void> start() async {
    _logger.debug('Starting IPFS Node...');

    try {
      // Start systems in dependency order
      await _startCoreSystem();
      await _startStorageLayer();
      await _startNetworkLayer();
      await _startServices();

      _logger.info('IPFS Node started successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to start IPFS Node', e, stackTrace);
      rethrow;
    }
  }

  Future<void> _startCoreSystem() async {
    _logger.debug('Starting core systems...');

    try {
      _logger.verbose('Starting core system initialization');
      await _container.get<MetricsCollector>().start();
      _logger.debug('Metrics Collector initialized successfully');

      _logger.verbose('Creating Security Manager');
      await _container.get<SecurityManager>().start();
      _logger.debug('Security Manager initialized successfully');

      _logger.debug('Core systems initialization complete');
    } catch (e, stackTrace) {
      _logger.error('Failed to initialize core systems', e, stackTrace);
      rethrow;
    }
  }

  Future<void> _startStorageLayer() async {
    _logger.debug('Starting storage layer...');

    try {
      _logger.verbose('Starting storage layer initialization');
      await _container.get<BlockStore>().start();
      _logger.debug('BlockStore initialized successfully');

      _logger.verbose('Creating DatastoreHandler');
      await _container.get<DatastoreHandler>().start();
      _logger.debug('DatastoreHandler initialized successfully');

      _logger.verbose('Creating IPLDHandler');
      await _container.get<IPLDHandler>().start();
      _logger.debug('IPLDHandler initialized successfully');

      _logger.debug('Storage layer initialization complete');
    } catch (e, stackTrace) {
      _logger.error('Failed to initialize storage layer', e, stackTrace);
      rethrow;
    }
  }

  Future<void> _startNetworkLayer() async {
    _logger.debug('Starting network layer...');

    try {
      _logger.verbose('Starting network layer initialization');
      
      if (_container.isRegistered(NetworkHandler)) {
        // CRITICAL: Set ipfsNode reference before starting any network services
        _container.get<NetworkHandler>().setIpfsNode(this);
        await _container.get<NetworkHandler>().start();
        _logger.debug('NetworkHandler created successfully');
      }

      _logger.verbose('Initializing peer discovery handlers');
      if (_container.isRegistered(MDNSHandler)) {
        await _container.get<MDNSHandler>().start();
        _logger.debug('MDNSHandler initialized');
      }

      _logger.verbose('Initializing core network protocols');
      if (_container.isRegistered(DHTHandler)) {
        await _container.get<DHTHandler>().start();
        _logger.debug('DHTHandler initialized');
      }

      _logger.verbose('Creating PubSubHandler');
      if (_container.isRegistered(PubSubHandler)) {
        await _container.get<PubSubHandler>().start();
        _logger.debug('PubSubHandler initialized');
      }

      _logger.verbose('Creating BitswapHandler');
      if (_container.isRegistered(BitswapHandler)) {
        await _container.get<BitswapHandler>().start();
        _logger.debug('BitswapHandler initialized');
      }

      _logger.debug('Network layer initialization complete');
    } catch (e, stackTrace) {
      _logger.error('Failed to initialize network layer', e, stackTrace);
      rethrow;
    }
  }

  Future<void> _startServices() async {
    _logger.debug('Starting high-level services...');

    try {
      _logger.verbose('Starting services initialization');
      
      if (_container.isRegistered(ContentRoutingHandler)) {
        await _container.get<ContentRoutingHandler>().start();
        _logger.debug('ContentRoutingHandler initialized');
      }

      if (_container.isRegistered(DNSLinkHandler)) {
        await _container.get<DNSLinkHandler>().start();
        _logger.debug('DNSLinkHandler initialized');
      }

      if (_container.isRegistered(GraphsyncHandler)) {
        await _container.get<GraphsyncHandler>().start();
        _logger.debug('GraphsyncHandler initialized');
      }

      if (_container.isRegistered(AutoNATHandler)) {
        await _container.get<AutoNATHandler>().start();
        _logger.debug('AutoNATHandler initialized');
      }

      if (_container.isRegistered(IPNSHandler)) {
        await _container.get<IPNSHandler>().start();
        _logger.debug('IPNSHandler initialized');
      }

      _logger.debug('High-level services initialization complete');
    } catch (e, stackTrace) {
      _logger.error('Failed to initialize high-level services', e, stackTrace);
      rethrow;
    }
  }

  Future<void> stop() async {
    _logger.debug('Stopping IPFS Node...');

    try {
      // Stop in reverse order of initialization

      // Stop high-level services
      if (_container.isRegistered(IPNSHandler)) await _container.get<IPNSHandler>().stop();
      if (_container.isRegistered(AutoNATHandler)) await _container.get<AutoNATHandler>().stop();
      if (_container.isRegistered(GraphsyncHandler)) await _container.get<GraphsyncHandler>().stop();
      if (_container.isRegistered(DNSLinkHandler)) await _container.get<DNSLinkHandler>().stop();
      if (_container.isRegistered(ContentRoutingHandler)) await _container.get<ContentRoutingHandler>().stop();

      // Stop network layer
      if (_container.isRegistered(BitswapHandler)) await _container.get<BitswapHandler>().stop();
      if (_container.isRegistered(PubSubHandler)) await _container.get<PubSubHandler>().stop();
      if (_container.isRegistered(DHTHandler)) await _container.get<DHTHandler>().stop();
      if (_container.isRegistered(BootstrapHandler)) await _container.get<BootstrapHandler>().stop();
      if (_container.isRegistered(MDNSHandler)) await _container.get<MDNSHandler>().stop();
      if (_container.isRegistered(NetworkHandler)) await _container.get<NetworkHandler>().stop();

      // Stop storage layer
      await _container.get<IPLDHandler>().stop();
      await _container.get<DatastoreHandler>().stop();

      // Stop core systems
      await _container.get<MetricsCollector>().stop();
      await _container.get<SecurityManager>().stop();

      _logger.info('IPFS Node stopped successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to stop IPFS Node', e, stackTrace);
      rethrow;
    }
  }

  Future<String> addFile(Uint8List data) async {
    try {
      // Create a new block from the file data
      final block = await Block.fromData(data);

      // Store the block in the datastore
      await _container.get<DatastoreHandler>().putBlock(block);

      // Notify listeners about the new content
      _newContentController.add(block.cid.toString());

      return block.cid.toString();
    } catch (e) {
      print('Error adding file: $e');
      rethrow;
    }
  }

  Future<String> addDirectory(Map<String, dynamic> directoryContent) async {
    // Create a new directory node
    // Note: Standard UnixFS directories don't store their own name/path internally
    final directoryManager = IPFSDirectoryManager();

    // Process each entry in the directory content
    for (final entry in directoryContent.entries) {
      if (entry.value is Uint8List) {
        // Handle file
        final cid = await addFile(entry.value as Uint8List);
        directoryManager.addEntry(IPFSDirectoryEntry(
          name: entry.key,
          hash: CID.decode(cid).multihash.toBytes(), // Decode CID to multihash bytes for the link
          size: fixnum.Int64(entry.value.length),
          isDirectory: false,
        ));
      } else if (entry.value is Map) {
        // Handle subdirectory recursively
        final subDirCid =
            await addDirectory(entry.value as Map<String, dynamic>);
        directoryManager.addEntry(IPFSDirectoryEntry(
          name: entry.key,
          hash: CID.decode(subDirCid).multihash.toBytes(),
          size: fixnum.Int64(0), // Tsize should ideally be known, but 0 is acceptable if unknown for now
          isDirectory: true,
        ));
      }
    }

    // Create a block from the directory data
    final pbNode = directoryManager.build();
    final block =
        await Block.fromData(pbNode.writeToBuffer(), format: 'dag-pb');

    // Store the directory block
    await _container.get<DatastoreHandler>().putBlock(block);

    // Return the CID of the directory
    return block.cid.toString();
  }

  /// Gets the content of a file or directory from IPFS.
  ///
  /// [cid] is the Content Identifier of the file/directory
  /// [path] is an optional path within the directory
  Future<Uint8List?> get(String cid, {String path = ''}) async {
    try {
      // First check if we have the block locally
      final block = await _container.get<DatastoreHandler>().getBlock(cid);

      if (block != null) {
        if (path.isEmpty) {
          // Return the raw data if no path is specified
          return block.data;
        } else {
          // If this is a directory and a path is specified,
          // traverse the directory structure
          final node = MerkleDAGNode.fromBytes(block.data);
          if (node.isDirectory) {
            return await _resolvePathInDirectory(node, path);
          }
        }
      }

      // If not found locally, try to fetch from the network
      final networkBlock =
          await _container.get<BitswapHandler>().wantBlock(cid);
      // Return the block data if found, null otherwise
      return networkBlock?.data;
    } catch (e) {
      print('Error retrieving content for CID $cid: $e');
      return null;
    }
  }

  Future<Uint8List?> _resolvePathInDirectory(
      MerkleDAGNode dirNode, String path) async {
    final pathParts = path.split('/').where((part) => part.isNotEmpty).toList();

    for (final link in dirNode.links) {
      if (link.name == pathParts[0]) {
        final childBlock = await _container
            .get<DatastoreHandler>()
            .getBlock(link.cid.toString());
        if (childBlock == null) return null;

        if (pathParts.length == 1) {
          return childBlock.data;
        } else {
          final childNode = MerkleDAGNode.fromBytes(childBlock.data);
          return await _resolvePathInDirectory(
              childNode, pathParts.sublist(1).join('/'));
        }
      }
    }
    return null;
  }

  Future<List<Link>> ls(String cid) async {
    try {
      // Get the block
      Block? block = await _container.get<DatastoreHandler>().getBlock(cid);
      if (block == null) {
        // Try fetching from network if not found locally
        final data = await _container.get<BitswapHandler>().wantBlock(cid);
        if (data == null) {
          throw Exception('Directory not found: $cid');
        }
        block = data; // data IS a Block
      }

      // Parse the directory node using MerkleDAGNode
      // Note: MerkleDAGNode must parse strict UnixFS to know if it's a directory
      final node = MerkleDAGNode.fromBytes(block.data);

      if (!node.isDirectory) {
        throw Exception('CID does not point to a directory: $cid');
      }

      // Convert directory links to Link objects
      return node.links;
    } catch (e) {
      print('Error listing directory $cid: $e');
      return [];
    }
  }

  /// Pins a CID to prevent it from being garbage collected.
  Future<void> pin(String cid) async {
    try {
      // Create a Pin instance
      final pin = Pin(
        cid: CID.decode(cid),
        type: PinTypeProto.PIN_TYPE_RECURSIVE,
        blockStore: _container.get<BlockStore>(),
      );

      // Pin the content
      final success = await pin.pin();
      if (!success) {
        throw Exception('Failed to pin CID: $cid');
      }

      // Update the datastore to mark the CID as pinned
      await _container.get<DatastoreHandler>().persistPinnedCIDs({cid});

      print('Successfully pinned CID: $cid');
    } catch (e) {
      print('Error pinning CID $cid: $e');
      rethrow;
    }
  }

  /// Unpins a CID from IPFS.
  ///
  /// This allows the content to be garbage collected if no other pins exist.
  /// Returns true if the unpin was successful, false otherwise.
  Future<bool> unpin(String cid) async {
    try {
      // Create a Pin instance
      final pin = Pin(
        cid: CID.decode(cid),
        type: PinTypeProto.PIN_TYPE_RECURSIVE,
        blockStore: _container.get<BlockStore>(),
      );

      // Attempt to unpin
      final success = await pin.unpin();

      if (success) {
        // Update the datastore
        await _container.get<DatastoreHandler>().datastore.unpin(cid);
        print('Successfully unpinned CID: $cid');
      } else {
        print('Failed to unpin CID: $cid - CID may not be pinned');
      }

      return success;
    } catch (e) {
      print('Error while unpinning CID $cid: $e');
      return false;
    }
  }

  // Add this method to the IPFSNode class
  Future<void> publishIPNS(String cid, {required String keyName}) async {
    try {
      // Validate CID
      if (!_container.get<DHTHandler>().isValidCID(cid)) {
        throw ArgumentError('Invalid CID: $cid');
      }

      // Delegate to DHT handler for IPNS record publishing
      await _container.get<DHTHandler>().publishIPNS(cid, keyName: keyName);

      print(
          'Successfully published IPNS record for CID: $cid with key: $keyName');
    } catch (e) {
      print('Error publishing IPNS record: $e');
      rethrow;
    }
  }

  Future<void> importCAR(Uint8List carFile) async {
    try {
      await _container.get<DatastoreHandler>().importCAR(carFile);
    } catch (e) {
      print('Error importing CAR file: $e');
      rethrow;
    }
  }

  /// Exports a CAR file for the given CID.
  Future<Uint8List> exportCAR(String cid) async {
    try {
      // Delegate to the datastoreHandler which has the CAR export implementation
      return await _container.get<DatastoreHandler>().exportCAR(cid);
    } catch (e) {
      print('Error exporting CAR file: $e');
      rethrow;
    }
  }

  /// Finds providers for a given CID.
  ///
  /// Returns a list of peer IDs that can provide the content identified by [cid].
  Future<List<String>> findProviders(String cid) async {
    try {
      // First check if we have the content locally
      final hasLocal = await _container.get<DatastoreHandler>().hasBlock(cid);
      if (hasLocal) {
        // If we have it locally, return our own peer ID
        return [_container.get<NetworkHandler>().ipfsNode.peerID];
      }

      // Convert string CID to CID object
      final cidObj = CID.decode(cid);

      // Try finding providers through DHT
      final dhtProviders =
          await _container.get<DHTHandler>().findProviders(cidObj);
      if (dhtProviders.isNotEmpty) {
        // Convert V_PeerInfo to String peer IDs
        return dhtProviders
            .map((p) => Base58().encode(Uint8List.fromList(p.peerId)))
            .toList();
      }

      // If DHT lookup fails, try finding through routing handler
      final routingProviders =
          await _container.get<ContentRoutingHandler>().findProviders(cid);
      if (routingProviders.isNotEmpty) {
        return routingProviders;
      }

      // No providers found
      return [];
    } catch (e) {
      print('Error finding providers for CID $cid: $e');
      return [];
    }
  }

  Future<void> requestBlock(String cid, Peer peer) async {
    try {
      // Validate CID format
      if (!_container.get<DHTHandler>().isValidCID(cid)) {
        throw ArgumentError('Invalid CID format: $cid');
      }

      // Use bitswap to request the block
      final block = await _container.get<BitswapHandler>().wantBlock(cid);

      if (block == null) {
        throw Exception('Failed to retrieve block from peer');
      }

      // Store the block in our datastore
      await _container.get<DatastoreHandler>().putBlock(block);
    } catch (e) {
      print('Error requesting block $cid from peer ${peer.toString()}: $e');
      rethrow;
    }
  }

  /// Subscribes to a PubSub topic.
  Future<void> subscribe(String topic) async {
    try {
      await _container.get<PubSubHandler>().subscribe(topic);
      print('Successfully subscribed to topic: $topic');
    } catch (e) {
      print('Error subscribing to topic $topic: $e');
      rethrow;
    }
  }

  /// Publishes a message to a PubSub topic.
  Future<void> publish(String topic, String message) async {
    try {
      await _container.get<PubSubHandler>().publish(topic, message);
      print('Successfully published message to topic: $topic');
    } catch (e) {
      print('Error publishing message to topic $topic: $e');
      rethrow;
    }
  }

  /// Resolves a DNSLink to its corresponding CID.
  Future<String> resolveDNSLink(String domainName) async {
    try {
      // First try resolving through the routing handler
      final cid = await _container
          .get<ContentRoutingHandler>()
          .resolveDNSLink(domainName);
      if (cid != null) {
        return cid;
      }

      // If routing handler fails, try DHT handler
      final dhtCid =
          await _container.get<DHTHandler>().resolveDNSLink(domainName);
      if (dhtCid != null) {
        return dhtCid;
      }

      throw Exception('Failed to resolve DNSLink for domain: $domainName');
    } catch (e) {
      print('Error resolving DNSLink for domain $domainName: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getHealthStatus() async {
    return {
      'core': {
        'security': await _container.get<SecurityManager>().getStatus(),
        'metrics': await _container.get<MetricsCollector>().getStatus(),
      },
      'storage': {
        'blockstore': await _container.get<BlockStore>().getStatus(),
        'datastore': await _container.get<DatastoreHandler>().getStatus(),
        'ipld': await _container.get<IPLDHandler>().getStatus(),
      },
      'network': {
        'dht': await _container.get<DHTHandler>().getStatus(),
        'pubsub': await _container.get<PubSubHandler>().getStatus(),
        'bitswap': await _container.get<BitswapHandler>().getStatus(),
        'mdns': await _container.get<MDNSHandler>().getStatus(),
        'bootstrap': await _container.get<BootstrapHandler>().getStatus(),
      },
      'services': {
        'routing': await _container.get<ContentRoutingHandler>().getStatus(),
        'dnslink': await _container.get<DNSLinkHandler>().getStatus(),
        'graphsync': await _container.get<GraphsyncHandler>().getStatus(),
        'autonat': await _container.get<AutoNATHandler>().getStatus(),
        'ipns': await _container.get<IPNSHandler>().getStatus(),
      }
    };
  }

  // Core getters
  Datastore get datastore => _container.get<DatastoreHandler>().datastore;
  Router get router => _container.get<NetworkHandler>().router;
  BitswapHandler get bitswap => _container.get<BitswapHandler>();
  DHTHandler get dhtHandler => _container.get<DHTHandler>();
  String get peerID => _container.get<NetworkHandler>().peerID;

  // Event streams
  Stream<String> get onNewContent => _newContentController.stream;

  /// Validates that all required services are registered in the container
  void _validateRequiredServices() {
    final requiredServices = [
      // Core systems
      MetricsCollector,
      SecurityManager,

      // Storage layer
      BlockStore,
      DatastoreHandler,
      IPLDHandler,

      // Network layer (Optional for offline mode)
      /*
      NetworkHandler,
      MDNSHandler,
      DHTHandler,
      PubSubHandler,
      BitswapHandler,
      BootstrapHandler,

      // Services
      ContentRoutingHandler,
      DNSLinkHandler,
      GraphsyncHandler,
      AutoNATHandler,
      IPNSHandler,
      */
    ];

    for (final service in requiredServices) {
      if (!_container.isRegistered(service)) {
        _logger.error('Required service not found: ${service.toString()}');
        throw StateError('Missing required service: ${service.toString()}');
      }
    }

    _logger.debug('All required services validated successfully');
  }

  // Add this getter to the IPFSNode class
  ServiceContainer get container => _container;
}
