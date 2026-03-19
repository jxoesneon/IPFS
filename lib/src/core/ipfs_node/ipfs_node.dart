// src/core/ipfs_node/ipfs_node.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/builders/ipfs_node_builder.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/data_structures/directory.dart';
import 'package:dart_ipfs/src/core/data_structures/link.dart';
import 'package:dart_ipfs/src/core/data_structures/merkle_dag_node.dart';
import 'package:dart_ipfs/src/core/data_structures/peer.dart';
import 'package:dart_ipfs/src/core/data_structures/pin.dart';
import 'package:dart_ipfs/src/core/di/service_container.dart';
import 'package:dart_ipfs/src/core/ipfs_node/auto_nat_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/bootstrap_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/content_routing_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/dns_link_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipld_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/mdns_handler.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/security/security_manager.dart';
import 'package:dart_ipfs/src/core/storage/datastore.dart';
import 'package:dart_ipfs/src/proto/generated/core/pin.pb.dart';
import 'package:dart_ipfs/src/protocols/bitswap/bitswap_handler.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_client.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_handler.dart';
import 'package:dart_ipfs/src/protocols/graphsync/graphsync_handler.dart';
import 'package:dart_ipfs/src/protocols/ipns/ipns_handler.dart';
import 'package:dart_ipfs/src/protocols/pubsub/pubsub_message.dart';
import 'package:dart_ipfs/src/transport/http_gateway_client.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:dart_ipfs/src/utils/base58.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:fixnum/fixnum.dart' as fixnum;

import 'datastore_handler.dart';
import 'network_handler.dart';
import 'pubsub_handler.dart';

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
/// // print('Peer ID: ${node.peerID}');
/// ```
///
/// **Adding Content:**
/// ```dart
/// final cid = await node.addFile(fileBytes);
/// // print('Added content: $cid');
/// ```
///
/// **Retrieving Content:**
/// ```dart
/// final data = await node.get(cid);
/// ```
///
/// **Lifecycle:**
/// Always call `start` before using the node and `stop` when done:
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
/// - [IPFSNodeBuilder] for advanced node construction
/// Modes for retrieving content via the [IPFSNode].
///
/// Strategies:
/// - [internal]: Use the native Dart P2P node (libp2p).
/// - [public]: Use public HTTP gateways (e.g. ipfs.io).
/// - [local]: Use a local IPFS daemon (e.g. go-ipfs at localhost:8080).
/// - [custom]: Use a user-defined HTTP gateway URL.
enum GatewayMode {
  /// Use internal P2P node (default).
  internal,

  /// Use public gateway (ipfs.io).
  public,

  /// Use local gateway (localhost:8080).
  local,

  /// Use custom URL.
  custom,
}

/// The main IPFS node implementation.
///
/// Provides high-level APIs for content addressing, publishing,
/// DHT operations, and peer-to-peer networking.
class IPFSNode {
  /// Creates an IPFSNode from a pre-configured service container.
  IPFSNode.fromContainer(this._container) : _logger = Logger('IPFSNode') {
    _logger.debug('Creating IPFS Node from container');

    // Validate required services
    _validateRequiredServices();
  }
  final ServiceContainer _container;
  final Logger _logger;
  final HttpGatewayClient _httpGatewayClient = HttpGatewayClient();
  final StreamController<String> _newContentController =
      StreamController<String>.broadcast();

