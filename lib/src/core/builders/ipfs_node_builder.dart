// src/core/builders/ipfs_node_builder.dart
import 'dart:async';

import 'package:cryptography/cryptography.dart';

import '../../platform/platform.dart';

import '../../protocols/bitswap/bitswap_handler.dart';
import '../../protocols/dcutr/dcutr_handler.dart';
import '../../protocols/dht/dht_handler.dart';
import '../../protocols/graphsync/graphsync_handler.dart';
import '../../protocols/identify/identify_handler.dart';
import '../../protocols/identify/identify_push_handler.dart';
import '../../protocols/ipns/ipns_handler.dart';
import '../../protocols/ping/ping_handler.dart';
import '../../services/gateway/gateway_server.dart';
import '../../services/rpc/rpc_server.dart';
import '../../transport/libp2p_router.dart';
import '../../utils/logger.dart';
import '../config/ipfs_config.dart';
import '../crypto/ed25519_signer.dart';
import '../crypto/peer_key_registry.dart';
import '../data_structures/blockstore.dart';
import '../di/service_container.dart';
import '../ipfs_node/auto_nat_handler.dart';
import '../ipfs_node/bootstrap_handler.dart';
import '../ipfs_node/content_routing_handler.dart';
import '../ipfs_node/datastore_handler.dart';
import '../ipfs_node/dns_link_handler.dart';
import '../ipfs_node/ipfs_node.dart';
import '../ipfs_node/ipld_handler.dart';
import '../ipfs_node/lifecycle_manager.dart';
import '../ipfs_node/mdns_handler.dart';
import '../ipfs_node/network_handler.dart';
import '../ipfs_node/pubsub_handler.dart';
import '../lifecycle/mobile_lifecycle_adapter.dart';
import '../lifecycle/mobile_lifecycle_coordinator.dart';
import '../metrics/metrics_collector.dart';
import '../peering/peering_service.dart';
import '../security/denylist_service.dart';
import '../security/security_manager.dart';
import '../storage/datastore.dart';
import '../storage/flat_file_datastore.dart';
import '../storage/memory_datastore.dart';

/// Builder for constructing an [IPFSNode] with customized configuration.
class IPFSNodeBuilder {
  /// Creates a builder with the specified [config].
  IPFSNodeBuilder(this._config) : _container = ServiceContainer();

  final IPFSConfig _config;
  final ServiceContainer _container;

  /// The node-scoped service container this builder populates.
  ///
  /// Registrations made here are visible only to the node built by this
  /// builder — each node gets its own container, so services never leak
  /// between nodes. Exposed so callers can register additional or substitute
  /// services (e.g. test stubs) before [build] wires them into the node, or
  /// afterwards for services the node resolves lazily.
  ServiceContainer get container => _container;

  final Logger _logger = Logger('IPFSNodeBuilder');
  MobileLifecycleAdapter? _mobileLifecycleAdapter;

  /// Configures an optional [MobileLifecycleAdapter] for mobile battery & lifecycle management.
  IPFSNodeBuilder withMobileLifecycle(MobileLifecycleAdapter adapter) {
    _mobileLifecycleAdapter = adapter;
    return this;
  }

