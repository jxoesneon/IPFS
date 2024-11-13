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
import 'package:dart_ipfs/src/core/data_structures/node.dart';
import 'package:dart_ipfs/src/core/data_structures/link.dart';
import 'package:dart_ipfs/src/core/data_structures/peer.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/protocols/ipns/ipns_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/mdns_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipld_handler.dart';
import 'package:dart_ipfs/src/proto/generated/core/cid.pb.dart';
import 'package:dart_ipfs/src/proto/generated/core/pin.pb.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/security/security_manager.dart';
import 'package:dart_ipfs/src/core/data_structures/directory.dart';
import 'package:dart_ipfs/src/core/ipfs_node/auto_nat_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/dns_link_handler.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/ipfs_node/graphsync_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/bootstrap_handler.dart';
import 'package:dart_ipfs/src/protocols/bitswap/bitswap_handler.dart';
import 'package:dart_ipfs/src/core/data_structures/merkle_dag_node.dart';
import 'package:dart_ipfs/src/proto/generated/core/node_type.pbenum.dart';
import 'package:dart_ipfs/src/core/ipfs_node/content_routing_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node_network_events.dart';
// src/core/ipfs_node/ipfs_node.dart

// lib/src/core/ipfs_node/ipfs_node.dart

/// The main class representing an IPFS node.
class IPFSNode {
  // Core Systems
  late final SecurityManager securityManager;
  late final Logger _logger;
  late final MetricsCollector metricsCollector;

  // Storage Layer
  late final BlockStore _blockStore;
  late final DatastoreHandler datastoreHandler;
  late final IPLDHandler ipldHandler;

  // Network Layer
  late final NetworkHandler networkHandler;
  late final DHTHandler dhtHandler;
  late final PubSubHandler pubSubHandler;
  late final BitswapHandler bitswapHandler;
  late final MDNSHandler mdnsHandler;
  late final BootstrapHandler bootstrapHandler;

  // High-level Services
  late final ContentRoutingHandler routingHandler;
  late final DNSLinkHandler dnsLinkHandler;
  late final GraphsyncHandler graphsyncHandler;
  late final AutoNATHandler autoNatHandler;
  late final IPNSHandler ipnsHandler;

  final IPFSConfig _config;
  final String _peerID;

  final _newContentController = StreamController<String>.broadcast();

  // Add getters for the handlers
  Datastore get datastore => datastoreHandler.datastore;
  Router get router => networkHandler.router;
  BitswapHandler get bitswap => bitswapHandler;
  IPFSConfig get config => _config;

  // Add the onNewContent stream getter
  Stream<String> get onNewContent => _newContentController.stream;

  // Add this getter
  String get peerID => _peerID;

  late NodeTypeProto nodeType;

  late CID cid;

  late List<Link> links;

  IPFSNode(IPFSConfig config)
      : _config = config,
        _peerID = config.nodeId {
    _logger =
        Logger('IPFSNode', debug: config.debug, verbose: config.verboseLogging);
    _logger.debug('Creating new IPFS Node instance');

    try {
      _logger.verbose('Starting core system initialization');
      _initializeCoreSystem();

      _logger.verbose('Starting storage layer initialization');
      _initializeStorageLayer();

      _logger.verbose('Starting network layer initialization');
      _initializeNetworkLayer();

      _logger.verbose('Starting services initialization');
      _initializeServices();

      _logger.debug('IPFS Node instance created successfully');
    } catch (e, stackTrace) {
      _logger.error('Error during IPFS Node initialization', e, stackTrace);
      rethrow;
    }
  }

  void _initializeCoreSystem() async {
    _logger.debug('Initializing core systems...');

    try {
      _logger.verbose('Creating Security Manager');
      securityManager = SecurityManager(_config.security, metricsCollector);
      _logger.debug('Security Manager initialized successfully');

      _logger.verbose('Configuring Metrics Collector');
      metricsCollector = MetricsCollector(_config);
      _logger.debug('Metrics Collector initialized successfully');

      _logger.debug('Core systems initialization complete');
    } catch (e, stackTrace) {
      _logger.error('Failed to initialize core systems', e, stackTrace);
      rethrow;
    }
  }

