import 'dart:async';

import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node_network_events.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:test/test.dart';

import '../../fakes/fake_router.dart';

/// Router that exposes a controllable connectionEvents stream.
class _EventsRouter extends FakeRouter {
  final StreamController<ConnectionEvent> controller =
      StreamController<ConnectionEvent>.broadcast();

  @override
  Stream<ConnectionEvent> get connectionEvents => controller.stream;
}

void main() {
  group('IpfsNodeNetworkEvents lifecycle', () {
    late _EventsRouter router;
    late IpfsNodeNetworkEvents events;

    setUp(() {
      router = _EventsRouter();
      events = IpfsNodeNetworkEvents(router);
    });

    tearDown(() async {
      await router.controller.close();
    });

    test('dispose cancels the router connectionEvents subscription', () async {
      events.start();
      expect(router.controller.hasListener, isTrue);

      events.dispose();
      await Future<void>.delayed(Duration.zero);

      // The discarded subscription used to stay attached to the router
      // forever; it must now be cancelled.
      expect(router.controller.hasListener, isFalse);
    });

    test('dispose before start is safe', () {
      events.dispose();
      expect(router.controller.hasListener, isFalse);
    });
  });
}
