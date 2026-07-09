// test/protocols/dcutr/dcutr_handler_test.dart
import 'package:test/test.dart';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/protocols/dcutr/dcutr_handler.dart';

import '../../fakes/fake_router.dart';

void main() {
  group('DCUtRHandler offline mode', () {
    late NetworkHandler networkHandler;
    late DCUtRHandler handler;

    setUp(() {
      networkHandler = NetworkHandler(
        IPFSConfig(network: NetworkConfig()),
        router: FakeRouter(),
      );
      handler = DCUtRHandler(
        IPFSConfig(network: NetworkConfig()),
        networkHandler,
      );
    });

    tearDown(() async {
      await handler.stop();
      await networkHandler.stop();
    });

    test('isAvailable is false before start', () {
      expect(handler.isAvailable, isFalse);
    });

    test('start and stop lifecycle', () async {
      await handler.start();
      expect(handler.isAvailable, isFalse);
      final status = await handler.getStatus();
      expect(status['running'], isTrue);
      expect(status['available'], isFalse);
      await handler.stop();
      expect((await handler.getStatus())['running'], isFalse);
    });

    test('start and stop idempotency', () async {
      await handler.start();
      await handler.start();
      await handler.stop();
      await handler.stop();
      expect((await handler.getStatus())['running'], isFalse);
    });

    test('directConnect returns false when not running', () async {
      final result = await handler.directConnect('QmPeer');
      expect(result, isFalse);
    });

    test('directConnect returns false without hole punch service', () async {
      await handler.start();
      final result = await handler.directConnect('QmPeer');
      expect(result, isFalse);
      // No hole punch service available means the attempt is skipped before
      // the attempt is recorded.
      expect(handler.lastHolePunchAttempt('QmPeer'), isNull);
    });

    test('directConnect returns false for invalid peer id', () async {
      await handler.start();
      final result = await handler.directConnect('not-a-peer-id');
      expect(result, isFalse);
    });
  });
}