  void _initializeStorageLayer() async {
    _logger.debug('Initializing storage layer...');

    try {
      _logger.verbose('Creating BlockStore at path: ${_config.blockStorePath}');
      _blockStore = BlockStore(path: _config.blockStorePath);
      _logger.debug('BlockStore initialized successfully');

      _logger.verbose('Creating DatastoreHandler');
      datastoreHandler = DatastoreHandler(_config);
      _logger.debug('DatastoreHandler initialized successfully');

      _logger.verbose('Creating IPLDHandler');
      ipldHandler = IPLDHandler(_blockStore, _config);
      _logger.debug('IPLDHandler initialized successfully');

      _logger.debug('Storage layer initialization complete');
    } catch (e, stackTrace) {
      _logger.error('Failed to initialize storage layer', e, stackTrace);
      rethrow;
    }
  }

  void _initializeNetworkLayer() async {
    _logger.debug('Initializing network layer...');

    try {
      _logger.verbose('Creating NetworkHandler');
      networkHandler = NetworkHandler(_config);
      _logger.debug('NetworkHandler created successfully');

      _logger.verbose('Initializing peer discovery handlers');
      mdnsHandler = MDNSHandler(_config);
      _logger.debug('MDNSHandler initialized');

      bootstrapHandler = BootstrapHandler(_config);
      _logger.debug('BootstrapHandler initialized');

      _logger.verbose('Initializing core network protocols');
      dhtHandler =
          DHTHandler(_config, networkHandler.p2pRouter, networkHandler);
      _logger.debug('DHTHandler initialized');

      _logger.verbose('Creating PubSubHandler');
      pubSubHandler = PubSubHandler(
          networkHandler.p2pRouter,
          _config.nodeId,
          IpfsNodeNetworkEvents(
              networkHandler.circuitRelayClient, networkHandler.p2pRouter));
      _logger.debug('PubSubHandler initialized');

      _logger.verbose('Creating BitswapHandler');
      bitswapHandler =
          BitswapHandler(_config, _blockStore, networkHandler.p2pRouter);
      _logger.debug('BitswapHandler initialized');

      _logger.debug('Network layer initialization complete');
    } catch (e, stackTrace) {
      _logger.error('Failed to initialize network layer', e, stackTrace);
      rethrow;
    }
  }

  void _initializeServices() async {
    _logger.debug('Initializing high-level services...');

    try {
      _logger.verbose('Creating ContentRoutingHandler');
      routingHandler = ContentRoutingHandler(_config, networkHandler);
      _logger.debug('ContentRoutingHandler initialized');

      _logger.verbose('Creating DNSLinkHandler');
      dnsLinkHandler = DNSLinkHandler(_config);
      _logger.debug('DNSLinkHandler initialized');

      _logger.verbose('Creating GraphsyncHandler');
      graphsyncHandler = GraphsyncHandler(_config, _blockStore);
      _logger.debug('GraphsyncHandler initialized');

      _logger.verbose('Creating AutoNATHandler');
      autoNatHandler = AutoNATHandler(_config, networkHandler);
      _logger.debug('AutoNATHandler initialized');

      _logger.verbose('Creating IPNSHandler');
      ipnsHandler = IPNSHandler(_config, securityManager, dhtHandler);
      _logger.debug('IPNSHandler initialized');

      _logger.debug('High-level services initialization complete');
    } catch (e, stackTrace) {
      _logger.error('Failed to initialize high-level services', e, stackTrace);
      rethrow;
    }
  }

  /// Starts the IPFS node.
  Future<void> start() async {
    _logger.debug('Starting IPFS Node...');

    try {
      // Start core systems
      await securityManager.start();
      await metricsCollector.start();

      // Start storage layer
      await datastoreHandler.start();
      await ipldHandler.start();

      // Start network layer in correct order
      await networkHandler.start();
      await mdnsHandler.start();
      await bootstrapHandler.start();
      await dhtHandler.start();
      await pubSubHandler.start();
      await bitswapHandler.start();

      // Start high-level services
      await routingHandler.start();
      await dnsLinkHandler.start();
      await graphsyncHandler.start();
      await autoNatHandler.start();
      await ipnsHandler.start();

      _logger.info('IPFS Node started successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to start IPFS Node', e, stackTrace);
      rethrow;
    }
  }

