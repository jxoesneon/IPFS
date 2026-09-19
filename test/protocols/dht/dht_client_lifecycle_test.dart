import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_client.dart';
import 'package:test/test.dart';

import '../../fakes/fake_router.dart';

/// Minimal [NetworkHandler] fake — only `config` is exercised by
/// [DHTClient.initialize]; anything else is an error.
class _FakeNetworkHandler implements NetworkHandler {
  _FakeNetworkHandler(this.config);

  @override
  final IPFSConfig config;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// Router that can be told to fail `registerProtocol`, which runs after the
/// routing table (and its KademliaTree timers) is created in initialize().
class _FailOnRegisterRouter extends FakeRouter {
  bool failRegister = false;

  @override
  void registerProtocol(String protocolId) {
    if (failRegister) {
      throw StateError('registerProtocol failed');
    }
  }
}

void main() {
  group('DHTClient lifecycle', () {
    late _FakeNetworkHandler networkHandler;
    late _FailOnRegisterRouter router;
    late DHTClient client;

    setUp(() {
      networkHandler = _FakeNetworkHandler(IPFSConfig());
      router = _FailOnRegisterRouter();
      client = DHTClient(networkHandler: networkHandler, router: router);
    });

    tearDown(() async {
      await client.stop();
    });

    test(
      'initialize failure stops the partially-created table timers',
      () async {
        // registerProtocol runs after the KademliaRoutingTable has been created;
        // its KademliaTree constructor already started periodic timers.
        router.failRegister = true;
        await expectLater(client.initialize(), throwsA(isA<StateError>()));

        // The orphaned table's timers must have been cancelled so a retry does
        // not stack another set of periodic tasks on top of them.
        final orphan = client.kademliaRoutingTable;
        expect(orphan.isStopped, isTrue);

        // The retry installs a fresh, running table rather than reusing the
        // stopped one.
        router.failRegister = false;
        await client.initialize();
        expect(client.isInitialized, isTrue);
        expect(identical(client.kademliaRoutingTable, orphan), isFalse);
        expect(client.kademliaRoutingTable.isStopped, isFalse);
      },
    );

    test('stop after a failed initialize is safe and a retry works', () async {
      router.failRegister = true;
      await expectLater(client.initialize(), throwsA(anything));

      // stop() must not choke on (or skip cleanup of) the partial table.
      await client.stop();

      router.failRegister = false;
      await client.initialize();
      expect(client.isInitialized, isTrue);
      expect(client.kademliaRoutingTable.isStopped, isFalse);
    });
  });
}
