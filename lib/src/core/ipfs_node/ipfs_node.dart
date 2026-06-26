// src/core/ipfs_node/ipfs_node.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/builders/ipfs_node_builder.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/data_structures/link.dart';
import 'package:dart_ipfs/src/core/data_structures/peer.dart';
import 'package:dart_ipfs/src/core/di/service_container.dart';
import 'package:dart_ipfs/src/core/errors/node_errors.dart';
import 'package:dart_ipfs/src/core/ipfs_node/auto_nat_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/bootstrap_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/content_manager.dart';
import 'package:dart_ipfs/src/core/ipfs_node/content_routing_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/datastore_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/dns_link_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipld_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/lifecycle_manager.dart';
import 'package:dart_ipfs/src/core/ipfs_node/mdns_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_manager.dart';
import 'package:dart_ipfs/src/core/ipfs_node/protocol_manager.dart';
import 'package:dart_ipfs/src/core/ipfs_node/pubsub_handler.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/mfs/mfs_manager.dart';
import 'package:dart_ipfs/src/core/plugins/ipfs_plugin.dart';
import 'package:dart_ipfs/src/core/security/security_manager.dart';
import 'package:dart_ipfs/src/core/storage/datastore.dart';
import 'package:dart_ipfs/src/protocols/bitswap/bitswap_handler.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_client.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_handler.dart';
import 'package:dart_ipfs/src/protocols/dht/reprovider.dart';
import 'package:dart_ipfs/src/protocols/graphsync/graphsync_handler.dart';
import 'package:dart_ipfs/src/protocols/ipns/ipns_handler.dart';
import 'package:dart_ipfs/src/protocols/pubsub/pubsub_message.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:dart_ipfs/src/utils/logger.dart';

/// Modes for retrieving content via the [IPFSNode].
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

/// Represents the possible states of an [IPFSNode].
enum NodeState {
  /// The node is created but not yet started.
  stopped,

  /// The node is in the process of starting.
  starting,

  /// The node is fully operational.
  running,

  /// The node is in the process of stopping.
  stopping,

  /// The node encountered a fatal error and cannot continue.
  error,
}

/// The main IPFS node implementation.
///
/// Provides high-level APIs for content addressing, publishing,
/// DHT operations, and peer-to-peer networking.
///
/// **Platform Note**: Storage behavior is platform-dependent. On VM platforms,
/// it uses the local file system. On Web platforms, it uses IndexedDB via the
/// [IpfsPlatform] abstraction.
///
/// [IPFSNode] acts as a facade, orchestrating specialized managers:
/// - [ContentManager]: Handles files, directories, pinning, and CAR files.
/// - [NetworkManager]: Handles peer connectivity and provider discovery.
/// - [ProtocolManager]: Handles PubSub, IPNS, and DNSLink.
class IPFSNode {
  /// Creates an IPFSNode from a pre-configured service container.
  ///
  /// Throws [NodeInitializationError] if required services are missing.
  IPFSNode.fromContainer(this._container) : _logger = Logger('IPFSNode') {
    _logger.debug('Creating IPFS Node from container');

    // Validate required services
    _validateRequiredServices();

    // Initialize managers with constructor injection
    _contentManager = ContentManager(
      datastoreHandler: _container.get<DatastoreHandler>(),
      newContentController: _newContentController,
      blockStore: _container.get<BlockStore>(),
      bitswapHandler: _container.isRegistered(BitswapHandler)
          ? _container.get<BitswapHandler>()
          : null,
    );

    _networkManager = NetworkManager(
      networkHandler: _container.isRegistered<NetworkHandler>()
          ? _container.get<NetworkHandler>()
          : null,
      datastoreHandler: _container.get<DatastoreHandler>(),
      dhtHandler: _container.isRegistered<DHTHandler>()
          ? _container.get<DHTHandler>()
          : null,
      contentRoutingHandler: _container.isRegistered(ContentRoutingHandler)
          ? _container.get<ContentRoutingHandler>()
          : null,
      bitswapHandler: _container.isRegistered(BitswapHandler)
          ? _container.get<BitswapHandler>()
          : null,
    );

    _protocolManager = ProtocolManager(
      pubSubHandler: _container.isRegistered(PubSubHandler)
          ? _container.get<PubSubHandler>()
          : null,
      dhtHandler: _container.isRegistered<DHTHandler>()
          ? _container.get<DHTHandler>()
          : null,
      contentRoutingHandler: _container.isRegistered(ContentRoutingHandler)
          ? _container.get<ContentRoutingHandler>()
          : null,
    );

    _mfsManager = MFSManager(
      _container.get<BlockStore>(),
      _container.get<DatastoreHandler>().datastore,
    );

    // Wire up the periodic reprovider when DHT and config are available.
    if (_container.isRegistered<DHTHandler>() &&
        _container.isRegistered<IPFSConfig>()) {
      _reprovider = Reprovider(
        config: _container.get<IPFSConfig>().dht,
        dhtHandler: _container.get<DHTHandler>(),
        pinManager: _container.get<BlockStore>().pinManager,
        mfsManager: _mfsManager,
        metrics: _container.isRegistered<MetricsCollector>()
            ? _container.get<MetricsCollector>()
            : null,
      );
    }

    _pluginManager = PluginManager(this);

    _lifecycleManager = _container.isRegistered<LifecycleManager>()
        ? _container.get<LifecycleManager>()
        : LifecycleManager();

    // Register services for lifecycle management
    _lifecycleManager.register(_container.get<BlockStore>());
    _lifecycleManager.register(_contentManager);
    _lifecycleManager.register(_networkManager);
    _lifecycleManager.register(_protocolManager);
    if (_reprovider != null) {
      _lifecycleManager.register(_reprovider!);
    }

    // Set back-references for handlers that need the IPFSNode instance
    if (_container.isRegistered<NetworkHandler>()) {
      _container.get<NetworkHandler>().setIpfsNode(this);
    }
  }

