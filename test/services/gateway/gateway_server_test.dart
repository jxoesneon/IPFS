import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/services/gateway/gateway_server.dart';
import 'package:test/test.dart';

class MockBlockStore implements BlockStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('GatewayServer', () {
    test('can be instantiated', () {
      final server = GatewayServer(blockStore: MockBlockStore());
      expect(server, isNotNull);
      expect(server.isRunning, isFalse);
    });

    // We can't easily test start/stop here because we don't want to actually bind ports
    // and createHttpServerAdapter returns the IO version which tries to bind.
    // In a real unit test we might want to mock createHttpServerAdapter,
    // but dart conditional imports make that tricky without dependency injection.
    // For now, simple instantiation is a good sanity check that imports are valid.
  });
}
