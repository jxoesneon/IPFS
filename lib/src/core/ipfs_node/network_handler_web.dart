import 'dart:async';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/proto/generated/dht/ipfs_node_network_events.pb.dart';
import 'package:dart_ipfs/src/transport/circuit_relay_client.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';

/// Web stub for NetworkHandler.
///
/// This implementation provides placeholder methods for web platform
/// where full P2P networking is not available.
class NetworkHandler {
  /// Creates a NetworkHandler for web platform.
  NetworkHandler(this._config, {RouterInterface? router})
    : _router = router,
      _networkEventController = StreamController<NetworkEvent>.broadcast();

  final CircuitRelayClient? _circuitRelayClient = null;
  final RouterInterface? _router;

  /// The IPFS node reference.
  late final IPFSNode ipfsNode;

  final StreamController<NetworkEvent> _networkEventController;
  final IPFSConfig _config;

  /// Starts the network handler (stub).
  Future<void> start() async {}

  /// Stops the network handler (stub).
  Future<void> stop() async {}

  /// Stream of network events.
  Stream<NetworkEvent> get networkEvents => _networkEventController.stream;

  /// Connects to a peer (stub).
  Future<void> connectToPeer(String multiaddress) async {}

  /// Disconnects from a peer (stub).
  Future<void> disconnectFromPeer(String multiaddress) async {}

  /// Lists connected peers (stub).
  Future<List<String>> listConnectedPeers() async => [];

  /// Sends a message to a peer (stub).
  Future<void> sendMessage(String peerId, String message) async {}

  /// Receives messages from a peer (stub).
  Stream<String> receiveMessages(String peerId) async* {
    yield* const Stream.empty();
  }

  /// Sets the IPFS node reference.
  void setIpfsNode(IPFSNode node) {
    ipfsNode = node;
  }

  /// Sends a request to a peer (stub).
  Future<Uint8List> sendRequest(
    dynamic peer,
    String protocolId,
    Uint8List request,
  ) async {
    throw UnimplementedError();
  }

  /// Returns the router (stub).
  RouterInterface? get router => _router;

  // Legacy stub for compatibility if needed, but should be removed eventually
  // RouterInterface? get p2pRouter => _router;

  /// Returns the circuit relay client.
  CircuitRelayClient? get circuitRelayClient => _circuitRelayClient;

  /// Returns the configuration.
  IPFSConfig get config => _config;

  /// Returns the peer ID (stub).
  String get peerID => 'web_node';

  /// Checks if direct connection is possible (stub).
  Future<bool> canConnectDirectly(String peerAddress) async => false;

  /// Tests connection (stub).
  Future<String> testConnection({required int sourcePort}) async => '';

  /// Tests dialback (stub).
  Future<bool> testDialback() async => false;

  /// Initializes the handler (stub).
  Future<void> initialize() async {}
}
