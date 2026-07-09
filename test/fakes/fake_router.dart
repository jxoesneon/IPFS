import 'dart:async';
import 'dart:typed_data';

import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_routing_table_interface.dart'
    show DHTRoutingTable;

/// A no-op [RouterInterface] fake for tests that only need to stub the router
/// getter on a Mockito-generated [NetworkHandler] mock.
class FakeRouter implements RouterInterface {
  @override
  String get peerID => 'QmFakeRouter';

  @override
  bool get hasStarted => true;

  @override
  bool get isInitialized => true;

  @override
  Set<String> get connectedPeers => const {};

  @override
  Stream<ConnectionEvent> get connectionEvents =>
      const Stream<ConnectionEvent>.empty();

  @override
  Stream<MessageEvent> get messageEvents => const Stream<MessageEvent>.empty();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> connect(String multiaddress) async {}

  @override
  Future<void> disconnect(String peerIdOrMultiaddress) async {}

  @override
  List<String> get listeningAddresses => [];

  @override
  List<String> listConnectedPeers() => [];

  @override
  bool isConnectedPeer(String peerIdStr) => false;

  @override
  Future<void> sendMessage(
    String peerIdStr,
    Uint8List message, {
    String? protocolId,
  }) async {}

  @override
  Future<Uint8List?> sendRequest(
    String peerId,
    String protocolId,
    Uint8List request,
  ) async => null;

  @override
  Future<Uint8List> sendMessageWithResponse(
    String peerId,
    Uint8List message, {
    String? protocolId,
    Duration? timeout,
  }) async => Uint8List(0);

  @override
  Stream<Uint8List> receiveMessages(String peerId) =>
      const Stream<Uint8List>.empty();

  @override
  void registerProtocolHandler(
    String protocolId,
    void Function(NetworkPacket) handler,
  ) {}

  @override
  void removeMessageHandler(String protocolId) {}

  @override
  void unregisterProtocolHandler(String protocolId) {}

  @override
  void registerProtocol(String protocolId) {}

  @override
  Future<void> broadcastMessage(String protocolId, Uint8List message) async {}

  @override
  void emitEvent(String topic, Uint8List data) {}

  @override
  void onEvent(String topic, void Function(dynamic) handler) {}

  @override
  void offEvent(String topic, void Function(dynamic) handler) {}

  @override
  Object? parseMultiaddr(String multiaddr) => null;

  @override
  List<String> resolvePeerId(String peerIdStr) => [];

  @override
  void registerRelayedConnection(String targetPeerId, String relayAddr) {}

  @override
  DHTRoutingTable? get dhtRoutingTable => null;
}
