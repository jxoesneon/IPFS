// src/core/builders/ipfs_node_builder.dart
import 'dart:async';
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
import 'package:dart_ipfs/src/core/ipfs_node/lifecycle_manager.dart';
import 'package:dart_ipfs/src/core/ipfs_node/mdns_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/pubsub_handler.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/security/security_manager.dart';
import 'package:dart_ipfs/src/core/storage/memory_datastore.dart';
import 'package:dart_ipfs/src/protocols/bitswap/bitswap_handler.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_handler.dart';
import 'package:dart_ipfs/src/protocols/graphsync/graphsync_handler.dart';
import 'package:dart_ipfs/src/protocols/ipns/ipns_handler.dart';
import 'package:dart_ipfs/src/services/gateway/gateway_server.dart';
import 'package:dart_ipfs/src/services/rpc/rpc_server.dart';
import 'package:dart_ipfs/src/utils/logger.dart';

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
    _container.registerSingleton(LifecycleManager());

    final metrics = MetricsCollector(_config);
    _container.registerSingleton(metrics);

    _container.registerSingleton(SecurityManager(_config.security, metrics));

    final datastore = MemoryDatastore();
    final datastoreHandler = DatastoreHandler(datastore);
    _container.registerSingleton(datastoreHandler);

    final blockStore = BlockStore(path: _config.blockStorePath);
    _container.registerSingleton(blockStore);

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
      _container.registerSingleton(DHTHandler(_config, router, networkHandler));
    }

    // Create IpfsNodeNetworkEvents instance
    final networkEvents = IpfsNodeNetworkEvents(router);

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
  }

  Future<void> _registerServerLifecycleServices(IPFSNode node) async {
    final lifecycleManager = _container.get<LifecycleManager>();

    if (_config.enableRPC) {
      final rpcServer = RPCServer(
        node: node,
        address: 'localhost',
        port: 5001,
      );
      _container.registerSingleton(rpcServer);
      lifecycleManager.register(rpcServer);
    }

    if (_config.gateway.enabled) {
      final gatewayServer = GatewayServer(
        blockStore: _container.get<BlockStore>(),
        node: node,
        address: _config.gateway.address,
        port: _config.gateway.port,
      );
      _container.registerSingleton(gatewayServer);
      lifecycleManager.register(gatewayServer);
    }
  }
}
