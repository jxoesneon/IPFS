// ignore_for_file: directives_ordering, deprecated_member_use_from_same_package, inference_failure_on_function_return_type, prefer_const_constructors

import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dart_ipfs/src/protocols/graphsync/graphsync_handler.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:dart_ipfs/src/protocols/bitswap/bitswap_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipld_handler.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/responses/block_response_factory.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart' as core;
import 'package:dart_ipfs/src/proto/generated/graphsync/graphsync.pb.dart';
import 'package:dart_ipfs/src/core/ipld/selectors/ipld_selector.dart' as ipld;
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:dart_ipfs/src/core/errors/graphsync_errors.dart';

import 'graphsync_handler_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<RouterInterface>(),
  MockSpec<BitswapHandler>(),
  MockSpec<IPLDHandler>(),
  MockSpec<BlockStore>(),
])
void main() {
  late GraphsyncHandler handler;
  late MockRouterInterface mockRouter;
  late MockBitswapHandler mockBitswap;
  late MockIPLDHandler mockIpld;
  late MockBlockStore mockBlockStore;
  late IPFSConfig config;

  setUp(() {
    mockRouter = MockRouterInterface();
    mockBitswap = MockBitswapHandler();
    mockIpld = MockIPLDHandler();
    mockBlockStore = MockBlockStore();
    config = IPFSConfig();
    handler = GraphsyncHandler(
      config,
      mockRouter,
      mockBitswap,
      mockIpld,
      mockBlockStore,
    );
  });

  group('GraphsyncHandler', () {
    test('start registers protocol and handler', () async {
      await handler.start();
      verify(mockRouter.registerProtocol('/ipfs/graphsync/1.0.0')).called(1);
      verify(
        mockRouter.registerProtocolHandler('/ipfs/graphsync/1.0.0', any),
      ).called(1);
    });

    test('getStatus returns correct info', () async {
      final status = await handler.getStatus();
      expect(status['enabled'], isTrue);
      expect(status['active_requests'], equals(0));
    });

    test('requestGraph sends message and returns block', () async {
      final cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      final selector = ipld.IPLDSelector(type: ipld.SelectorType.all);
      final decodedCid = CID.decode(cid);
      final dummyBlock = core.Block(
        cid: decodedCid,
        data: Uint8List.fromList([1, 2, 3]),
      );

      when(mockBitswap.wantBlock(cid)).thenAnswer((_) async => dummyBlock);

      final result = await handler.requestGraph(cid, selector);

      expect(result, isNotNull);
      expect(result!.data, equals(dummyBlock.data));
      verify(mockRouter.broadcastMessage(any, any)).called(1);
    });

    test('stop executes cleanly', () async {
      await handler.stop();
      // Verifies logger output or just completion
    });

    test('handleMessage processes new request', () async {
      await handler.start();
      // Capture the handler
      final capturedHandler =
          verify(
                mockRouter.registerProtocolHandler(any, captureAny),
              ).captured.single
              as Function(NetworkPacket);

      final rootCid = CID.decode(
        'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn',
      );
      final selector = ipld.ExploreAll(next: ipld.Matcher());
      final selectorBytes = await ipld.encodeSelectorDagCbor(selector);

      final request = GraphsyncRequest()
        ..id = 1
        ..root = rootCid.toBytes()
        ..selector = selectorBytes;

      final message = GraphsyncMessage();
      message.requests.add(request);

      final packet = NetworkPacket(
        srcPeerId: 'peerA',
        datagram: message.writeToBuffer(),
      );

      final dummyBlock = core.Block(
        cid: rootCid,
        data: Uint8List.fromList([4, 5, 6]),
      );
      when(mockBitswap.wantBlock(any)).thenAnswer((_) async => dummyBlock);

      final resultNode = IPLDNode()
        ..kind = Kind.BYTES
        ..bytesValue = dummyBlock.data;
      final result = ipld.SelectedNode(
        cid: rootCid,
        node: resultNode,
        path: 'some/path',
        remainingDepth: 32,
      );
      when(
        mockIpld.executeSelectorStream(
          any,
          any,
          maxDepth: anyNamed('maxDepth'),
          maxNodes: anyNamed('maxNodes'),
        ),
      ).thenAnswer((_) => Stream.fromIterable([result]));
      when(mockBlockStore.hasBlock(any)).thenAnswer((_) async => false);
      when(mockBlockStore.getBlock(any)).thenAnswer(
        (_) async => BlockResponseFactory.successGet(dummyBlock.toProto()),
      );

      await capturedHandler(packet);

      // Verify initial response sent
      verify(mockRouter.broadcastMessage(any, any)).called(greaterThan(2));
    });

    test('handleMessage processes cancel request', () async {
      await handler.start();
      final capturedHandler =
          verify(
                mockRouter.registerProtocolHandler(any, captureAny),
              ).captured.single
              as Function(NetworkPacket);

      final message = GraphsyncMessage();
      message.requests.add(
        GraphsyncRequest()
          ..id = 1
          ..cancel = true,
      );

      final packet = NetworkPacket(
        srcPeerId: 'peerA',
        datagram: message.writeToBuffer(),
      );

      await capturedHandler(packet);
      verify(mockRouter.broadcastMessage(any, any)).called(1);
    });

    test('handleMessage processes pause/unpause request', () async {
      await handler.start();
      final capturedHandler =
          verify(
                mockRouter.registerProtocolHandler(any, captureAny),
              ).captured.single
              as Function(NetworkPacket);

      final pauseMsg = GraphsyncMessage();
      pauseMsg.requests.add(
        GraphsyncRequest()
          ..id = 2
          ..pause = true,
      );
      await capturedHandler(
        NetworkPacket(srcPeerId: 'p', datagram: pauseMsg.writeToBuffer()),
      );

      final unpauseMsg = GraphsyncMessage();
      unpauseMsg.requests.add(
        GraphsyncRequest()
          ..id = 2
          ..unpause = true,
      );
      await capturedHandler(
        NetworkPacket(srcPeerId: 'p', datagram: unpauseMsg.writeToBuffer()),
      );

      verify(mockRouter.broadcastMessage(any, any)).called(2);
    });

    test('handleMessage error if missing root or selector', () async {
      await handler.start();
      final capturedHandler =
          verify(
                mockRouter.registerProtocolHandler(any, captureAny),
              ).captured.single
              as Function(NetworkPacket);

      final request = GraphsyncRequest()..id = 4; // Missing root and selector
      final message = GraphsyncMessage()..requests.add(request);

      final packet = NetworkPacket(
        srcPeerId: 'peerA',
        datagram: message.writeToBuffer(),
      );

      await expectLater(
        () => capturedHandler(packet),
        throwsA(isA<GraphsyncError>()),
      );
    });

    test('handleMessage error if root block not found', () async {
      await handler.start();
      final capturedHandler =
          verify(
                mockRouter.registerProtocolHandler(any, captureAny),
              ).captured.single
              as Function(NetworkPacket);

      final rootCid = CID.decode(
        'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn',
      );
      final selector = ipld.ExploreAll(next: ipld.Matcher());
      final request = GraphsyncRequest()
        ..id = 5
        ..root = rootCid.toBytes()
        ..selector = await ipld.encodeSelectorDagCbor(selector);

      final message = GraphsyncMessage()..requests.add(request);
      final packet = NetworkPacket(
        srcPeerId: 'peerA',
        datagram: message.writeToBuffer(),
      );

      when(mockBitswap.wantBlock(any)).thenAnswer((_) async => null);
      when(mockIpld.executeSelectorStream(any, any)).thenAnswer(
        (_) => Stream.fromIterable([
          ipld.SelectedNode(
            cid: rootCid,
            node: IPLDNode(),
            path: '',
            remainingDepth: 32,
          ),
        ]),
      );

      await expectLater(
        () => capturedHandler(packet),
        throwsA(isA<GraphsyncError>()),
      );
    });

    test('handleMessage error if root node not found in IPLD', () async {
      await handler.start();
      final capturedHandler =
          verify(
                mockRouter.registerProtocolHandler(any, captureAny),
              ).captured.single
              as Function(NetworkPacket);

      final rootCid = CID.decode(
        'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn',
      );
      final selector = ipld.ExploreAll(next: ipld.Matcher());
      final request = GraphsyncRequest()
        ..id = 6
        ..root = rootCid.toBytes()
        ..selector = await ipld.encodeSelectorDagCbor(selector);

      final message = GraphsyncMessage()..requests.add(request);
      final packet = NetworkPacket(
        srcPeerId: 'peerA',
        datagram: message.writeToBuffer(),
      );

      final dummyBlock = core.Block(
        cid: rootCid,
        data: Uint8List.fromList([4, 5, 6]),
      );
      when(mockBitswap.wantBlock(any)).thenAnswer((_) async => dummyBlock);
      when(
        mockIpld.executeSelectorStream(any, any),
      ).thenAnswer((_) => Stream.empty());

      await expectLater(
        () => capturedHandler(packet),
        throwsA(isA<GraphsyncError>()),
      );
    });
  });
}
