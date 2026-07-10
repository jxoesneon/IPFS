import 'dart:async';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/config/network_config.dart';
import 'package:dart_ipfs/src/proto/generated/circuit_relay.pb.dart' as pb;
import 'package:dart_ipfs/src/protocols/dht/dht_routing_table_interface.dart'
    show DHTRoutingTable;
import 'package:dart_ipfs/src/transport/circuit_relay_client.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:test/test.dart';

class _MockRouter implements RouterInterface {
  final Map<String, void Function(NetworkPacket)> _handlers = {};
  final List<Uint8List> sentMessages = [];
  final List<String> sentPeers = [];
  final List<String> connectedMultiaddrs = [];
  final List<String> registeredRelayedPeers = [];
  final Set<String> _connectedPeers = {'relay-peer'};
  final StreamController<ConnectionEvent> _connectionEventsController =
      StreamController<ConnectionEvent>.broadcast();

  pb.Status _connectStatus = pb.Status.OK;

  @override
  String get peerID => 'local-peer';

  @override
  bool get hasStarted => true;

  @override
  bool get isInitialized => true;

  @override
  Set<String> get connectedPeers => _connectedPeers;

  @override
  Stream<ConnectionEvent> get connectionEvents =>
      _connectionEventsController.stream;

  @override
  Stream<MessageEvent> get messageEvents => const Stream.empty();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> connect(String multiaddress) async {
    connectedMultiaddrs.add(multiaddress);
    final peerId = _extractPeerId(multiaddress);
    if (peerId != null) {
      _connectedPeers.add(peerId);
    }
  }

  @override
  Future<void> disconnect(String peerIdOrMultiaddress) async {
    final peerId = peerIdOrMultiaddress.contains('/p2p/')
        ? _extractPeerId(peerIdOrMultiaddress)
        : peerIdOrMultiaddress;
    if (peerId != null) {
      _connectedPeers.remove(peerId);
    }
  }

  @override
  List<String> get listeningAddresses => [];

  @override
  List<String> listConnectedPeers() => _connectedPeers.toList();

  @override
  bool isConnectedPeer(String peerIdStr) => _connectedPeers.contains(peerIdStr);

  @override
  Future<void> sendMessage(
    String peerIdStr,
    Uint8List message, {
    String? protocolId,
  }) async {
    sentPeers.add(peerIdStr);
    sentMessages.add(message);

    if (_handlers.containsKey(protocolId)) {
      const hopProtocolId = '/libp2p/circuit/relay/0.2.0/hop';
      if (protocolId != hopProtocolId) {
        return;
      }
      final msg = pb.HopMessage.fromBuffer(message);
      if (msg.type == pb.HopMessage_Type.RESERVE) {
        final response = pb.HopMessage()
          ..type = pb.HopMessage_Type.STATUS
          ..status = pb.Status.OK
          ..reservation = (pb.Reservation()
            ..expire = fixnum.Int64(
              DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
            )
            ..limitData = fixnum.Int64(1024)
            ..limitDuration = fixnum.Int64(3600));

        final packet = NetworkPacket(
          srcPeerId: peerIdStr,
          datagram: response.writeToBuffer(),
        );
        unawaited(Future.microtask(() => _handlers[protocolId]!(packet)));
      } else if (msg.type == pb.HopMessage_Type.CONNECT) {
        final response = pb.HopMessage()
          ..type = pb.HopMessage_Type.STATUS
          ..status = _connectStatus;
        final packet = NetworkPacket(
          srcPeerId: peerIdStr,
          datagram: response.writeToBuffer(),
        );
        unawaited(Future.microtask(() => _handlers[protocolId]!(packet)));
      }
    }
  }

  @override
  Future<Uint8List?> sendRequest(
    String peerId,
    String protocolId,
    Uint8List request,
  ) async => null;

  @override
  Stream<Uint8List> receiveMessages(String peerId) => const Stream.empty();

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
  dynamic parseMultiaddr(String multiaddr) => null;

  @override
  List<String> resolvePeerId(String peerIdStr) => [
    '/ip4/127.0.0.1/tcp/4001/p2p/$peerIdStr',
  ];

