// test/issues/issue_22_dht_init_test.dart
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_client.dart';
import 'package:dart_ipfs/src/transport/p2plib_router.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'issue_22_dht_init_test.mocks.dart';

@GenerateMocks([NetworkHandler, P2plibRouter])
void main() {
  group('Issue #22: DHTClient LateInitializationError', () {
    late DHTClient dhtClient;
    late MockNetworkHandler mockNetworkHandler;
    late MockP2plibRouter mockRouter;

    setUp(() {
      mockNetworkHandler = MockNetworkHandler();
      mockRouter = MockP2plibRouter();

      // Setup default config mock if accessed
      when(mockNetworkHandler.config).thenReturn(IPFSConfig());

      dhtClient = DHTClient(
        networkHandler: mockNetworkHandler,
        router: mockRouter,
      );
    });

    test(
      'storeValue throws StateError (not LateInit) when not initialized',
      () async {
        // Trying to call storeValue before initialize() or start()
        // Should cleanly throw StateError with helpful message, NOT LateInitializationError

        try {
          await dhtClient.storeValue(
            Uint8List.fromList([1, 2, 3]),
            Uint8List.fromList([4, 5, 6]),
          );
          fail('Should have thrown error');
        } catch (e) {
          // We expect StateError ("DHTClient not initialized")
          // If Issue #22 is present, this might throw LateInitializationError or crash
          expect(e, isA<StateError>());
          expect(e.toString(), contains('DHTClient not initialized'));
        }
      },
    );

    test('getValue throws StateError when not initialized', () async {
      try {
        await dhtClient.getValue(Uint8List.fromList([1, 2, 3]));
        fail('Should have thrown error');
      } catch (e) {
        expect(e, isA<StateError>());
        expect(e.toString(), contains('DHTClient not initialized'));
      }
    });
  });
}
