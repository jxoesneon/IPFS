// test/transport/circuit_relay_test.dart
import 'dart:async';
import 'package:dart_ipfs/src/transport/circuit_relay_client.dart';
import 'package:dart_ipfs/src/transport/p2plib_router.dart';
import 'package:p2plib/p2plib.dart' as p2p;
import 'package:test/test.dart';

// Mock P2plibRouter
class MockP2plibRouter implements P2plibRouter {
  bool started = false;

  @override
  Future<void> start() async {
    started = true;
  }

  @override
  Future<void> stop() async {
    started = false;
  }

  @override
  Future<void> connect(String peerId) async {
    // Mock success
  }

  @override
  Future<void> disconnect(String peerId) async {
    // Mock success
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('CircuitRelayClient', () {
    late CircuitRelayClient client;
    late MockP2plibRouter mockRouter;

    setUp(() {
      mockRouter = MockP2plibRouter();
      client = CircuitRelayClient(mockRouter);
    });

    test('start/stop', () async {
      await client.start();
      expect(mockRouter.started, isTrue);

      await client.stop();
      expect(mockRouter.started, isFalse);
    });

    test('reserve returns reservation on success', () async {
      // Verify event emitted
      final eventFuture = expectLater(
        client.onCircuitRelayEvents,
        emits(
          predicate<CircuitRelayConnectionEvent>(
            (e) =>
                e.eventType == 'circuit_relay_reservation' &&
                e.relayAddress == 'TestRelayPeer',
          ),
        ),
      );

      final reservation = await client.reserve('TestRelayPeer');

      expect(reservation, isNotNull);
      expect(reservation!.relayPeerId, equals('TestRelayPeer'));
      expect(reservation.limitData.toInt(), equals(1024 * 1024 * 1024));
      expect(reservation.isExpired, isFalse);

      await eventFuture;
    });

    test('reserve handles expiration check', () async {
      final reservation = await client.reserve(
        'ShortRelay',
        duration: Duration(milliseconds: 1),
      );

      await Future<void>.delayed(Duration(milliseconds: 10));
      expect(reservation!.isExpired, isTrue);
    });
  });
}