  @override
  void registerRelayedConnection(String targetPeerId, String relayAddr) {
    registeredRelayedPeers.add(targetPeerId);
    _connectedPeers.add(targetPeerId);
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
  }) async => Uint8List(0);

  @override
  DHTRoutingTable? get dhtRoutingTable => null;

  void setConnectStatus(pb.Status status) {
    _connectStatus = status;
  }

  void emitPeerDisconnected(String peerId) {
    _connectionEventsController.add(
      ConnectionEvent(peerId: peerId, type: ConnectionEventType.disconnected),
    );
  }

  String? _extractPeerId(String multiaddress) {
    final parts = multiaddress.split('/');
    final p2pIndex = parts.lastIndexOf('p2p');
    if (p2pIndex != -1 && p2pIndex + 1 < parts.length) {
      return parts[p2pIndex + 1];
    }
    return null;
  }

  void deliverStopMessage(String peerId, Uint8List datagram) {
    const stopProtocolId = '/libp2p/circuit/relay/0.2.0/stop';
    final handler = _handlers[stopProtocolId];
    if (handler != null) {
      handler(NetworkPacket(srcPeerId: peerId, datagram: datagram));
    }
  }
}

class _SilentRouter extends _MockRouter {
  @override
  Future<void> sendMessage(
    String peerIdStr,
    Uint8List message, {
    String? protocolId,
  }) async {
    // Swallow messages without responding.
  }
}