  final ServiceContainer _container;
  final Logger _logger;
  late final ContentManager _contentManager;
  late final NetworkManager _networkManager;
  late final ProtocolManager _protocolManager;
  late final LifecycleManager _lifecycleManager;
  late final MFSManager _mfsManager;
  late final PluginManager _pluginManager;
  Reprovider? _reprovider;

  NodeState _state = NodeState.stopped;

  /// Returns the current state of the node.
  NodeState get state => _state;

  /// Returns the Mutable File System (MFS) manager.
  MFSManager get mfs => _mfsManager;

  /// Returns the periodic [Reprovider] service, if DHT is enabled.
  Reprovider? get reprovider => _reprovider;

  /// Returns the Plugin manager.
  PluginManager get plugins => _pluginManager;

  /// Returns the SecurityManager.
  SecurityManager get securityManager => _container.get<SecurityManager>();

  /// Whether the node is currently running.
  bool get isRunning => _state == NodeState.running;

  final StreamController<String> _newContentController =
      StreamController<String>.broadcast();

  /// Returns a [Future] that resolves to an [IPFSNode] built from the [config].
  ///
  /// This is the recommended way to instantiate a node.
  static Future<IPFSNode> create(IPFSConfig config) async {
    final builder = IPFSNodeBuilder(config);
    return await builder.build();
  }

  // Public API Getters for external access

  /// Returns the peer ID of this node.
  ///
  /// Returns 'offline' if the network is not initialized.
  String get peerId => _networkManager.peerId;

  /// Returns a [Stream] of bandwidth metrics as a [Map].
  Stream<Map<String, dynamic>> get bandwidthMetrics {
    if (_container.isRegistered<MetricsCollector>()) {
      return _container.get<MetricsCollector>().metricsStream;
    }
    return const Stream.empty();
  }

  /// Returns a [List] of multiaddresses this node is listening on.
  List<String> get addresses {
    try {
      if (!_container.isRegistered<NetworkHandler>()) return [];
      final networkHandler = _container.get<NetworkHandler>();
      final router = networkHandler.router;
      return router.listeningAddresses;
    } catch (e) {
      _logger.warning('Failed to get addresses: $e');
      return [];
    }
  }

  /// Returns the underlying [BlockStore].
  BlockStore get blockStore {
    return _container.get<BlockStore>();
  }

  /// Returns the [DHTClient] for peer and content discovery.
  ///
  /// Throws [StateError] if the node is in offline mode or DHT is not available.
  DHTClient get dhtClient {
    if (!_container.isRegistered<DHTHandler>()) {
      throw StateError('DHT client not available (offline mode)');
    }
    try {
      final dhtHandler = _container.get<DHTHandler>();
      return dhtHandler.dhtClient;
    } catch (e) {
      throw StateError('DHT client not available: $e');
    }
  }

  /// Returns a [Future] that resolves to a [List] of currently connected peer IDs.
  Future<List<String>> get connectedPeers => _networkManager.connectedPeers;

