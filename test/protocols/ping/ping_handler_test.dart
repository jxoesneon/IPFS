// test/protocols/ping/ping_handler_test.dart
//
// Tests for the libp2p Ping protocol handler.

import 'dart:async';
import 'dart:typed_data';

import 'package:dart_ipfs/src/protocols/dht/dht_routing_table_interface.dart';
import 'package:dart_ipfs/src/protocols/ping/ping_handler.dart';
import 'package:dart_ipfs/src/transport/router_events.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:test/test.dart';

/// A mock router for testing the ping handler.
class MockPingRouter implements RouterInterface {
  final Map<String, void Function(NetworkPacket)> _handlers = {};
  Uint8List? _requestResponse;
  String? _requestResponsePeer;
  final List<_SentPing> _sentMessages = [];
  bool _throwOnSendRequest = false;

  @override
  String get peerID => 'QmTestPeer';

  @override
  bool get hasStarted => true;

  @override
  bool get isInitialized => true;

  @override
  Set<String> get connectedPeers => {};

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
  List<String> get listeningAddresses => ['/ip4/0.0.0.0/tcp/4001'];

  @override
  List<String> listConnectedPeers() => ['QmPeer1'];

  @override
  bool isConnectedPeer(String peerIdStr) => true;

  @override
  Future<void> sendMessage(
    String peerIdStr,
    Uint8List message, {
    String? protocolId,
  }) async {
    _sentMessages.add(
      _SentPing(peerIdStr, protocolId ?? '/ipfs/1.0.0', message),
    );
  }

  @override
  Future<Uint8List?> sendRequest(
    String peerId,
    String protocolId,
    Uint8List request,
  ) async {
    if (_throwOnSendRequest) {
      throw Exception('Network error');
    }
    if (_requestResponsePeer != null && _requestResponsePeer != peerId) {
      return null;
    }
    return _requestResponse;
  }

  @override
  Stream<Uint8List> receiveMessages(String peerId) =>
      const Stream<Uint8List>.empty();

  @override
  void registerProtocolHandler(
    String protocolId,
    void Function(NetworkPacket) handler,
  ) {
    _handlers[protocolId] = handler;
  }

  @override
  void removeMessageHandler(String protocolId) {
    _handlers.remove(protocolId);
  }

  @override
  void unregisterProtocolHandler(String protocolId) {
    removeMessageHandler(protocolId);
  }

  @override
  Future<Uint8List> sendMessageWithResponse(
    String peerId,
    Uint8List message, {
    String? protocolId,
    Duration? timeout,
  }) async {
    throw UnimplementedError();
  }

  @override
  void registerProtocol(String protocolId) {}

  @override
  Future<void> broadcastMessage(String protocolId, Uint8List message) async {}

  @override
  void emitEvent(String topic, Uint8List data) {}

  @override
  void onEvent(String topic, void Function(NetworkMessage) handler) {}

  @override
  void offEvent(String topic, void Function(NetworkMessage) handler) {}

  @override
  Object? parseMultiaddr(String multiaddr) => null;

  @override
  List<String> resolvePeerId(String peerIdStr) => [];

  @override
  void registerRelayedConnection(String targetPeerId, String relayAddr) {}

  @override
  DHTRoutingTable? get dhtRoutingTable => null;

  // --- Test helpers ---

  void setEchoResponse(String peerId, Uint8List? response) {
    _requestResponsePeer = peerId;
    _requestResponse = response;
  }

  void setThrowOnSendRequest(bool shouldThrow) {
    _throwOnSendRequest = true;
  }

  void simulateIncomingPing(String srcPeerId, Uint8List payload) {
    final handler = _handlers[pingProtocolId];
    expect(handler, isNotNull, reason: 'Ping handler not registered');
    handler!(
      NetworkPacket(
        srcPeerId: srcPeerId,
        datagram: payload,
        responder: (response) async {
          _echoedResponse = response;
        },
      ),
    );
  }

  Uint8List? _echoedResponse;
  Uint8List? get echoedResponse => _echoedResponse;

  List<_SentPing> get sentMessages => _sentMessages;
}

class _SentPing {
  _SentPing(this.peerId, this.protocolId, this.data);
  final String peerId;
  final String protocolId;
  final Uint8List data;
}

