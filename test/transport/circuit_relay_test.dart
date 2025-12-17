// test/transport/circuit_relay_test.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:dart_ipfs/src/transport/circuit_relay_client.dart';
import 'package:dart_ipfs/src/transport/p2plib_router.dart';
import 'package:dart_ipfs/src/utils/base58.dart';
import 'package:dart_ipfs/src/proto/generated/circuit_relay.pb.dart' as pb;
import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:p2plib/p2plib.dart' as p2p;
import 'package:test/test.dart';

// Mock RouterL2
class MockRouterL2 implements p2p.RouterL2 {
  final Map<p2p.PeerId, List<p2p.FullAddress>> resolvedAddresses = {};
  void Function(Uint8List datagram, Iterable<p2p.FullAddress> addresses)?
  onSend;

  @override
  Iterable<p2p.FullAddress> resolvePeerId(p2p.PeerId peerId) {
    // Determine if we have a match by value equality or string representation if PeerId doesn't override ==
    // Simplify: just return what we have if non-empty
    return resolvedAddresses.values.expand((element) => element);
  }

  @override
  void sendDatagram({
    required Iterable<p2p.FullAddress> addresses,
    required Uint8List datagram,
  }) {
    if (onSend != null) {
      onSend!(datagram, addresses);
    }
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Mock P2plibRouter
class MockP2plibRouter implements P2plibRouter {
  bool started = false;
  final MockRouterL2 _routerL0 = MockRouterL2();
  final Map<String, void Function(p2p.Packet)> handlers = {};

  @override
  p2p.RouterL2 get routerL0 => _routerL0;

  @override
  Future<void> start() async {
    started = true;
  }

  @override
  Future<void> stop() async {
    started = false;
  }

  @override
  void registerProtocol(String protocolId) {}

  @override
  void registerProtocolHandler(
    String protocolId,
    void Function(p2p.Packet) handler,
  ) {
    handlers[protocolId] = handler;
  }

  @override
  Future<void> connect(String peerId) async {}

  @override
  Future<void> disconnect(String peerId) async {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('CircuitRelayClient', () {
    late CircuitRelayClient client;
    late MockP2plibRouter mockRouter;
    late String validPeerId;
    late p2p.PeerId peerIdObj;

    setUp(() {
      mockRouter = MockP2plibRouter();
      client = CircuitRelayClient(mockRouter);

      // Setup valid peer ID matching bitswap_test.dart pattern (64 bytes)
      final bytes = Uint8List.fromList(List.filled(64, 1));
      validPeerId = Base58().encode(bytes);
      peerIdObj = p2p.PeerId(value: bytes);

      mockRouter._routerL0.resolvedAddresses[peerIdObj] = [
        p2p.FullAddress(address: InternetAddress.loopbackIPv4, port: 4001),
      ];
    });

    test('start/stop', () async {
      await client.start();
      expect(mockRouter.started, isTrue);
      expect(
        mockRouter.handlers.containsKey('/libp2p/circuit/relay/0.2.0/hop'),
        isTrue,
      );

      await client.stop();
      // stop() calls router.stop() but doesn't clear handlers in mock, which is fine
      expect(mockRouter.started, isFalse);
    });

    test('reserve returns reservation on success', () async {
      await client.start();

      // Intercept send and reply with success
      mockRouter._routerL0.onSend = (datagram, addresses) {
        // Decode request to verify it is a RESERVE
        final req = pb.HopMessage.fromBuffer(datagram);
        expect(req.type, pb.HopMessage_Type.RESERVE);

        // Simulate response
        final res = pb.HopMessage()
          ..type = pb.HopMessage_Type.STATUS
          ..status = pb.Status.OK
          ..reservation = (pb.Reservation()
            ..expire = fixnum.Int64(
              (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600,
            )
            ..limitData = fixnum.Int64(1000)
            ..limitDuration = fixnum.Int64(3600));

        // Trigger handler
        final handler = mockRouter.handlers['/libp2p/circuit/relay/0.2.0/hop']!;

        final packet = p2p.Packet(
          datagram: res.writeToBuffer(),
          header: p2p.PacketHeader(id: 1, issuedAt: 0),
          srcFullAddress: addresses.first,
        );
        packet.srcPeerId = peerIdObj;

        handler(packet);
      };

      final reservation = await client.reserve(validPeerId);

      expect(reservation, isNotNull);
      expect(reservation!.relayPeerId, equals(validPeerId));
      expect(reservation.limitData.toInt(), equals(1000));
      expect(reservation.isExpired, isFalse);
    });

    test('reserve handles failure status', () async {
      await client.start();

      mockRouter._routerL0.onSend = (datagram, addresses) {
        final res = pb.HopMessage()
          ..type = pb.HopMessage_Type.STATUS
          ..status = pb.Status.FAILED;

        final handler = mockRouter.handlers['/libp2p/circuit/relay/0.2.0/hop']!;
        final packet = p2p.Packet(
          datagram: res.writeToBuffer(),
          header: p2p.PacketHeader(id: 1, issuedAt: 0),
          srcFullAddress: addresses.first,
        );
        packet.srcPeerId = peerIdObj;
        handler(packet);
      };

      final reservation = await client.reserve(validPeerId);
      expect(reservation, isNull);
    });
  });
}
