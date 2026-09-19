@TestOn('vm')
library;

import 'dart:async';

import 'package:dart_ipfs/src/transport/circuit_relay_client_web.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:test/test.dart';

void main() {
  group('CircuitRelayClient (web)', () {
    late CircuitRelayClient client;

    setUp(() {
      client = CircuitRelayClient(_FakeRouter());
    });

    tearDown(() async {
      await client.stop();
    });

    test('reserve throws a descriptive CircuitRelayException', () {
      expect(
        () => client.reserve('relayPeer'),
        throwsA(
          isA<CircuitRelayException>().having(
            (e) => e.message,
            'message',
            allOf(contains('web platform'), contains('Circuit Relay')),
          ),
        ),
      );
    });

    test('connectThroughRelay throws a descriptive CircuitRelayException', () {
      expect(
        () => client.connectThroughRelay('/p2p/relay', 'target'),
        throwsA(isA<CircuitRelayException>()),
      );
    });

    test('connect throws a descriptive CircuitRelayException', () {
      expect(
        () => client.connect('peer'),
        throwsA(isA<CircuitRelayException>()),
      );
    });

    test('lifecycle and event surface still work', () async {
      await client.start();

      expect(client.activeRelayAddrs, isEmpty);
      expect(client.connectionEvents, isA<Stream>());

      final event = CircuitRelayConnectionEvent(
        eventType: 'test',
        relayAddress: '/p2p/relay',
      );
      expectLater(client.onCircuitRelayEvents, emits(event));
      client.emitCircuitRelayEvent(event);

      await client.disconnect('peer');
    });
  });
}

class _FakeRouter implements RouterInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
