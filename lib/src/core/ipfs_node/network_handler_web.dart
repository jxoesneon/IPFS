import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../../proto/generated/dht/ipfs_node_network_events.pb.dart';
import '../../transport/circuit_relay_client.dart';
import '../../transport/libp2p_router.dart';
import '../../transport/router_interface.dart';
import '../config/ipfs_config.dart';
import 'ipfs_node.dart';

/// Web implementation of [NetworkHandler].
///
/// Unlike the old placeholder version, this handler delegates to the
/// configured [RouterInterface] (a [Libp2pRouter] by default), which on the
/// web platform dials peers over the browser transports it supports
/// (WebSocket, WebRTC, WebTransport).
///
/// Capabilities that are genuinely impossible in a browser — inbound
/// listening sockets, AutoNAT dialback, and circuit relay — are reported
/// honestly: they return negative results or `null` instead of pretending
/// to work.
class NetworkHandler {
  /// Creates a NetworkHandler for web platform.
  NetworkHandler(this._config, {RouterInterface? router})
    : _router =
          router ?? Libp2pRouter(_config, seed: _config.libp2pIdentitySeed),
      _networkEventController = StreamController<NetworkEvent>.broadcast();

  /// Circuit relay is not available on the web platform, so this is always
  /// `null`. See [CircuitRelayClient] for the platform limitation.
  final CircuitRelayClient? _circuitRelayClient = null;
  final RouterInterface _router;

  IPFSNode? _ipfsNode;

  /// The IPFS node reference.
  IPFSNode get ipfsNode => _ipfsNode!;

  final StreamController<NetworkEvent> _networkEventController;
  final IPFSConfig _config;

  /// Starts the router, activating browser-capable transports
  /// (WebSocket, WebRTC, WebTransport).
  Future<void> start() => _router.start();

  /// Stops the router and disconnects all peers.
  Future<void> stop() => _router.stop();

  /// Stream of network events.
  Stream<NetworkEvent> get networkEvents => _networkEventController.stream;

  /// Connects to a peer using its multiaddress.
  Future<void> connectToPeer(String multiaddress) =>
      _router.connect(multiaddress);

  /// Disconnects from a peer using its multiaddress.
  Future<void> disconnectFromPeer(String multiaddress) =>
      _router.disconnect(multiaddress);

  /// Lists all connected peers.
  Future<List<String>> listConnectedPeers() =>
      Future.value(_router.listConnectedPeers());

  /// Sends a UTF-8 encoded [message] to a specific peer.
  Future<void> sendMessage(String peerId, String message) =>
      _router.sendMessage(peerId, utf8.encode(message));

  /// Receives UTF-8 messages from a specific peer.
  Stream<String> receiveMessages(String peerId) =>
      _router.receiveMessages(peerId).map(utf8.decode);

  /// Sets the IPFS node reference.
  void setIpfsNode(IPFSNode node) {
    _ipfsNode = node;
  }

  /// Sends a request to a peer and waits for a response.
  ///
  /// Returns the response bytes, or `null` on timeout/failure.
  Future<Uint8List?> sendRequest(
    String peerId,
    String protocolId,
    Uint8List request,
  ) => _router.sendRequest(peerId, protocolId, request);

  /// Returns the router used by this handler.
  RouterInterface get router => _router;

  /// Returns the circuit relay client.
  ///
  /// Always `null` on the web platform: browsers cannot maintain the
  /// relayed connections required by Circuit Relay v2.
  CircuitRelayClient? get circuitRelayClient => _circuitRelayClient;

  /// Returns the configuration.
  IPFSConfig get config => _config;

  /// Returns the peer ID.
  String get peerID => _router.peerID;

  /// Whether a direct connection to [peerAddress] is possible.
  ///
  /// Always `false` on the web platform: browsers cannot accept inbound
  /// connections, so every peer is reached through a dial-out transport
  /// or a relay rather than a direct inbound path.
  Future<bool> canConnectDirectly(String peerAddress) async => false;

  /// Tests connectivity from [sourcePort].
  ///
  /// Always returns an empty string on the web platform: browsers cannot
  /// bind listening sockets, so there is no observable external address
  /// or port to report.
  Future<String> testConnection({required int sourcePort}) async => '';

  /// Tests AutoNAT dialback.
  ///
  /// Always `false` on the web platform: AutoNAT dialback requires the
  /// peer to dial us back on a listening socket, which browsers cannot
  /// provide.
  Future<bool> testDialback() async => false;

  /// Initializes the router.
  Future<void> initialize() => _router.initialize();
}
