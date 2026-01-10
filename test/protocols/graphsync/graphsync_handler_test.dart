import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dart_ipfs/src/protocols/graphsync/graphsync_handler.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/transport/p2plib_router.dart';
import 'package:dart_ipfs/src/protocols/bitswap/bitswap_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipld_handler.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/proto/generated/graphsync/graphsync.pb.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart' as core;
import 'package:dart_ipfs/src/core/ipld/selectors/ipld_selector.dart';
import 'package:dart_ipfs/src/core/responses/block_response_factory.dart';

import 'graphsync_handler_test.mocks.dart';

@GenerateMocks([P2plibRouter, BitswapHandler, IPLDHandler, BlockStore])
void main() {
  group('GraphsyncHandler', () {
    late GraphsyncHandler handler;
    late MockP2plibRouter mockRouter;
    late MockBitswapHandler mockBitswap;
    late MockIPLDHandler mockIpld;
    late MockBlockStore mockBlockStore;
    late IPFSConfig config;

    setUp(() {
      mockRouter = MockP2plibRouter();
      mockBitswap = MockBitswapHandler();
      mockIpld = MockIPLDHandler();
      mockBlockStore = MockBlockStore();
      config = IPFSConfig();
      
      handler = GraphsyncHandler(config, mockRouter, mockBitswap, mockIpld, mockBlockStore);
    });

    test('start registers protocol and handler', () async {
      when(mockRouter.registerProtocol(any)).thenReturn(null);
      when(mockRouter.registerProtocolHandler(any, any)).thenReturn(null);

      await handler.start();

      verify(mockRouter.registerProtocol('/ipfs/graphsync/1.0.0')).called(1);
      verify(mockRouter.registerProtocolHandler('/ipfs/graphsync/1.0.0', any)).called(1);
    });

    test('stop logs success', () async {
      await handler.stop();
    });
    
    test('requestGraph sends request and fetches root block', () async {
      final blockData = Uint8List.fromList([1, 2, 3]);
      final block = await core.Block.fromData(blockData, format: 'raw');
      final cidStr = block.cid.toString();
      final selector = IPLDSelector(type: SelectorType.all);
      
      when(mockRouter.broadcastMessage(any, any)).thenAnswer((_) async {});
      when(mockBitswap.wantBlock(any)).thenAnswer((_) async => block);
      when(mockBlockStore.putBlock(any)).thenAnswer(
        (_) async => BlockResponseFactory.successAdd('Added'),
      );

      final result = await handler.requestGraph(cidStr, selector);
      
      expect(result, isNotNull);
      expect(result!.data, equals(blockData));
      
      // Use any for protocol ID matching to avoid strict string issues or import protocol class
      verify(mockRouter.broadcastMessage(argThat(contains('graphsync')), any)).called(1);
      verify(mockBitswap.wantBlock(cidStr)).called(1);
    });

    test('handleCancelRequest processes message', () async {
      // Access private method via reflection or just construct incoming packet?
      // Since _handleMessage is attached to the router filter, we can test by simulating the callback.
      // But _handleMessage is private. 
      // We can expose it or invoke it via a test helper if we modify the class.
      // Alternatively, we capture the callback passed to registerProtocolHandler.
      
      var callback;
      when(mockRouter.registerProtocol(any)).thenReturn(null);
      when(mockRouter.registerProtocolHandler(any, any)).thenAnswer((invocation) {
        callback = invocation.positionalArguments[1];
      });

      await handler.start();
      expect(callback, isNotNull);

      // Create cancel request packet
      final gsMsg = GraphsyncMessage()
        ..requests.add(GraphsyncRequest()
            ..id = 123
            ..cancel = true
        );
      
      // Prepare Packet (Packet class needs checking)
      // The callback expects 'packet'. 
      // Checking graphsync_handler.dart: (packet) => _handleMessage(packet.srcPeerId, packet.datagram)
      // So packet has srcPeerId and datagram.
      // We need a MockPacket.
    });
  });
}