  /// Builds and initializes an [IPFSNode].
  Future<IPFSNode> build() async {
    Logger.setGlobalLevel(_config.logLevel);
    _logger.info('Building IPFS Node...');

    try {
      await _registerCoreServices();
      await _registerNetworkServices();
      await _initializeServices();

      final node = IPFSNode.fromContainer(_container);
      await _registerServerLifecycleServices(node);
      await _registerMobileLifecycleServices(node);
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

    final securityManager = SecurityManager(
      _config.security,
      metrics,
      keystorePath: _config.keystorePath,
    );
    _container.registerSingleton(securityManager);
    lifecycleManager.register(securityManager);

    // Persist the datastore under the configured path so pins and blocks
    // survive restarts. Web targets keep an in-memory store (the platform
    // filesystem API is unavailable there).
    final Datastore datastore = getPlatform().isWeb
        ? MemoryDatastore()
        : FlatFileDatastore(_config.datastorePath);
    final datastoreHandler = DatastoreHandler(datastore);
    _container.registerSingleton(datastoreHandler);
    lifecycleManager.register(datastoreHandler);

    final blockStore = BlockStore(path: _config.blockStorePath);
    _container.registerSingleton(blockStore);
    metrics.registerBlockStore(blockStore);

    final ipldHandler = IPLDHandler(_config, blockStore);
    _container.registerSingleton(ipldHandler);
    lifecycleManager.register(ipldHandler);
  }

  Future<void> _registerNetworkServices() async {
    if (_config.offline) return;

    final networkHandler = NetworkHandler(_config);
    _container.registerSingleton(networkHandler);
    await networkHandler.initialize();

    final mdnsHandler = MDNSHandler(_config);
    _container.registerSingleton(mdnsHandler);
    _container.get<LifecycleManager>().register(mdnsHandler);

    final router = networkHandler.router;
    final lifecycleManager = _container.get<LifecycleManager>();

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
        // Persist DHT values (e.g. IPNS records) in the node's datastore
        // directory with the same flat-file engine as the primary store.
        storage: getPlatform().isWeb
            ? MemoryDatastore()
            : FlatFileDatastore(_config.datastorePath),
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

    final keyRegistry = PeerKeyRegistry();
    _container.registerSingleton(keyRegistry);

    // Standard libp2p housekeeping protocols: ping is transport-agnostic;
    // identify requires the libp2p identity material, so it is only wired
    // when the router exposes it.
    final pingHandler = PingHandler(router: router);
    _container.registerSingleton(pingHandler);
    lifecycleManager.register(pingHandler);

    if (router is Libp2pRouter) {
      final publicKeyBytes = router.identityPublicKeyBytes;
      final peerIdBytes = router.peerIdBytes;
      if (publicKeyBytes != null && peerIdBytes != null) {
        final identifyHandler = IdentifyHandler(
          router: router,
          publicKeyBytes: publicKeyBytes,
          peerIdBytes: peerIdBytes,
          keyRegistry: keyRegistry,
        );
        _container.registerSingleton(identifyHandler);
        lifecycleManager.register(identifyHandler);

        final identifyPushHandler = IdentifyPushHandler(
          router: router,
          identifyHandler: identifyHandler,
        );
        _container.registerSingleton(identifyPushHandler);
        lifecycleManager.register(identifyPushHandler);
      }
    }

    if (_config.enablePubSub) {
      // Derive the PubSub signing key from the node's identity seed so
      // published messages carry an Ed25519 signature bound to this peer ID.
      SimpleKeyPair? pubsubKeyPair;
      final identitySeed = router is Libp2pRouter ? router.identitySeed : null;
      if (identitySeed != null) {
        pubsubKeyPair = await Ed25519Signer().keyPairFromSeed(identitySeed);
      }

      final pubSubHandler = PubSubHandler(
        router,
        networkHandler.peerID,
        keyPair: pubsubKeyPair,
        keyRegistry: keyRegistry,
      );
      _container.registerSingleton(pubSubHandler);
      lifecycleManager.register(pubSubHandler);
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
    _container.get<LifecycleManager>().register(
      _container.get<BootstrapHandler>(),
    );
  }

  Future<void> _initializeServices() async {
    if (_config.offline) return;

    final networkHandler = _container.get<NetworkHandler>();
    final router = networkHandler.router;

    if (_config.enableContentRouting) {
      final contentRoutingHandler = ContentRoutingHandler(
        _config,
        networkHandler,
        // Share the node's DHT client: a second DHTClient would re-register
        // the kad protocol handlers on the same router and shadow the
        // DHTHandler's client, silently dropping inbound DHT traffic.
        dhtClient: _container.isRegistered<DHTHandler>()
            ? _container.get<DHTHandler>().dhtClient
            : null,
      );
      _container.registerSingleton(contentRoutingHandler);
      _container.get<LifecycleManager>().register(contentRoutingHandler);
    }

    if (_config.enableDNSLinkResolution) {
      final dnsLinkHandler = DNSLinkHandler(_config);
      _container.registerSingleton(dnsLinkHandler);
      _container.get<LifecycleManager>().register(dnsLinkHandler);
    }

    if (_config.enableGraphsync) {
      final graphsyncHandler = GraphsyncHandler(
        _config,
        router,
        _container.get<BitswapHandler>(),
        _container.get<IPLDHandler>(),
        _container.get<BlockStore>(),
      );
      _container.registerSingleton(graphsyncHandler);
      _container.get<LifecycleManager>().register(graphsyncHandler);
    }
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
      _container.get<IPLDHandler>().ipnsResolver = (name) =>
          ipnsHandler.resolve(name);
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
        apiKey: _config.rpcApiKey,
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
        gatewayConfig: _config.gateway,
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

  Future<void> _registerMobileLifecycleServices(IPFSNode node) async {
    final adapter = _mobileLifecycleAdapter;
    if (adapter != null) {
      final coordinator = MobileLifecycleCoordinator(
        adapter: adapter,
        reprovider: node.reprovider,
        networkManager: node.networkManager,
        blockStore: node.blockStore,
      );
      _container.registerSingleton(coordinator);
      _container.get<LifecycleManager>().register(coordinator);
    }
  }
}
