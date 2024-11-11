import 'dart:async';
import 'dart:typed_data';
import 'pubsub_handler.dart';
import 'routing_handler.dart';
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
import 'package:dart_ipfs/src/proto/generated/core/cid.pb.dart';
import 'package:dart_ipfs/src/proto/generated/core/pin.pb.dart';
import 'package:dart_ipfs/src/core/data_structures/directory.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/protocols/bitswap/bitswap_handler.dart';
import 'package:dart_ipfs/src/core/data_structures/merkle_dag_node.dart';
import 'package:dart_ipfs/src/proto/generated/core/node_type.pbenum.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node_network_events.dart';

// lib/src/core/ipfs_node/ipfs_node.dart

/// The main class representing an IPFS node.
class IPFSNode {
  late final BitswapHandler bitswapHandler;
  late final DHTHandler dhtHandler;
  late final DatastoreHandler datastoreHandler;
  late final RoutingHandler routingHandler;
  late final NetworkHandler networkHandler;
  late final PubSubHandler pubSubHandler;
  final IPFSConfig _config;
  late final BlockStore _blockStore;
  late final Logger _logger;

  final _newContentController = StreamController<String>.broadcast();

  // Add getters for the handlers
  Datastore get datastore => datastoreHandler.datastore;
  Router get router => networkHandler.router;
  BitswapHandler get bitswap => bitswapHandler;
  IPFSConfig get config => _config;

  // Add the onNewContent stream getter
  Stream<String> get onNewContent => _newContentController.stream;

  // Add this field to store the peer ID
  late final String _peerID;

  // Add this getter
  String get peerID => _peerID;

  late NodeTypeProto nodeType;

  late CID cid;

  late List<Link> links;

  IPFSNode(this._config) {
    _logger = Logger('IPFSNode',
        debug: _config.debug, verbose: _config.verboseLogging);

    _logger.debug('Initializing IPFS Node with config: ${_config.toString()}');

    try {
      // Initialize BlockStore first since other components depend on it
      _blockStore = BlockStore(path: _config.blockStorePath);
      _logger
          .verbose('BlockStore initialized at path: ${_config.blockStorePath}');

      networkHandler = NetworkHandler(_config);
      _logger.verbose(
          'Network handler created with config: ${_config.network.toString()}');

      networkHandler.setIpfsNode(this);
      _logger.verbose('IPFS node reference set in network handler');

      _peerID = _config.nodeId;
      _logger.debug('Peer ID initialized: $_peerID');

      _initializeHandlers();
    } catch (e, stackTrace) {
      _logger.error('Error during IPFS Node initialization', e, stackTrace);
      rethrow;
    }
  }

  Future<void> _initializeHandlers() async {
    _logger.debug('Initializing protocol handlers...');

    try {
      final router = networkHandler.p2pRouter;
      _logger.verbose('Router instance obtained');

      bitswapHandler = BitswapHandler(_config, _blockStore, router);
      _logger.debug('BitswapHandler created');

      await networkHandler.initialize();
      _logger.verbose('NetworkHandler initialized');

      dhtHandler = DHTHandler(_config, router, networkHandler);
      _logger.debug('DHTHandler created');

      pubSubHandler = PubSubHandler(router, _config.nodeId,
          IpfsNodeNetworkEvents(networkHandler.circuitRelayClient, router));
      _logger.debug('PubSubHandler created');

      datastoreHandler = DatastoreHandler(_config);
      _logger.debug('DatastoreHandler created');

      routingHandler = RoutingHandler(_config, networkHandler);
      _logger.debug('RoutingHandler created');

      _logger.info('All handlers initialized successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to initialize handlers', e, stackTrace);
      rethrow;
    }
  }

  /// Starts the IPFS node.
  Future<void> start() async {
    if (!networkHandler.p2pRouter.isInitialized) {
      await networkHandler.p2pRouter.initialize();
    }
    _logger.debug('Starting IPFS Node...');

    await bitswapHandler.start();
    _logger.verbose('BitswapHandler started');

    await dhtHandler.start();
    _logger.verbose('DHTHandler started');

    await pubSubHandler.start();
    _logger.verbose('PubSubHandler started');

    await datastoreHandler.start();
    _logger.verbose('DatastoreHandler started');

    await routingHandler.start();
    _logger.verbose('RoutingHandler started');

    await networkHandler.start();
    _logger.verbose('NetworkHandler started');

    _logger.debug('IPFS Node started successfully');
  }

  /// Stops the IPFS node.
  Future<void> stop() async {
    await bitswapHandler.stop();
    await dhtHandler.stop();
    await pubSubHandler.stop();
    await datastoreHandler.stop();
    await routingHandler.stop();
    await networkHandler.stop();
    await _newContentController.close();
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
}