  /// Stops the IPFS node.
  Future<void> stop() async {
    _logger.debug('Stopping IPFS Node...');

    try {
      // Stop in reverse order of initialization

      // Stop high-level services
      await ipnsHandler.stop();
      await autoNatHandler.stop();
      await graphsyncHandler.stop();
      await dnsLinkHandler.stop();
      await routingHandler.stop();

      // Stop network layer
      await bitswapHandler.stop();
      await pubSubHandler.stop();
      await dhtHandler.stop();
      await bootstrapHandler.stop();
      await mdnsHandler.stop();
      await networkHandler.stop();

      // Stop storage layer
      await ipldHandler.stop();
      await datastoreHandler.stop();

      // Stop core systems
      await metricsCollector.stop();
      await securityManager.stop();

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
      await datastoreHandler.putBlock(block);

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
    final directoryManager = IPFSDirectoryManager('');

    // Process each entry in the directory content
    for (final entry in directoryContent.entries) {
      if (entry.value is Uint8List) {
        // Handle file
        final cid = await addFile(entry.value as Uint8List);
        directoryManager.addEntry(IPFSDirectoryEntry(
          name: entry.key,
          hash: cid.codeUnits, // Convert String CID to bytes
          size: fixnum.Int64(entry.value.length),
          isDirectory: false,
        ));
      } else if (entry.value is Map) {
        // Handle subdirectory recursively
        final subDirCid =
            await addDirectory(entry.value as Map<String, dynamic>);
        directoryManager.addEntry(IPFSDirectoryEntry(
          name: entry.key,
          hash: subDirCid.codeUnits,
          size: fixnum.Int64(0), // Size will be updated when processing entries
          isDirectory: true,
        ));
      }
    }

    // Create a block from the directory data
    final directoryProto = directoryManager.directory;
    final block =
        await Block.fromData(directoryProto.writeToBuffer(), format: 'dag-pb');

    // Store the directory block
    await datastoreHandler.putBlock(block);

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
      final block = await datastoreHandler.getBlock(cid);

      if (block != null) {
        if (path.isEmpty) {
          // Return the raw data if no path is specified
          return block.data;
        } else {
          // If this is a directory and a path is specified,
          // traverse the directory structure
          if (block.nodeType == IPFSNodeType.directory) {
            final dirNode = MerkleDAGNode.fromBytes(block.data);
            return await _resolvePathInDirectory(dirNode, path);
          }
        }
      }

      // If not found locally, try to fetch from the network
      final networkBlock = await bitswapHandler.wantBlock(cid);
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
        final childBlock = await datastoreHandler.getBlock(link.cid.toString());
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

  /// Lists the contents of a directory in IPFS.
  ///
  /// [cid] is the Content Identifier of the directory to list
  /// Returns a list of [Link] objects representing the directory entries.
  Future<List<Link>> ls(String cid) async {
    try {
      // Get the directory block
      var block = await datastoreHandler.getBlock(cid);
      if (block == null) {
        // Try fetching from network if not found locally
        final data = await bitswapHandler.wantBlock(cid);
        if (data == null) {
          throw Exception('Directory not found: $cid');
        }
        block = MerkleDAGNode.fromBytes(data.data);
      }

      // Parse the directory node
      if (!block.isDirectory) {
        throw Exception('CID does not point to a directory: $cid');
      }

      // Convert directory links to Link objects
      return block.links
          .map((nodeLink) => Link(
                name: nodeLink.name,
                cid: nodeLink.cid,
                hash: nodeLink.hash,
                size: nodeLink.size.toInt(),
                isDirectory: nodeLink.metadata?['type'] == 'directory',
                metadata: nodeLink.metadata,
              ))
          .toList();
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
        cid: CID.fromBytes(Uint8List.fromList(cid.codeUnits), 'raw'),
        type: PinTypeProto.PIN_TYPE_RECURSIVE,
        blockStore: _blockStore,
      );

      // Pin the content
      final success = await pin.pin();
      if (!success) {
        throw Exception('Failed to pin CID: $cid');
      }

      // Update the datastore to mark the CID as pinned
      await datastoreHandler.persistPinnedCIDs({cid});

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
        blockStore: _blockStore,
      );

      // Attempt to unpin
      final success = await pin.unpin();

      if (success) {
        // Update the datastore
        await datastoreHandler.datastore.unpin(cid);
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
      if (!dhtHandler.isValidCID(cid)) {
        throw ArgumentError('Invalid CID: $cid');
      }

      // Delegate to DHT handler for IPNS record publishing
      await dhtHandler.publishIPNS(cid, keyName: keyName);

      print(
          'Successfully published IPNS record for CID: $cid with key: $keyName');
    } catch (e) {
      print('Error publishing IPNS record: $e');
      rethrow;
    }
  }

  Future<void> importCAR(Uint8List carFile) async {
    try {
      await datastoreHandler.importCAR(carFile);
    } catch (e) {
      print('Error importing CAR file: $e');
      rethrow;
    }
  }

  /// Exports a CAR file for the given CID.
  Future<Uint8List> exportCAR(String cid) async {
    try {
      // Delegate to the datastoreHandler which has the CAR export implementation
      return await datastoreHandler.exportCAR(cid);
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
      final hasLocal = await datastoreHandler.hasBlock(cid);
      if (hasLocal) {
        // If we have it locally, return our own peer ID
        return [peerID];
      }

      // Convert string CID to CID object
      final cidObj = CID(
          version: IPFSCIDVersion.IPFS_CID_VERSION_1,
          multihash: Uint8List.fromList(cid.codeUnits),
          codec: 'raw',
          multibasePrefix: 'base58btc');

      // Try finding providers through DHT
      final dhtProviders = await dhtHandler.findProviders(cidObj);
      if (dhtProviders.isNotEmpty) {
        // Convert V_PeerInfo to String peer IDs
        return dhtProviders
            .map((p) => Base58().encode(Uint8List.fromList(p.peerId)))
            .toList();
      }

      // If DHT lookup fails, try finding through routing handler
      final routingProviders = await routingHandler.findProviders(cid);
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
      if (!dhtHandler.isValidCID(cid)) {
        throw ArgumentError('Invalid CID format: $cid');
      }

      // Use bitswap to request the block
      final block = await bitswapHandler.wantBlock(cid);

      if (block == null) {
        throw Exception('Failed to retrieve block from peer');
      }

      // Store the block in our datastore
      await datastoreHandler.putBlock(block);
    } catch (e) {
      print('Error requesting block $cid from peer ${peer.toString()}: $e');
      rethrow;
    }
  }

  /// Subscribes to a PubSub topic.
  Future<void> subscribe(String topic) async {
    try {
      await pubSubHandler.subscribe(topic);
      print('Successfully subscribed to topic: $topic');
    } catch (e) {
      print('Error subscribing to topic $topic: $e');
      rethrow;
    }
  }

  /// Publishes a message to a PubSub topic.
  Future<void> publish(String topic, String message) async {
    try {
      await pubSubHandler.publish(topic, message);
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
      final cid = await routingHandler.resolveDNSLink(domainName);
      if (cid != null) {
        return cid;
      }

      // If routing handler fails, try DHT handler
      final dhtCid = await dhtHandler.resolveDNSLink(domainName);
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
        'security': await securityManager.getStatus(),
        'metrics': await metricsCollector.getStatus(),
      },
      'storage': {
        'blockstore': await _blockStore.getStatus(),
        'datastore': await datastoreHandler.getStatus(),
        'ipld': await ipldHandler.getStatus(),
      },
      'network': {
        'dht': await dhtHandler.getStatus(),
        'pubsub': await pubSubHandler.getStatus(),
        'bitswap': await bitswapHandler.getStatus(),
        'mdns': await mdnsHandler.getStatus(),
        'bootstrap': await bootstrapHandler.getStatus(),
      },
      'services': {
        'routing': await routingHandler.getStatus(),
        'dnslink': await dnsLinkHandler.getStatus(),
        'graphsync': await graphsyncHandler.getStatus(),
        'autonat': await autoNatHandler.getStatus(),
        'ipns': await ipnsHandler.getStatus(),
      }
    };
  }
}