  /// Returns a [Future] that resolves to the public key of this node as a base64 encoded protobuf.
  Future<String> get publicKey async {
    try {
      if (!_container.isRegistered(SecurityManager)) return '';
      final key = await _container.get<SecurityManager>().getPrivateKey('self');
      if (key != null) {
        final keyBytes = key.publicKeyBytes;
        if (keyBytes.isEmpty) return '';

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

  /// Resolves a [peerIdStr] to its known multiaddresses.
  List<String> resolvePeerId(String peerIdStr) =>
      _networkManager.resolvePeerId(peerIdStr);

  /// Returns a [Future] that resolves to a [List] of CIDs currently pinned by this node.
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

  /// Returns a [Future] that resolves to the raw content associated with the given [cid].
  ///
  /// This is an alias for [get].
  Future<Uint8List?> cat(String cid) async => get(cid);

  /// Returns a [Future] that completes when the node manually connects to a peer using its [multiaddr].
  Future<void> connectToPeer(String multiaddr) =>
      _networkManager.connectToPeer(multiaddr);

  /// Returns a [Future] that completes when the node gracefully disconnects from a peer identified by [peerIdOrAddr].
  Future<void> disconnectFromPeer(String peerIdOrAddr) =>
      _networkManager.disconnectFromPeer(peerIdOrAddr);

  /// Returns a [Future] that resolves to the CID corresponding to the IPNS [name].
  Future<String> resolveIPNS(String name) => _protocolManager.resolveIPNS(name);

  // PubSub API

  /// Returns a [Future] that completes when the node subscribes to a PubSub [topic].
  Future<void> subscribe(String topic) => _protocolManager.subscribe(topic);

  /// Returns a [Future] that completes when the node unsubscribes from a PubSub [topic].
  Future<void> unsubscribe(String topic) => _protocolManager.unsubscribe(topic);

  /// Returns a [Future] that completes when the node publishes a [message] to a PubSub [topic].
  Future<void> publish(String topic, String message) =>
      _protocolManager.publish(topic, message);

  /// Returns a [Stream] of incoming [PubSubMessage]s for all subscribed topics.
  Stream<PubSubMessage> get pubsubMessages => _protocolManager.pubsubMessages;

  /// Returns a [Future] that completes when the IPFS node and all its subsystems have started.
  ///
  /// Transitions the state from [NodeState.stopped] to [NodeState.running].
  /// Throws [NodeStateError] if the node is already running or starting.
  /// Throws [NodeStartupError] if any critical subsystem fails to start.
  Future<void> start() async {
    if (_state == NodeState.running || _state == NodeState.starting) {
      throw NodeStateError('Node is already ${_state.name}');
    }

    _state = NodeState.starting;
    _logger.info('Starting IPFS Node...');

    try {
      await _lifecycleManager.startAll();
      await _mfsManager.init();
      await _pluginManager.initAll();
      await _pluginManager.startAll();
      _state = NodeState.running;
      _logger.info('IPFS Node started successfully');
    } catch (e, stackTrace) {
      _state = NodeState.error;
      _logger.error('Failed to start IPFS Node', e, stackTrace);
      throw NodeStartupError('Failed to start IPFS node', details: e);
    }
  }

  /// Returns a [Future] that completes when the IPFS node has stopped gracefully, releasing all resources.
  ///
  /// Transitions the state from [NodeState.running] to [NodeState.stopped].
  /// Throws [NodeShutdownError] if any critical subsystem fails to stop.
  Future<void> stop() async {
    if (_state == NodeState.stopped || _state == NodeState.stopping) {
      _logger.warning('Node is already ${_state.name}');
      return;
    }

    _state = NodeState.stopping;
    _logger.info('Stopping IPFS Node...');

    try {
      await _pluginManager.stopAll();
      await _lifecycleManager.stopAll();
      _state = NodeState.stopped;
      _logger.info('IPFS Node stopped successfully');
    } catch (e, stackTrace) {
      _state = NodeState.error;
      _logger.error('Failed to stop IPFS Node', e, stackTrace);
      throw NodeShutdownError('Failed to stop IPFS node', details: e);
    }
  }

  /// Returns a [Future] that completes when the IPFS node has restarted by performing a stop and then a start.
  ///
  /// Throws [NodeShutdownError] if stop fails.
  /// Throws [NodeStartupError] if start fails.
  Future<void> restart() async {
    _logger.info('Restarting IPFS Node...');
    await stop();
    await start();
  }

  /// Returns a [Future] that resolves to the CID of the added file [data].
  Future<String> addFile(Uint8List data) => _contentManager.addFile(data);

  /// Returns a [Future] that resolves to the CID of the added file from [dataStream].
  Future<String> addFileStream(Stream<List<int>> dataStream) =>
      _contentManager.addFileStream(dataStream);

  /// Returns a [Future] that resolves to the CID of the added [directoryContent].
  Future<String> addDirectory(Map<String, dynamic> directoryContent) =>
      _contentManager.addDirectory(directoryContent);

  /// Sets the mode for retrieving content.
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

  /// Returns a [Future] that resolves to the content of a file or directory associated with the given [cid].
  Future<Uint8List?> get(String cid, {String path = ''}) => _contentManager.get(
        cid,
        path: path,
        gatewayMode: _gatewayMode,
        customGatewayUrl: _customGatewayUrl,
      );

  /// Returns a [Future] that resolves to a [List] of [Link]s representing the contents of an IPFS directory.
  Future<List<Link>> ls(String cid) => _contentManager.ls(cid);

  /// Returns a [Future] that completes when the given [cid] is pinned to prevent it from being garbage collected.
  Future<void> pin(String cid) => _contentManager.pin(cid);

  /// Returns a [Future] that resolves to `true` if the given [cid] was successfully unpinned from IPFS.
  Future<bool> unpin(String cid) => _contentManager.unpin(cid);

  /// Returns a [Future] that completes when an IPNS record is published for the given [cid].
  Future<void> publishIPNS(String cid, {required String keyName}) =>
      _protocolManager.publishIPNS(cid, keyName: keyName);

  /// Returns a [Future] that completes when the given CAR (Content Addressable Archive) file [carFile] is imported.
  Future<void> importCAR(Uint8List carFile) =>
      _contentManager.importCAR(carFile);

  /// Returns a [Future] that resolves to the CAR file bytes for the given [cid].
  Future<Uint8List> exportCAR(String cid) => _contentManager.exportCAR(cid);

  /// Returns a [Future] that resolves to a [List] of multiaddresses for providers of the given [cid].
  Future<List<String>> findProviders(String cid) =>
      _networkManager.findProviders(cid);

  /// Returns a [Future] that completes when a specific block associated with [cid] is requested from a [peer] via Bitswap.
  Future<void> requestBlock(String cid, Peer peer) =>
      _networkManager.requestBlock(cid, peer);

  /// Returns a [Future] that resolves to the CID corresponding to the given [domainName] via DNSLink.
  Future<String> resolveDNSLink(String domainName) =>
      _protocolManager.resolveDNSLink(domainName);

  /// Returns a [Future] that resolves to a health status map for all subsystems.
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

  /// Returns a [Future] that resolves to the status map of the given service [T].
  Future<Map<String, dynamic>> _getServiceStatus<T extends Object>() async {
    if (_container.isRegistered<T>()) {
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
  /// Returns the underlying [Datastore].
  Datastore get datastore => _container.get<DatastoreHandler>().datastore;

  /// Returns the [RouterInterface] used for networking, or `null` if not available.
  RouterInterface? get router {
    if (_container.isRegistered<NetworkHandler>()) {
      return _container.get<NetworkHandler>().router;
    }
    return null;
  }

  /// Returns the [BitswapHandler] instance, or `null` if not registered.
  BitswapHandler? get bitswap {
    if (_container.isRegistered(BitswapHandler)) {
      return _container.get<BitswapHandler>();
    }
    return null;
  }

  /// Returns the [IPNSHandler] instance, or `null` if not registered.
  IPNSHandler? get ipns {
    if (_container.isRegistered<IPNSHandler>()) {
      return _container.get<IPNSHandler>();
    }
    return null;
  }

  /// Returns the [MetricsCollector] instance, or `null` if not registered.
  MetricsCollector? get metricsCollector {
    if (_container.isRegistered<MetricsCollector>()) {
      return _container.get<MetricsCollector>();
    }
    return null;
  }

  /// Returns the [DHTHandler] instance, or `null` if not registered.
  DHTHandler? get dhtHandler {
    if (_container.isRegistered<DHTHandler>()) {
      return _container.get<DHTHandler>();
    }
    return null;
  }

  /// Returns the peer ID of this node.
  String get peerID => _networkManager.peerId;

  // Event streams
  /// Returns a [Stream] of new content CIDs added to this node.
  Stream<String> get onNewContent => _newContentController.stream;

  /// Validates that all required services are registered in the container
  void _validateRequiredServices() {
    final requiredServices = [
      MetricsCollector,
      SecurityManager,
      BlockStore,
      DatastoreHandler,
      IPLDHandler,
    ];

    for (final service in requiredServices) {
      if (!_container.isRegistered(service)) {
        _logger.error('Required service not found: ${service.toString()}');
        throw StateError('Missing required service: ${service.toString()}');
      }
    }

    _logger.debug('All required services validated successfully');
  }
}