  /// Factory method to create and build an IPFS node from configuration.
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
      return networkHandler.peerID;
    } catch (e) {
      _logger.warning('Failed to get peerId: $e');
      return 'unknown';
    }
  }

  /// Broadcast stream of bandwidth metrics
  Stream<Map<String, dynamic>> get bandwidthMetrics {
    if (_container.isRegistered(MetricsCollector)) {
      return _container.get<MetricsCollector>().metricsStream;
    }
    return const Stream.empty();
  }

  /// Get the addresses this node is listening on
  List<String> get addresses {
    try {
      if (!_container.isRegistered(NetworkHandler)) return [];
      final networkHandler = _container.get<NetworkHandler>();
      final router = networkHandler.router;
      return router.listeningAddresses;
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
  Future<List<String>> get connectedPeers async {
    try {
      if (_container.isRegistered(NetworkHandler)) {
        return await _container.get<NetworkHandler>().listConnectedPeers();
      }
      return [];
    } catch (e) {
      _logger.warning('Failed to get connected peers: $e');
      return [];
    }
  }

  /// Get the public key of this node (base64 encoded)
  Future<String> get publicKey async {
    try {
      if (!_container.isRegistered(SecurityManager)) return '';
      final key = await _container.get<SecurityManager>().getPrivateKey('self');
      if (key != null) {
        final keyBytes = key.publicKeyBytes;
        if (keyBytes.isEmpty) return '';

        // Manually construct Protobuf: PublicKey { required KeyType Type = 1; required bytes Data = 2; }
        // Type 2 = Secp256k1
        // Tag 1 (Type) = (1 << 3) | 0 = 8. Value = 2. -> [0x08, 0x02]
        // Tag 2 (Data) = (2 << 3) | 2 = 18 (0x12). Value = length + bytes.
        // Compressed Secp256k1 is 33 bytes, fits in 1 byte varint.

        final protoBytes = <int>[
          0x08, 0x02, // Type: Secp256k1
          0x12, keyBytes.length, // Data tag + length
          ...keyBytes,
        ];

        return base64.encode(protoBytes);
      }
      return '';
    } catch (e) {
      _logger.warning('Failed to get public key: $e');
      return '';
    }
  }

  /// Resolve a peer ID to its known addresses (from Routing Table)
  List<String> resolvePeerId(String peerIdStr) {
    try {
      if (!_container.isRegistered(NetworkHandler)) return [];
      final router = _container.get<NetworkHandler>().router;
      return router.resolvePeerId(peerIdStr);
    } catch (e) {
      _logger.warning('Failed to resolve peer ID $peerIdStr: $e');
      return [];
    }
  }

  /// Get list of pinned CIDs
  Future<List<String>> get pinnedCids async {
    try {
      if (!_container.isRegistered(DatastoreHandler)) return [];
      final pins = await _container.get<DatastoreHandler>().loadPinnedCIDs();
      return pins.toList();
    } catch (e) {
      _logger.warning('Failed to load pinned CIDs: $e');
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
      if (!_container.isRegistered(NetworkHandler)) {
        throw StateError('NetworkHandler not available');
      }
      await _container.get<NetworkHandler>().connectToPeer(multiaddr);
    } catch (e) {
      _logger.error('Failed to connect to peer: $e');
      rethrow;
    }
  }

  /// Disconnect from a peer
  Future<void> disconnectFromPeer(String peerIdOrAddr) async {
    try {
      if (!_container.isRegistered(NetworkHandler)) return;
      await _container.get<NetworkHandler>().disconnectFromPeer(peerIdOrAddr);
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

  // PubSub API

  /// Subscribe to a topic
  Future<void> subscribe(String topic) async {
    try {
      if (!_container.isRegistered(PubSubHandler)) return;
      await _container.get<PubSubHandler>().subscribe(topic);
    } catch (e) {
      _logger.error('Failed to subscribe: $e');
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribe(String topic) async {
    try {
      if (!_container.isRegistered(PubSubHandler)) return;
      await _container.get<PubSubHandler>().unsubscribe(topic);
    } catch (e) {
      _logger.error('Failed to unsubscribe: $e');
    }
  }

  /// Publish a message
  Future<void> publish(String topic, String message) async {
    try {
      if (!_container.isRegistered(PubSubHandler)) {
        throw StateError('PubSubHandler not available');
      }
      await _container.get<PubSubHandler>().publish(topic, message);
    } catch (e) {
      _logger.error('Failed to publish: $e');
      rethrow;
    }
  }

  /// Stream of incoming PubSub messages
  Stream<PubSubMessage> get pubsubMessages {
    if (_container.isRegistered(PubSubHandler)) {
      return _container.get<PubSubHandler>().messages;
    }
    return const Stream.empty();
  }

  /// Starts the IPFS node and all its subsystems.
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

  /// Stops the IPFS node gracefully, releasing all resources.
  Future<void> stop() async {
    _logger.debug('Stopping IPFS Node...');

    try {
      // Stop in reverse order of initialization

      // Stop high-level services
      if (_container.isRegistered(IPNSHandler)) {
        await _container.get<IPNSHandler>().stop();
      }
      if (_container.isRegistered(AutoNATHandler)) {
        await _container.get<AutoNATHandler>().stop();
      }
      if (_container.isRegistered(GraphsyncHandler)) {
        await _container.get<GraphsyncHandler>().stop();
      }
      if (_container.isRegistered(DNSLinkHandler)) {
        await _container.get<DNSLinkHandler>().stop();
      }
      if (_container.isRegistered(ContentRoutingHandler)) {
        await _container.get<ContentRoutingHandler>().stop();
      }

      // Stop network layer
      if (_container.isRegistered(BitswapHandler)) {
        await _container.get<BitswapHandler>().stop();
      }
      if (_container.isRegistered(PubSubHandler)) {
        await _container.get<PubSubHandler>().stop();
      }
      if (_container.isRegistered(DHTHandler)) {
        await _container.get<DHTHandler>().stop();
      }
      if (_container.isRegistered(BootstrapHandler)) {
        await _container.get<BootstrapHandler>().stop();
      }
      if (_container.isRegistered(MDNSHandler)) {
        await _container.get<MDNSHandler>().stop();
      }
      if (_container.isRegistered(NetworkHandler)) {
        await _container.get<NetworkHandler>().stop();
      }

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

  /// Adds a file to IPFS and returns its CID.
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
      // print('Error adding file: $e');
      rethrow;
    }
  }

  /// Adds file content from a stream (memory-efficient for large files)
  ///
  /// Collects chunks into a BytesBuilder and then creates a block.
  /// For truly large files, consider chunking into multiple blocks.
  Future<String> addFileStream(Stream<List<int>> dataStream) async {
    try {
      final builder = BytesBuilder();
      await for (final chunk in dataStream) {
        builder.add(chunk);
      }
      return addFile(builder.takeBytes());
    } catch (e) {
      _logger.error('Error adding file from stream: $e');
      rethrow;
    }
  }

  /// Adds a directory to IPFS and returns its CID.
  Future<String> addDirectory(Map<String, dynamic> directoryContent) async {
    // Create a new directory node
    // Note: Standard UnixFS directories don't store their own name/path internally
    final directoryManager = IPFSDirectoryManager();

    // Process each entry in the directory content
    for (final entry in directoryContent.entries) {
      if (entry.value is Uint8List) {
        // Handle file
        final cid = await addFile(entry.value as Uint8List);
        directoryManager.addEntry(
          IPFSDirectoryEntry(
            name: entry.key,
            hash: CID
                .decode(cid)
                .toBytes(), // Use toBytes() for binary CID (preserves version/codec)
            size: fixnum.Int64((entry.value as Uint8List).length),
            isDirectory: false,
          ),
        );
      } else if (entry.value is Map) {
        // Handle subdirectory recursively
        final subDirCid = await addDirectory(
          entry.value as Map<String, dynamic>,
        );
        directoryManager.addEntry(
          IPFSDirectoryEntry(
            name: entry.key,
            hash: CID.decode(subDirCid).toBytes(),
            size: fixnum.Int64(
              0,
            ), // Tsize should ideally be known, but 0 is acceptable if unknown for now
            isDirectory: true,
          ),
        );
      }
    }

    // Create a block from the directory data
    final pbNode = directoryManager.build();
    final block = await Block.fromData(
      pbNode.writeToBuffer(),
      format: 'dag-pb',
    );

    // Store the directory block
    await _container.get<DatastoreHandler>().putBlock(block);

    // Return the CID of the directory
    return block.cid.toString();
  }

  /// Gets the content of a file or directory from IPFS.
  ///
  /// [cid] is the Content Identifier of the file/directory
  /// [path] is an optional path within the directory
  GatewayMode _gatewayMode = GatewayMode.internal;
  String _customGatewayUrl = '';

  /// Sets the mode for retrieving content.
  ///
  /// [mode] defines the strategy (internal P2P, public gateway, etc.).
  /// [customUrl] is required if [mode] is [GatewayMode.custom].
  void setGatewayMode(GatewayMode mode, {String? customUrl}) {
    _gatewayMode = mode;
    if (customUrl != null) {
      _customGatewayUrl = customUrl;
    }
    _logger.info('Switched Gateway Mode to: $mode');
  }

  /// Gets the content of a file or directory from IPFS.
  ///
  /// [cid] is the Content Identifier of the file/directory
  /// [path] is an optional path within the directory
  Future<Uint8List?> get(String cid, {String path = ''}) async {
    try {
      // MODE: Public / Local / Custom -> Use HTTP Gateway exclusively
      if (_gatewayMode != GatewayMode.internal) {
        String url;
        switch (_gatewayMode) {
          case GatewayMode.public:
            url = 'https://ipfs.io/ipfs';
            break;
          case GatewayMode.local:
            url = 'http://127.0.0.1:8080/ipfs';
            break;
          case GatewayMode.custom:
            url = _customGatewayUrl;
            break;
          default:
            url = 'https://ipfs.io/ipfs';
        }
        _logger.debug('Retrieving via Gateway ($url): $cid');
        // Currently HttpGatewayClient is hardcoded to ipfs.io in its implementation?
        // We might need to update HttpGatewayClient to accept a base URL.
        // For now, assuming HttpGatewayClient logic will be updated or uses default.
        // Actually, let's just use the client we have, but we need to tell it where to look.
        // Since HttpGatewayClient instance is private and hardcoded, we should probably
        // update HttpGatewayClient to take a baseUrl in `get`.
        // Let's assume for this step we update HttpGatewayClient first?
        // Wait, I can't update HttpGatewayClient in this tool call.
        // I will just call it for now and fix it in next step.
        return await _httpGatewayClient.get(cid, baseUrl: url);
      }

      // MODE: Internal -> Use Native P2P
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
      if (_container.isRegistered(BitswapHandler)) {
        final networkBlock = await _container.get<BitswapHandler>().wantBlock(
          cid,
        );
        if (networkBlock?.data != null) {
          return networkBlock!.data;
        }
      }

      // 3. HTTP Gateway Fallback (Hybrid Compatibility) - KEEP THIS for Internal Mode too?
      // Yes, "Hybrid Fallback" is a feature of Internal Mode.
      _logger.debug(
        'P2P retrieval failed, attempting HTTP gateway fallback for $cid',
      );
      final gatewayData = await _httpGatewayClient.get(cid);
      if (gatewayData != null) {
        return gatewayData;
      }

      return null;
    } catch (e) {
      // print('Error retrieving content for CID $cid: $e');
      return null;
    }
  }

  Future<Uint8List?> _resolvePathInDirectory(
    MerkleDAGNode dirNode,
    String path,
  ) async {
    final pathParts = path.split('/').where((part) => part.isNotEmpty).toList();

    for (final link in dirNode.links) {
      if (link.name == pathParts[0]) {
        final childBlock = await _container.get<DatastoreHandler>().getBlock(
          link.cid.toString(),
        );
        if (childBlock == null) return null;

        if (pathParts.length == 1) {
          return childBlock.data;
        } else {
          final childNode = MerkleDAGNode.fromBytes(childBlock.data);
          return await _resolvePathInDirectory(
            childNode,
            pathParts.sublist(1).join('/'),
          );
        }
      }
    }
    return null;
  }

  /// Lists the contents of an IPFS directory.
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
      // print('Error listing directory $cid: $e');
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

      // print('Successfully pinned CID: $cid');
    } catch (e) {
      // print('Error pinning CID $cid: $e');
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
        // Remove from pins in datastore using /pins/ key prefix
        final pinKey = Key('/pins/$cid');
        await _container.get<DatastoreHandler>().datastore.delete(pinKey);
      }

      return success;
    } catch (e) {
      return false;
    }
  }

  // Add this method to the IPFSNode class
  /// Publishes an IPNS record for the given CID.
  Future<void> publishIPNS(String cid, {required String keyName}) async {
    try {
      // Validate CID
      if (!_container.get<DHTHandler>().isValidCID(cid)) {
        throw ArgumentError('Invalid CID: $cid');
      }

      // Delegate to DHT handler for IPNS record publishing
      await _container.get<DHTHandler>().publishIPNS(cid, keyName: keyName);

      // print(
      //   'Successfully published IPNS record for CID: $cid with key: $keyName',
      // );
    } catch (e) {
      // print('Error publishing IPNS record: $e');
      rethrow;
    }
  }

  /// Imports a CAR (Content Addressable Archive) file.
  Future<void> importCAR(Uint8List carFile) async {
    try {
      await _container.get<DatastoreHandler>().importCAR(carFile);
    } catch (e) {
      // print('Error importing CAR file: $e');
      rethrow;
    }
  }

  /// Exports a CAR file for the given CID.
  Future<Uint8List> exportCAR(String cid) async {
    try {
      // Delegate to the datastoreHandler which has the CAR export implementation
      return await _container.get<DatastoreHandler>().exportCAR(cid);
    } catch (e) {
      // print('Error exporting CAR file: $e');
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
      final dhtProviders = await _container.get<DHTHandler>().findProviders(
        cidObj,
      );
      if (dhtProviders.isNotEmpty) {
        // Convert V_PeerInfo to String peer IDs
        return dhtProviders
            .map((p) => Base58().encode(Uint8List.fromList(p.peerId)))
            .toList();
      }

      // If DHT lookup fails, try finding through routing handler
      final routingProviders = await _container
          .get<ContentRoutingHandler>()
          .findProviders(cid);
      if (routingProviders.isNotEmpty) {
        return routingProviders;
      }

      // No providers found
      return [];
    } catch (e) {
      // print('Error finding providers for CID $cid: $e');
      return [];
    }
  }

  /// Requests a specific block from a peer via Bitswap.
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
      // print('Error requesting block $cid from peer ${peer.toString()}: $e');
      rethrow;
    }
  }

  /// Resolves a DNSLink to its corresponding CID.
  Future<String> resolveDNSLink(String domainName) async {
    try {
      // First try resolving through the routing handler
      final cid = await _container.get<ContentRoutingHandler>().resolveDNSLink(
        domainName,
      );
      if (cid != null) {
        return cid;
      }

      // If routing handler fails, try DHT handler
      final dhtCid = await _container.get<DHTHandler>().resolveDNSLink(
        domainName,
      );
      if (dhtCid != null) {
        return dhtCid;
      }

      throw Exception('Failed to resolve DNSLink for domain: $domainName');
    } catch (e) {
      // print('Error resolving DNSLink for domain $domainName: $e');
      rethrow;
    }
  }

  /// Returns a health status map for all subsystems.
  Future<Map<String, dynamic>> getHealthStatus() async {
    return {
      'core': {
        'security': await _getServiceStatus<SecurityManager>(),
        'metrics': await _getServiceStatus<MetricsCollector>(),
      },
      'storage': {
        'blockstore': await _getServiceStatus<BlockStore>(),
        'datastore': await _getServiceStatus<DatastoreHandler>(),
        'ipld': await _getServiceStatus<IPLDHandler>(),
      },
      'network': {
        'dht': await _getServiceStatus<DHTHandler>(),
        'pubsub': await _getServiceStatus<PubSubHandler>(),
        'bitswap': await _getServiceStatus<BitswapHandler>(),
        'mdns': await _getServiceStatus<MDNSHandler>(),
        'bootstrap': await _getServiceStatus<BootstrapHandler>(),
      },
      'services': {
        'routing': await _getServiceStatus<ContentRoutingHandler>(),
        'dnslink': await _getServiceStatus<DNSLinkHandler>(),
        'graphsync': await _getServiceStatus<GraphsyncHandler>(),
        'autonat': await _getServiceStatus<AutoNATHandler>(),
        'ipns': await _getServiceStatus<IPNSHandler>(),
      },
    };
  }

  Future<Map<String, dynamic>> _getServiceStatus<T>() async {
    if (_container.isRegistered(T)) {
      try {
        return await (_container.get<T>() as dynamic).getStatus()
            as Map<String, dynamic>;
      } catch (e) {
        return {'status': 'error', 'message': e.toString()};
      }
    }
    return {'status': 'disabled'};
  }

  // Core getters
  /// Access to the underlying datastore.
  Datastore get datastore => _container.get<DatastoreHandler>().datastore;

  /// Access to the network router.
  RouterInterface? get router {
    if (_container.isRegistered(NetworkHandler)) {
      return _container.get<NetworkHandler>().router;
    }
    return null;
  }

  /// Access to the Bitswap handler.
  BitswapHandler? get bitswap {
    if (_container.isRegistered(BitswapHandler)) {
      return _container.get<BitswapHandler>();
    }
    return null;
  }

  /// Access to the DHT handler.
  DHTHandler? get dhtHandler {
    if (_container.isRegistered(DHTHandler)) {
      return _container.get<DHTHandler>();
    }
    return null;
  }

  /// This node's peer ID.
  String get peerID => _container.get<NetworkHandler>().peerID;

  // Event streams
  /// Stream of new content CIDs added to this node.
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

  /// Returns the service container for dependency injection.
  ServiceContainer get container => _container;
}