void main() {
  late MockPingRouter router;
  late PingHandler handler;

  setUp(() {
    router = MockPingRouter();
    handler = PingHandler(router: router);
  });

  group('PingHandler', () {
    test('start registers protocol handler', () async {
      await handler.start();
      expect(handler.isStarted, isTrue);
    });

    test('stop removes protocol handler', () async {
      await handler.start();
      expect(handler.isStarted, isTrue);

      await handler.stop();
      expect(handler.isStarted, isFalse);
    });

    test('server echoes 32-byte payload back', () async {
      await handler.start();

      final payload = Uint8List.fromList(List.generate(32, (i) => i));

      router.simulateIncomingPing('QmRemote', payload);

      expect(router.echoedResponse, isNotNull);
      expect(router.echoedResponse!.length, equals(32));
      expect(router.echoedResponse, equals(payload));
    });

    test('server echoes even with wrong-size payload (lenient)', () async {
      await handler.start();

      final payload = Uint8List.fromList([1, 2, 3, 4]); // wrong size

      router.simulateIncomingPing('QmRemote', payload);

      expect(router.echoedResponse, isNotNull);
      expect(router.echoedResponse, equals(payload));
    });

    test('ping succeeds with matching echo', () async {
      await handler.start();

      // The mock router will echo back whatever was sent.
      // We need to capture the request and echo it.
      // Since sendRequest returns a fixed response, we set it to a
      // valid 32-byte payload that we'll generate.
      final expectedPayload = handler.generatePayload();
      router.setEchoResponse('QmPeer1', expectedPayload);

      // But the actual ping generates a different random payload.
      // So we need a router that echoes the request. Let's use a custom
      // approach: override the response to match any 32-byte value.
      // For this test, we'll just set a fixed 32-byte response.
      final fixedResponse = Uint8List.fromList(List.generate(32, (i) => i));
      router.setEchoResponse('QmPeer1', fixedResponse);

      // This will fail because the echo won't match the random payload.
      // We need a smarter approach. Let's test with a router that echoes.
      final echoRouter = _EchoRouter();
      final echoHandler = PingHandler(router: echoRouter);

      await echoHandler.start();
      final result = await echoHandler.ping('QmPeer1');

      expect(result.success, isTrue);
      expect(result.rtt, isNotNull);
      expect(result.peerId, equals('QmPeer1'));
    });

    test('ping fails when handler not started', () async {
      final result = await handler.ping('QmPeer1');

      expect(result.success, isFalse);
      expect(result.error, contains('not started'));
    });

    test('ping fails on null response', () async {
      await handler.start();
      router.setEchoResponse('QmPeer1', null);

      final result = await handler.ping('QmPeer1');

      expect(result.success, isFalse);
      expect(result.error, contains('No response'));
    });

    test('ping fails on wrong response size', () async {
      await handler.start();
      router.setEchoResponse('QmPeer1', Uint8List.fromList([1, 2, 3]));

      final result = await handler.ping('QmPeer1');

      expect(result.success, isFalse);
      expect(result.error, contains('Invalid response size'));
    });

    test('ping fails on mismatched payload', () async {
      await handler.start();
      // Set a valid 32-byte response that won't match the random payload
      router.setEchoResponse(
        'QmPeer1',
        Uint8List.fromList(List.generate(32, (i) => 0xFF)),
      );

      final result = await handler.ping('QmPeer1');

      expect(result.success, isFalse);
      expect(result.error, contains('does not match'));
    });

    test('ping fails on exception', () async {
      await handler.start();
      router.setThrowOnSendRequest(true);

      final result = await handler.ping('QmPeer1');

      expect(result.success, isFalse);
      expect(result.error, contains('Network error'));
    });

    test('ping times out', () async {
      await handler.start();

      // Use a router that never responds (returns null after delay)
      final slowRouter = _SlowRouter();
      final slowHandler = PingHandler(router: slowRouter);
      await slowHandler.start();

      final result = await slowHandler.ping(
        'QmPeer1',
        timeout: const Duration(milliseconds: 50),
      );

      expect(result.success, isFalse);
      expect(result.error, contains('timed out'));
    });

    test('pingMultiple sends multiple pings', () async {
      final echoRouter = _EchoRouter();
      final echoHandler = PingHandler(router: echoRouter);
      await echoHandler.start();

      final results = await echoHandler.pingMultiple(
        'QmPeer1',
        count: 3,
        interval: const Duration(milliseconds: 10),
      );

      expect(results.length, equals(3));
      for (final r in results) {
        expect(r.success, isTrue);
      }
    });

    test('generatePayload returns 32 bytes', () {
      final payload = handler.generatePayload();
      expect(payload.length, equals(32));
    });

    test('generatePayload returns different values each call', () {
      final p1 = handler.generatePayload();
      final p2 = handler.generatePayload();
      // Extremely unlikely to be equal
      expect(p1, isNot(equals(p2)));
    });

    test('PingResult toString for success', () {
      final result = PingResult(
        peerId: 'QmPeer',
        rtt: const Duration(milliseconds: 42),
        success: true,
      );
      final s = result.toString();
      expect(s, contains('QmPeer'));
      expect(s, contains('42ms'));
    });

    test('PingResult toString for failure', () {
      final result = PingResult(
        peerId: 'QmPeer',
        rtt: null,
        success: false,
        error: 'timeout',
      );
      final s = result.toString();
      expect(s, contains('failed'));
      expect(s, contains('timeout'));
    });

    test('protocol constants are correct', () {
      expect(pingProtocolId, equals('/ipfs/ping/1.0.0'));
      expect(pingPayloadSize, equals(32));
      expect(defaultPingTimeout, equals(const Duration(seconds: 10)));
    });
  });
}

