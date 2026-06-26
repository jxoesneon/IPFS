// ignore_for_file: directives_ordering, deprecated_member_use_from_same_package, inference_failure_on_function_return_type, prefer_const_constructors

import 'dart:async';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart' as core;
import 'package:dart_ipfs/src/core/ipld/selectors/ipld_selector.dart' as ipld;
import 'package:dart_ipfs/src/core/ipld/selectors/selector_ast.dart' as gs;
import 'package:dart_ipfs/src/core/responses/block_response_factory.dart';
import 'package:dart_ipfs/src/proto/generated/graphsync/graphsync.pb.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:dart_ipfs/src/protocols/graphsync/graphsync_handler.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'graphsync_handler_test.mocks.dart';

void main() {
  late GraphsyncHandler handler;
  late MockRouterInterface mockRouter;
  late MockBitswapHandler mockBitswap;
  late MockIPLDHandler mockIpld;
  late MockBlockStore mockBlockStore;

  Future<core.Block> makeBlock(Uint8List data) async {
    return core.Block.fromData(data, format: 'raw');
  }

  Future<Function(NetworkPacket)> captureHandler() async {
    await handler.start();
    return verify(
          mockRouter.registerProtocolHandler(any, captureAny),
        ).captured.single
        as Function(NetworkPacket);
  }

  setUp(() async {
    mockRouter = MockRouterInterface();
    mockBitswap = MockBitswapHandler();
    mockIpld = MockIPLDHandler();
    mockBlockStore = MockBlockStore();
    handler = GraphsyncHandler(
      IPFSConfig(),
      mockRouter,
      mockBitswap,
      mockIpld,
      mockBlockStore,
    );
    await handler.start();
  });

  group('Graphsync bidirectional pause/resume', () {
    test('server pauses traversal when peer sends pause update', () async {
      final capturedHandler = await captureHandler();

      final dummyBlock = await makeBlock(Uint8List.fromList([4, 5, 6]));
      final rootCid = dummyBlock.cid;
      final selector = ipld.ExploreAll(next: ipld.Matcher());
      final request = GraphsyncRequest()
        ..id = 1
        ..root = rootCid.toBytes()
        ..selector = await ipld.encodeSelectorDagCbor(selector);

      final message = GraphsyncMessage()..requests.add(request);
      final packet = NetworkPacket(
        srcPeerId: 'peerA',
        datagram: message.writeToBuffer(),
      );

      when(mockBitswap.wantBlock(any)).thenAnswer((_) async => dummyBlock);
      when(mockBlockStore.hasBlock(any)).thenAnswer((_) async => false);
      when(mockBlockStore.getBlock(any)).thenAnswer(
        (_) async => BlockResponseFactory.successGet(dummyBlock.toProto()),
      );

      final completer = Completer<ipld.SelectedNode>();
      when(
        mockIpld.executeSelectorStream(
          any,
          any,
          maxDepth: anyNamed('maxDepth'),
          maxNodes: anyNamed('maxNodes'),
        ),
      ).thenAnswer((_) => Stream.fromFuture(completer.future));

      capturedHandler(packet);
      await pumpEventQueue();

      // The server should have accepted the request.
      var allCalls = verify(
        mockRouter.sendMessage(
          'peerA',
          captureAny,
          protocolId: anyNamed('protocolId'),
        ),
      ).captured.cast<Uint8List>();
      expect(allCalls, isNotEmpty);
      final acceptance = GraphsyncMessage.fromBuffer(allCalls.first);
      expect(
        acceptance.responses.first.status,
        equals(ResponseStatus.RS_IN_PROGRESS),
      );

      // Peer sends a pause update.
      final pauseMsg = GraphsyncMessage()
        ..requests.add(
          GraphsyncRequest()
            ..id = 1
            ..pause = true,
        );
      await capturedHandler(
        NetworkPacket(srcPeerId: 'peerA', datagram: pauseMsg.writeToBuffer()),
      );

      allCalls = verify(
        mockRouter.sendMessage(
          'peerA',
          captureAny,
          protocolId: anyNamed('protocolId'),
        ),
      ).captured.cast<Uint8List>();
      final pauseResponse = GraphsyncMessage.fromBuffer(allCalls.last);
      expect(
        pauseResponse.responses.first.status,
        equals(ResponseStatus.RS_PAUSED),
      );

      // Peer sends an unpause update and the traversal completes.
      final unpauseMsg = GraphsyncMessage()
        ..requests.add(
          GraphsyncRequest()
            ..id = 1
            ..unpause = true,
        );
      await capturedHandler(
        NetworkPacket(srcPeerId: 'peerA', datagram: unpauseMsg.writeToBuffer()),
      );
      completer.complete(
        ipld.SelectedNode(
          cid: rootCid,
          node: IPLDNode()
            ..kind = Kind.BYTES
            ..bytesValue = dummyBlock.data,
          path: '',
          remainingDepth: 32,
        ),
      );
      await pumpEventQueue();

      allCalls = verify(
        mockRouter.sendMessage(
          'peerA',
          captureAny,
          protocolId: anyNamed('protocolId'),
        ),
      ).captured.cast<Uint8List>();
      expect(
        allCalls.map(
          (b) => GraphsyncMessage.fromBuffer(b).responses.first.status,
        ),
        contains(ResponseStatus.RS_COMPLETED),
      );
    });

    test('client sends pause, resume, and cancel updates to a peer', () async {
      const peer = 'peerB';
      when(mockRouter.isConnectedPeer(peer)).thenReturn(true);
      when(
        mockBlockStore.putBlock(any),
      ).thenAnswer((_) async => BlockResponseFactory.successAdd('added'));

      final dummyBlock = await makeBlock(Uint8List.fromList([4, 5, 6]));
      final selector = const gs.ExploreAll(next: gs.Matcher());
      final stream = await handler.requestGraphFromPeer(
        peer,
        dummyBlock.cid,
        selector,
      );
      await pumpEventQueue();

      // Collect request id from the sent request buffer.
      final sentRequest =
          verify(
                mockRouter.sendMessage(
                  peer,
                  captureAny,
                  protocolId: anyNamed('protocolId'),
                ),
              ).captured.single
              as Uint8List;
      final requestId = GraphsyncMessage.fromBuffer(
        sentRequest,
      ).requests.first.id;

      await handler.pauseRequest(requestId, peer);
      await handler.resumeRequest(requestId, peer);
      await handler.cancelRequest(requestId, peer);
      await pumpEventQueue();

      final calls = verify(
        mockRouter.sendMessage(
          peer,
          captureAny,
          protocolId: anyNamed('protocolId'),
        ),
      ).captured.cast<Uint8List>();
      // pause + resume + cancel after the initial request.
      expect(calls.length, equals(3));

      final pauseUpdate = GraphsyncMessage.fromBuffer(calls[0]);
      expect(pauseUpdate.requests.first.pause, isTrue);
      expect(pauseUpdate.requests.first.id, equals(requestId));

      final resumeUpdate = GraphsyncMessage.fromBuffer(calls[1]);
      expect(resumeUpdate.requests.first.unpause, isTrue);
      expect(resumeUpdate.requests.first.id, equals(requestId));

      final cancelUpdate = GraphsyncMessage.fromBuffer(calls[2]);
      expect(cancelUpdate.requests.first.cancel, isTrue);
      expect(cancelUpdate.requests.first.id, equals(requestId));

      // The stream should still be alive until a terminal response is received.
      expect(stream, isA<Stream<GraphsyncResponse>>());
    });
  });
}

Future<void> pumpEventQueue() async {
  await Future<void>.delayed(Duration.zero);
}
