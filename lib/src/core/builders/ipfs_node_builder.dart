// src/core/builders/ipfs_node_builder.dart
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/di/service_container.dart';
import 'package:dart_ipfs/src/core/ipfs_node/datastore_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipld_handler.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/security/security_manager.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/mdns_handler.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/pubsub_handler.dart';
import 'package:dart_ipfs/src/protocols/bitswap/bitswap_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/bootstrap_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/content_routing_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/dns_link_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/graphsync_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/auto_nat_handler.dart';
import 'package:dart_ipfs/src/protocols/ipns/ipns_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node_network_events.dart';

class IPFSNodeBuilder {
  final ServiceContainer _container;
  final IPFSConfig _config;

  IPFSNodeBuilder(this._config) : _container = ServiceContainer();

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
        SecurityManager(_config.security, _container.get<MetricsCollector>()));
  }

  Future<void> _initializeStorageLayer() async {
    _container.registerSingleton(BlockStore(path: _config.blockStorePath));
    _container.registerSingleton(DatastoreHandler(_config));
    _container
        .registerSingleton(IPLDHandler(_container.get<BlockStore>(), _config));
  }

  Future<void> _initializeNetworkLayer() async {
    // First register NetworkHandler
    _container.registerSingleton(NetworkHandler(_config));

    // Get the router from NetworkHandler for other handlers
    final networkHandler = _container.get<NetworkHandler>();

    _container.registerSingleton(MDNSHandler(_config));

    _container.registerSingleton(
        DHTHandler(_config, networkHandler.p2pRouter, networkHandler));

    // Create IpfsNodeNetworkEvents instance
    final networkEvents = IpfsNodeNetworkEvents(
        networkHandler.circuitRelayClient, networkHandler.p2pRouter);

    _container.registerSingleton(PubSubHandler(
      networkHandler.p2pRouter,
      networkHandler.peerID,
      networkEvents, // Pass the IpfsNodeNetworkEvents instance
    ));

    _container.registerSingleton(BitswapHandler(
        _config, _container.get<BlockStore>(), networkHandler.p2pRouter));

    _container.registerSingleton(BootstrapHandler(_config));
  }

  Future<void> _initializeServices() async {
    final networkHandler = _container.get<NetworkHandler>();

    _container
        .registerSingleton(ContentRoutingHandler(_config, networkHandler));
    _container.registerSingleton(DNSLinkHandler(_config));
    _container.registerSingleton(
        GraphsyncHandler(_config, _container.get<BlockStore>()));
    _container.registerSingleton(AutoNATHandler(_config, networkHandler));
    _container.registerSingleton(IPNSHandler(
      _config,
      _container.get<SecurityManager>(),
      _container.get<DHTHandler>(),
    ));
  }
}
