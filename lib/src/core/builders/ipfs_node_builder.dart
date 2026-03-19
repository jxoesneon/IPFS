// src/core/builders/ipfs_node_builder.dart
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/di/service_container.dart';
import 'package:dart_ipfs/src/core/ipfs_node/auto_nat_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/bootstrap_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/content_routing_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/datastore_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/dns_link_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node_network_events.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipld_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/mdns_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/pubsub_handler.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/security/security_manager.dart';
import 'package:dart_ipfs/src/protocols/bitswap/bitswap_handler.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_handler.dart';
import 'package:dart_ipfs/src/protocols/graphsync/graphsync_handler.dart';
import 'package:dart_ipfs/src/protocols/ipns/ipns_handler.dart';
import 'package:dart_ipfs/src/storage/hive_datastore.dart';

/// Builder for constructing fully-configured [IPFSNode] instances.
///
/// This builder implements dependency injection and layered initialization
/// to create IPFS nodes with all required components properly wired together.
///
/// The build process initializes components in the following order:
/// 1. **Core systems**: Metrics, security
/// 2. **Storage layer**: BlockStore, datastore, IPLD handler
/// 3. **Network layer**: P2P router, DHT, PubSub, Bitswap (if not offline)
/// 4. **Services**: Content routing, IPNS, GraphSync, AutoNAT (if not offline)
///
/// Example:
/// ```dart
/// final config = IPFSConfig(offline: false);
/// final builder = IPFSNodeBuilder(config);
/// final node = await builder.build();
/// await node.start();
/// ```
///
/// See also:
/// - [IPFSNode] for the main node interface
/// - [IPFSConfig] for configuration options
/// - [ServiceContainer] for dependency injection
/// Builder for creating and configuring an [IPFSNode].
///
/// This class handles the complex orchestration of initializing
/// and registering all required services (networking, storage,
/// protocol handlers) in the correct order.
class IPFSNodeBuilder {
  /// Creates a new builder with the given [config].
  IPFSNodeBuilder(this._config) : _container = ServiceContainer();
  final ServiceContainer _container;
  final IPFSConfig _config;

  /// Builds and returns a fully-configured [IPFSNode].
  ///
  /// This method initializes all layers in order and wires up dependencies.
  /// The returned node is ready to be started with [IPFSNode.start].
  Future<IPFSNode> build() async {
    // Register core systems
    await _initializeCoreSystem();

    // Register storage systems
    await _initializeStorageLayer();

    // Register network systems
    await _initializeNetworkLayer();

    // Register services
    await _initializeServices();

    return IPFSNode.fromContainer(_container);
  }

  Future<void> _initializeCoreSystem() async {
    _container.registerSingleton(MetricsCollector(_config));
    _container.registerSingleton(
      SecurityManager(_config.security, _container.get<MetricsCollector>()),
    );
  }

  Future<void> _initializeStorageLayer() async {
    _container.registerSingleton(BlockStore(path: _config.blockStorePath));
    _container.registerSingleton(BlockStore(path: _config.blockStorePath));

    // Create and inject the Datastore (Hive backend)
    // Note: We need to import HiveDatastore.
    // Since imports are top-level, I'll assume they will be added or I need to add them.
    // I can't add imports here easily with replace, so I'll trust the user/IDE or do a separate add imports step.
    // Wait, I can do it in two chunks? No, multi-chunk only for same file.
    // I will use replace_file_content for this block, and assume I'll fix imports next,
    // OR I can use the tool to add imports if I include the top of file.
    // But this file is large.
    // I will replace this line and then add imports.
    final datastore = HiveDatastore(_config.datastorePath);
    _container.registerSingleton(DatastoreHandler(datastore));
    _container.registerSingleton(
      IPLDHandler(_config, _container.get<BlockStore>()),
    );
  }

  Future<void> _initializeNetworkLayer() async {
    // Skip network initialization if offline
    if (_config.offline) return;

    // Create NetworkHandler (uses generic router interface)
    _container.registerSingleton(NetworkHandler(_config));

    // Get the router from NetworkHandler for other handlers
    final networkHandler = _container.get<NetworkHandler>();
    await networkHandler.initialize();

    _container.registerSingleton(MDNSHandler(_config));

    // Get the router - use the interface for protocol handlers
    final router = networkHandler.router;

    if (_config.enableDHT) {
      _container.registerSingleton(DHTHandler(_config, router, networkHandler));
    }

    // Create IpfsNodeNetworkEvents instance
    final networkEvents = IpfsNodeNetworkEvents(router);
    networkEvents.start();

    if (_config.enablePubSub) {
      _container.registerSingleton(
        PubSubHandler(router, networkHandler.peerID, networkEvents),
      );
    }

    _container.registerSingleton(
      BitswapHandler(_config, _container.get<BlockStore>(), router),
    );

    _container.registerSingleton(BootstrapHandler(_config, networkHandler));
  }

  Future<void> _initializeServices() async {
    // Skip services requiring network if offline
    if (_config.offline) return;

    final networkHandler = _container.get<NetworkHandler>();
    final router = networkHandler.router;

    _container.registerSingleton(
      ContentRoutingHandler(_config, networkHandler),
    );
    _container.registerSingleton(DNSLinkHandler(_config));
    _container.registerSingleton(
      GraphsyncHandler(
        _config,
        router,
        _container.get<BitswapHandler>(),
        _container.get<IPLDHandler>(),
        _container.get<BlockStore>(),
      ),
    );
    _container.registerSingleton(AutoNATHandler(_config, networkHandler));
    if (_container.isRegistered(DHTHandler)) {
      _container.registerSingleton(
        IPNSHandler(
          _config,
          _container.get<SecurityManager>(),
          _container.get<DHTHandler>(),
          _container.isRegistered(PubSubHandler)
              ? _container.get<PubSubHandler>()
              : null,
        ),
      );
    }

    // CircuitRelayService legacy removal
    // if (_config.enableCircuitRelay) {
    //   final relayService = CircuitRelayService(
    //     router,
    //     _config,
    //   );
    //   relayService.start();
    //   _container.registerSingleton(relayService);
    // }
  }

  /// Registers Graphsync related services in the provided container.
  void registerGraphsyncServices(ServiceContainer container) {
    container.registerSingleton(
      GraphsyncHandler(
        _config,
        _container.get<NetworkHandler>().router,
        _container.get<BitswapHandler>(),
        _container.get<IPLDHandler>(),
        _container.get<BlockStore>(),
      ),
    );
  }
}