void main() {
  const relayAddr = '/ip4/127.0.0.1/tcp/4001/p2p/relay-peer/p2p-circuit';
  const targetPeerId = '12'; // valid base58 string

  group('CircuitRelayConfig', () {
    test('defaults are correct', () {
      const config = CircuitRelayConfig();
      expect(config.enabled, isTrue);
      expect(config.staticRelays, isEmpty);
      expect(config.reservationTimeout.inSeconds, 30);
      expect(config.reservationRefreshInterval.inMinutes, 5);
      expect(config.maxCircuits, 8);
    });

    test('toJson / fromJson round-trip', () {
      const config = CircuitRelayConfig(
        enabled: false,
        staticRelays: ['/ip4/127.0.0.1/tcp/4001/p2p/relay-peer'],
        reservationTimeout: Duration(seconds: 10),
        reservationRefreshInterval: Duration(seconds: 120),
        maxCircuits: 4,
      );
      final json = config.toJson();
      final restored = CircuitRelayConfig.fromJson(json);
      expect(restored.enabled, isFalse);
      expect(restored.staticRelays, ['/ip4/127.0.0.1/tcp/4001/p2p/relay-peer']);
      expect(restored.reservationTimeout.inSeconds, 10);
      expect(restored.reservationRefreshInterval.inSeconds, 120);
      expect(restored.maxCircuits, 4);
    });

    test('NetworkConfig includes circuitRelay', () {
      final config = NetworkConfig(
        circuitRelay: const CircuitRelayConfig(maxCircuits: 4),
      );
      final json = config.toJson();
      expect(json['circuitRelay'], isNotNull);
      expect(json['circuitRelay']['maxCircuits'], 4);
      final restored = NetworkConfig.fromJson(json);
      expect(restored.circuitRelay.maxCircuits, 4);
    });
  });

  group('HopMessage encode/decode', () {
    test('RESERVE round-trips with limit', () {
      final msg = pb.HopMessage()
        ..type = pb.HopMessage_Type.RESERVE
        ..limit = (pb.Limit()
          ..duration = fixnum.Int64(3600)
          ..data = fixnum.Int64(1024));
      final decoded = pb.HopMessage.fromBuffer(msg.writeToBuffer());
      expect(decoded.type, pb.HopMessage_Type.RESERVE);
      expect(decoded.limit.duration.toInt(), 3600);
      expect(decoded.limit.data.toInt(), 1024);
    });

    test('CONNECT round-trips with peer', () {
      final msg = pb.HopMessage()
        ..type = pb.HopMessage_Type.CONNECT
        ..peer = (pb.Peer()..id = [1, 2, 3]);
      final decoded = pb.HopMessage.fromBuffer(msg.writeToBuffer());
      expect(decoded.type, pb.HopMessage_Type.CONNECT);
      expect(decoded.peer.id, [1, 2, 3]);
    });

    test('STATUS round-trips with OK and FAILED', () {
      final ok = pb.HopMessage()
        ..type = pb.HopMessage_Type.STATUS
        ..status = pb.Status.OK;
      final failed = pb.HopMessage()
        ..type = pb.HopMessage_Type.STATUS
        ..status = pb.Status.FAILED;
      expect(pb.HopMessage.fromBuffer(ok.writeToBuffer()).status, pb.Status.OK);
      expect(
        pb.HopMessage.fromBuffer(failed.writeToBuffer()).status,
        pb.Status.FAILED,
      );
    });
  });

  group('Reservation parsing', () {
    test('Reservation expiry is calculated correctly', () {
      final past = Reservation(
        relayPeerId: 'relay-peer',
        expireTime: DateTime.now().subtract(const Duration(hours: 1)),
        limitData: fixnum.Int64(1024),
        limitDuration: fixnum.Int64(3600),
      );
      final future = Reservation(
        relayPeerId: 'relay-peer',
        expireTime: DateTime.now().add(const Duration(hours: 1)),
        limitData: fixnum.Int64(1024),
        limitDuration: fixnum.Int64(3600),
      );
      expect(past.isExpired, isTrue);
      expect(future.isExpired, isFalse);
    });

    test('Reservation carries relayAddr', () {
      final reservation = Reservation(
        relayPeerId: 'relay-peer',
        relayAddr: relayAddr,
        expireTime: DateTime.now().add(const Duration(hours: 1)),
        limitData: fixnum.Int64(1024),
        limitDuration: fixnum.Int64(3600),
      );
      expect(reservation.relayAddr, relayAddr);
    });
  });

  group('CircuitRelayClient reservation', () {
    late _MockRouter router;
    late CircuitRelayClient client;

    setUp(() {
      router = _MockRouter();
      client = CircuitRelayClient(router);
    });

    test('reserve sends RESERVE and parses reservation', () async {
      await client.start();
      final reservation = await client.reserve('relay-peer');
      expect(reservation, isNotNull);
      expect(reservation!.relayPeerId, 'relay-peer');
      expect(reservation.isExpired, isFalse);
      expect(reservation.limitData.toInt(), 1024);
      expect(router.sentPeers, contains('relay-peer'));
    });

    test('reserve returns null when disabled', () async {
      client = CircuitRelayClient(
        router,
        config: const CircuitRelayConfig(enabled: false),
      );
      await client.start();
      final reservation = await client.reserve('relay-peer');
      expect(reservation, isNull);
      expect(router.sentMessages, isEmpty);
    });

    test('activeRelayAddrs returns non-expired reservations', () async {
      await client.start();
      await client.reserve('relay-peer');
      expect(client.activeRelayAddrs, contains('relay-peer'));
    });

    test('reserve timeout returns null', () async {
      final silentRouter = _SilentRouter();
      client = CircuitRelayClient(
        silentRouter,
        config: const CircuitRelayConfig(
          reservationTimeout: Duration(milliseconds: 50),
        ),
      );
      await client.start();
      final reservation = await client.reserve('relay-peer');
      expect(reservation, isNull);
    });
  });

  group('CircuitRelayClient connectThroughRelay', () {
    late _MockRouter router;
    late CircuitRelayClient client;

    setUp(() async {
      router = _MockRouter();
      client = CircuitRelayClient(router);
      await client.start();
    });

    test('connects through relay and exposes target peer', () async {
      final connection = await client.connectThroughRelay(
        relayAddr,
        targetPeerId,
      );
      expect(connection.targetPeerId, targetPeerId);
      expect(connection.relayAddr, relayAddr);
      expect(router.connectedPeers, contains(targetPeerId));
      expect(router.registeredRelayedPeers, contains(targetPeerId));
    });

    test('builds relayed multiaddr with /p2p-circuit segment', () async {
      await client.connectThroughRelay(relayAddr, targetPeerId);
      expect(
        router.connectedMultiaddrs.last,
        '/ip4/127.0.0.1/tcp/4001/p2p/relay-peer/p2p-circuit/p2p/$targetPeerId',
      );
    });

    test('builds relayed multiaddr when /p2p-circuit is omitted', () async {
      const addrWithoutCircuit = '/ip4/127.0.0.1/tcp/4001/p2p/relay-peer';
      await client.connectThroughRelay(addrWithoutCircuit, targetPeerId);
      expect(
        router.connectedMultiaddrs.last,
        '/ip4/127.0.0.1/tcp/4001/p2p/relay-peer/p2p-circuit/p2p/$targetPeerId',
      );
    });

    test('emits created event on success', () async {
      final events = <CircuitRelayConnectionEvent>[];
      final sub = client.onCircuitRelayEvents.listen(events.add);
      await client.connectThroughRelay(relayAddr, targetPeerId);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(events.any((e) => e.eventType == 'circuit_relay_created'), isTrue);
      await sub.cancel();
    });

    test('throws when disabled', () async {
      client = CircuitRelayClient(
        router,
        config: const CircuitRelayConfig(enabled: false),
      );
      await client.start();
      expect(
        () => client.connectThroughRelay(relayAddr, targetPeerId),
        throwsA(isA<CircuitRelayException>()),
      );
    });

    test('throws when CONNECT is rejected', () async {
      router.setConnectStatus(pb.Status.FAILED);
      expect(
        () => client.connectThroughRelay(relayAddr, targetPeerId),
        throwsA(isA<CircuitRelayException>()),
      );
    });

    test('emits failure event on CONNECT rejection', () async {
      router.setConnectStatus(pb.Status.FAILED);
      final events = <CircuitRelayConnectionEvent>[];
      final sub = client.onCircuitRelayEvents.listen(events.add);
      try {
        await client.connectThroughRelay(relayAddr, targetPeerId);
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(events.any((e) => e.eventType == 'circuit_relay_failed'), isTrue);
      await sub.cancel();
    });

    test('throws on timeout waiting for CONNECT status', () async {
      final silentRouter = _SilentRouter();
      client = CircuitRelayClient(
        silentRouter,
        config: const CircuitRelayConfig(
          reservationTimeout: Duration(milliseconds: 50),
        ),
      );
      await client.start();
      expect(
        () => client.connectThroughRelay(relayAddr, targetPeerId),
        throwsA(isA<CircuitRelayException>()),
      );
    });
  });

  group('maxCircuits enforcement', () {
    late _MockRouter router;
    late CircuitRelayClient client;

    setUp(() async {
      router = _MockRouter();
      client = CircuitRelayClient(
        router,
        config: const CircuitRelayConfig(
          maxCircuits: 2,
          reservationTimeout: Duration(milliseconds: 100),
        ),
      );
      await client.start();
    });

    test('queues additional attempts until a slot is freed', () async {
      final conn1 = await client.connectThroughRelay(relayAddr, '11');
      final conn2 = await client.connectThroughRelay(relayAddr, '12');
      expect(conn1.targetPeerId, '11');
      expect(conn2.targetPeerId, '12');

      final pending = client.connectThroughRelay(relayAddr, '13');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(router.connectedPeers, isNot(contains('13')));

      await client.disconnect('11');
      final conn3 = await pending;
      expect(conn3.targetPeerId, '13');
      expect(router.connectedPeers, contains('13'));
    });

    test('times out queued attempts when no slot is freed', () async {
      await client.connectThroughRelay(relayAddr, '11');
      await client.connectThroughRelay(relayAddr, '12');

      expect(
        () => client.connectThroughRelay(relayAddr, '13'),
        throwsA(isA<CircuitRelayException>()),
      );
    });
  });

  group('disconnect and cleanup', () {
    late _MockRouter router;
    late CircuitRelayClient client;

    setUp(() async {
      router = _MockRouter();
      client = CircuitRelayClient(router);
      await client.start();
      await client.connectThroughRelay(relayAddr, targetPeerId);
    });

    test('disconnect removes relayed peer', () async {
      await client.disconnect(targetPeerId);
      expect(router.connectedPeers, isNot(contains(targetPeerId)));
    });

    test('router disconnection event emits closed event', () async {
      final events = <CircuitRelayConnectionEvent>[];
      final sub = client.onCircuitRelayEvents.listen(events.add);
      router.emitPeerDisconnected(targetPeerId);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        events.any(
          (e) =>
              e.eventType == 'circuit_relay_closed' &&
              e.relayAddress == targetPeerId,
        ),
        isTrue,
      );
      await sub.cancel();
    });
  });

  group('CircuitRelayClient STOP handling', () {
    late _MockRouter router;
    late CircuitRelayClient client;

    setUp(() async {
      router = _MockRouter();
      client = CircuitRelayClient(router);
      await client.start();
    });

    test(
      'incoming STOP CONNECT replies with STATUS OK and emits event',
      () async {
        final events = <CircuitRelayConnectionEvent>[];
        final sub = client.onCircuitRelayEvents.listen(events.add);

        final stopMsg = pb.StopMessage()
          ..type = pb.StopMessage_Type.CONNECT
          ..peer = (pb.Peer()..id = [1, 2, 3]);
        router.deliverStopMessage('relay-peer', stopMsg.writeToBuffer());

        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(router.sentPeers, contains('relay-peer'));
        final response = pb.StopMessage.fromBuffer(router.sentMessages.last);
        expect(response.type, pb.StopMessage_Type.STATUS);
        expect(response.status, pb.Status.OK);
        expect(
          events.any((e) => e.eventType == 'circuit_relay_incoming'),
          isTrue,
        );
        await sub.cancel();
      },
    );
  });
}
