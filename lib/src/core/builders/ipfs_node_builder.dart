// src/core/builders/ipfs_node_builder.dart
import 'dart:async';

import '../../protocols/bitswap/bitswap_handler.dart';
import '../../protocols/dcutr/dcutr_handler.dart';
import '../../protocols/dht/dht_handler.dart';
import '../../protocols/graphsync/graphsync_handler.dart';
import '../../protocols/ipns/ipns_handler.dart';
import '../../services/gateway/gateway_server.dart';
import '../../services/rpc/rpc_server.dart';
import '../../utils/logger.dart';
import '../config/ipfs_config.dart';
import '../data_structures/blockstore.dart';
import '../di/service_container.dart';
import '../ipfs_node/auto_nat_handler.dart';
import '../ipfs_node/bootstrap_handler.dart';
import '../ipfs_node/content_routing_handler.dart';
import '../ipfs_node/datastore_handler.dart';
import '../ipfs_node/dns_link_handler.dart';
import '../ipfs_node/ipfs_node.dart';
import '../ipfs_node/ipfs_node_network_events.dart';
import '../ipfs_node/ipld_handler.dart';
import '../ipfs_node/lifecycle_manager.dart';
import '../ipfs_node/mdns_handler.dart';
import '../ipfs_node/network_handler.dart';
import '../ipfs_node/pubsub_handler.dart';
import '../metrics/metrics_collector.dart';
import '../peering/peering_service.dart';
import '../security/denylist_service.dart';
import '../security/security_manager.dart';
import '../storage/memory_datastore.dart';

/// Builder for constructing an [IPFSNode] with customized configuration.
class IPFSNodeBuilder {
  /// Creates a builder with the specified [config].
  IPFSNodeBuilder(this._config) : _container = ServiceContainer();

  final IPFSConfig _config;
  final ServiceContainer _container;
  final Logger _logger = Logger('IPFSNodeBuilder');

  /// Builds and initializes an [IPFSNode].
  Future<IPFSNode> build() async {
    _logger.info('Building IPFS Node...');

    try {
      await _registerCoreServices();
      await _registerNetworkServices();
      await _initializeServices();

      final node = IPFSNode.fromContainer(_container);
      await _registerServerLifecycleServices(node);
      return node;
    } catch (e, stackTrace) {
      _logger.error('Failed to build IPFS Node', e, stackTrace);
      rethrow;
    }
  }

  Future<void> _registerCoreServices() async {
    _container.registerSingleton(_config);

    // Register LifecycleManager early so that any core service, server, or
    // offline-mode node can resolve it from the container.
    final lifecycleManager = LifecycleManager();
    _container.registerSingleton(lifecycleManager);

    final metrics = MetricsCollector(_config);
    _container.registerSingleton(metrics);
    lifecycleManager.register(metrics);

    final denylistService = DenylistService(
      _config.security,
      metrics,
      storagePath:
          _config.security.denylistStoragePath ??
          '${_config.dataPath}/denylist_cache.txt',
    );
    _container.registerSingleton(denylistService);
    lifecycleManager.register(denylistService);

    _container.registerSingleton(SecurityManager(_config.security, metrics));

    final datastore = MemoryDatastore();
    final datastoreHandler = DatastoreHandler(datastore);
    _container.registerSingleton(datastoreHandler);

    final blockStore = BlockStore(path: _config.blockStorePath);
    _container.registerSingleton(blockStore);
    metrics.registerBlockStore(blockStore);

    _container.registerSingleton(IPLDHandler(_config, blockStore));
  }