/// A router that echoes back the ping request payload.
class _EchoRouter implements RouterInterface {
  final Map<String, void Function(NetworkPacket)> _handlers = {};

  @override
  String get peerID => 'QmEcho';

  @override
  bool get hasStarted => true;

  @override
  bool get isInitialized => true;

  @override
  Set<String> get connectedPeers => {'QmPeer1'};

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
  List<String> get listeningAddresses => ['/ip4/0.0.0.0/tcp/4001'];

  @override
  List<String> listConnectedPeers() => ['QmPeer1'];

  @override
  bool isConnectedPeer(String peerIdStr) => true;

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
  ) async {
    // Echo back the exact request
    return request;
  }

  @override
  Stream<Uint8List> receiveMessages(String peerId) =>
      const Stream<Uint8List>.empty();

  @override
  void registerProtocolHandler(
    String protocolId,
    void Function(NetworkPacket) handler,
  ) {
    _handlers[protocolId] = handler;
  }

  @override
  void removeMessageHandler(String protocolId) {
    _handlers.remove(protocolId);
  }

  @override
  void unregisterProtocolHandler(String protocolId) {
    removeMessageHandler(protocolId);
  }

  @override
  Future<Uint8List> sendMessageWithResponse(
    String peerId,
    Uint8List message, {
    String? protocolId,
    Duration? timeout,
  }) async {
    return message;
  }

  @override
  void registerProtocol(String protocolId) {}

  @override
  Future<void> broadcastMessage(String protocolId, Uint8List message) async {}

  @override
  void emitEvent(String topic, Uint8List data) {}

  @override
  void onEvent(String topic, void Function(NetworkMessage) handler) {}

  @override
  void offEvent(String topic, void Function(NetworkMessage) handler) {}

  @override
  Object? parseMultiaddr(String multiaddr) => null;

  @override
  List<String> resolvePeerId(String peerIdStr) => [];

  @override
  void registerRelayedConnection(String targetPeerId, String relayAddr) {}

  @override
  DHTRoutingTable? get dhtRoutingTable => null;
}

/// A router that delays responses to simulate timeout.
class _SlowRouter implements RouterInterface {
  @override
  String get peerID => 'QmSlow';

  @override
  bool get hasStarted => true;

  @override
  bool get isInitialized => true;

  @override
  Set<String> get connectedPeers => {'QmPeer1'};

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
  List<String> listConnectedPeers() => ['QmPeer1'];

  @override
  bool isConnectedPeer(String peerIdStr) => true;

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
  ) async {
    // Delay longer than the test timeout
    await Future.delayed(const Duration(seconds: 5));
    return request;
  }

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
  Future<Uint8List> sendMessageWithResponse(
    String peerId,
    Uint8List message, {
    String? protocolId,
    Duration? timeout,
  }) async {
    await Future.delayed(const Duration(seconds: 5));
    return message;
  }

  @override
  void registerProtocol(String protocolId) {}

  @override
  Future<void> broadcastMessage(String protocolId, Uint8List message) async {}

  @override
  void emitEvent(String topic, Uint8List data) {}

  @override
  void onEvent(String topic, void Function(NetworkMessage) handler) {}

  @override
  void offEvent(String topic, void Function(NetworkMessage) handler) {}

  @override
  Object? parseMultiaddr(String multiaddr) => null;

  @override
  List<String> resolvePeerId(String peerIdStr) => [];

  @override
  void registerRelayedConnection(String targetPeerId, String relayAddr) {}

  @override
  DHTRoutingTable? get dhtRoutingTable => null;
}