  Future<void> _registerNetworkServices() async {
    if (_config.offline) return;

    final networkHandler = NetworkHandler(_config);
    _container.registerSingleton(networkHandler);
    await networkHandler.initialize();

    _container.registerSingleton(MDNSHandler(_config));

    final router = networkHandler.router;

    if (_config.enableDHT) {
      final metrics = _container.get<MetricsCollector>();
      final denylistService = _container.isRegistered<DenylistService>()
          ? _container.get<DenylistService>()
          : null;
      final dhtHandler = DHTHandler(
        _config,
        router,
        networkHandler,
        metrics: metrics,
        denylistService: denylistService,
      );
      _container.registerSingleton(dhtHandler);
      _container.get<LifecycleManager>().register(dhtHandler);

      // Provide the routing table size to the metrics collector once the DHT
      // handler is available. The provider is invoked later by the periodic
      // timer, so initialization order at this point is not critical.
      metrics.registerRoutingTableProvider(
        () => dhtHandler.dhtClient.kademliaRoutingTable.peerCount,
      );
    }

    // Create IpfsNodeNetworkEvents instance
    final networkEvents = IpfsNodeNetworkEvents(router);

    if (_config.enablePubSub) {
      _container.registerSingleton(
        PubSubHandler(router, networkHandler.peerID, networkEvents),
      );
    }

    final denylistService = _container.isRegistered<DenylistService>()
        ? _container.get<DenylistService>()
        : null;
    final bitswapHandler = BitswapHandler(
      _config,
      _container.get<BlockStore>(),
      router,
      denylistService: denylistService,
    );
    _container.registerSingleton(bitswapHandler);
    _container.get<LifecycleManager>().register(bitswapHandler);

    _container.registerSingleton(BootstrapHandler(_config, networkHandler));
    _container.get<LifecycleManager>().register(_container.get<BootstrapHandler>());
  }

  Future<void> _initializeServices() async {
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

    // DCUtR (Direct Connection Upgrade through Relay) support.
    _container.registerSingleton(DCUtRHandler(_config, networkHandler));

    // libp2p peering service: keep persistent connections to bootstrap peers.
    _container.registerSingleton(
      PeeringService(
        _config,
        networkHandler,
        peeringConfig: PeeringConfig(peers: _config.network.bootstrapPeers),
      ),
    );

    if (_container.isRegistered(DHTHandler)) {
      final ipnsHandler = IPNSHandler(
        _config,
        _container.get<SecurityManager>(),
        _container.get<DHTHandler>(),
        _container.isRegistered(PubSubHandler)
            ? _container.get<PubSubHandler>()
            : null,
      );
      _container.registerSingleton(ipnsHandler);
      _container.get<LifecycleManager>().register(ipnsHandler);
    }
  }

  Future<void> _registerServerLifecycleServices(IPFSNode node) async {
    final lifecycleManager = _container.get<LifecycleManager>();
    final metrics = _container.get<MetricsCollector>();

    if (_config.enableRPC) {
      final rpcServer = RPCServer(
        node: node,
        address: 'localhost',
        port: 5001,
        metricsCollector: metrics,
        metricsConfig: _config.metrics,
      );
      _container.registerSingleton(rpcServer);
      lifecycleManager.register(rpcServer);
    }

    if (_config.gateway.enabled) {
      final ipnsHandler = _container.isRegistered<IPNSHandler>()
          ? _container.get<IPNSHandler>()
          : null;
      final denylistService = _container.isRegistered<DenylistService>()
          ? _container.get<DenylistService>()
          : null;
      final gatewayServer = GatewayServer(
        blockStore: _container.get<BlockStore>(),
        node: node,
        address: _config.gateway.address,
        port: _config.gateway.port,
        corsOrigins: _config.gateway.corsOrigins,
        metricsCollector: metrics,
        metricsConfig: _config.metrics,
        denylistService: denylistService,
        ipnsResolver: ipnsHandler != null
            ? (String name) async => ipnsHandler.resolve(name)
            : null,
        ipnsRecordResolver: ipnsHandler != null
            ? (String name) async => ipnsHandler.getRecordBytes(name)
            : null,
      );
      _container.registerSingleton(gatewayServer);
      lifecycleManager.register(gatewayServer);
    }
  }
}
