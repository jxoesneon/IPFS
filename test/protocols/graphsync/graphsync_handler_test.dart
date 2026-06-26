// ignore_for_file: directives_ordering, deprecated_member_use_from_same_package, inference_failure_on_function_return_type, prefer_const_constructors

import 'dart:async';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart' as core;
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/errors/graphsync_errors.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipld_handler.dart';
import 'package:dart_ipfs/src/core/ipld/selectors/ipld_selector.dart' as ipld;
import 'package:dart_ipfs/src/core/ipld/selectors/selector_ast.dart' as gs;
import 'package:dart_ipfs/src/core/responses/block_response_factory.dart';
import 'package:dart_ipfs/src/proto/generated/graphsync/graphsync.pb.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:dart_ipfs/src/protocols/bitswap/bitswap_handler.dart';
import 'package:dart_ipfs/src/protocols/graphsync/graphsync_handler.dart';
import 'package:dart_ipfs/src/protocols/graphsync/graphsync_protocol.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

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

  Future<core.Block> makeBlock(Uint8List data) async {
    return core.Block.fromData(data, format: 'raw');
  }

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

  Future<Function(NetworkPacket)> captureHandler() async {
    await handler.start();
    return verify(
          mockRouter.registerProtocolHandler(any, captureAny),
        ).captured.single
        as Function(NetworkPacket);
  }

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
      expect(status['server_requests'], equals(0));
      expect(status['client_requests'], equals(0));
    });

    test(
      'requestGraph falls back to Bitswap when no peers connected',
      () async {
        final cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
        final selector = ipld.IPLDSelector(type: ipld.SelectorType.all);
        final dummyBlock = await makeBlock(Uint8List.fromList([1, 2, 3]));

        when(mockRouter.listConnectedPeers()).thenReturn([]);
        when(mockBitswap.wantBlock(cid)).thenAnswer((_) async => dummyBlock);

        final result = await handler.requestGraph(cid, selector);

        expect(result, isNotNull);
        expect(result!.data, equals(dummyBlock.data));
        verify(mockBitswap.wantBlock(cid)).called(1);
        verifyNever(
          mockRouter.sendMessage(any, any, protocolId: anyNamed('protocolId')),
        );
      },
    );

    test('requestGraph sends Graphsync to first connected peer', () async {
      final selector = ipld.IPLDSelector(type: ipld.SelectorType.all);
      final dummyBlock = await makeBlock(Uint8List.fromList([1, 2, 3]));
      final cid = dummyBlock.cid.encode();

      const peer = 'peerA';
      when(mockRouter.listConnectedPeers()).thenReturn([peer]);
      when(mockRouter.isConnectedPeer(peer)).thenReturn(true);
      when(mockBlockStore.hasBlock(any)).thenAnswer((_) async => false);
      when(mockBlockStore.getBlock(any)).thenAnswer(
        (_) async => BlockResponseFactory.successGet(dummyBlock.toProto()),
      );
      when(
        mockBlockStore.putBlock(any),
      ).thenAnswer((_) async => BlockResponseFactory.successAdd('added'));

      final capturedHandler = await captureHandler();
      final future = handler.requestGraph(cid, selector);

      await pumpEventQueue();

      final sentBuffer =
          verify(
                mockRouter.sendMessage(
                  peer,
                  captureAny,
                  protocolId: anyNamed('protocolId'),
                ),
              ).captured.single
              as Uint8List;
      final requestMessage = GraphsyncMessage.fromBuffer(sentBuffer);
      expect(requestMessage.requests, hasLength(1));
      final requestId = requestMessage.requests.first.id;

      final responseMessage = GraphsyncProtocol().createResponse(
        requestId: requestId,
        status: ResponseStatus.RS_COMPLETED,
        blocks: [
          Block(prefix: dummyBlock.cid.toPrefixBytes(), data: dummyBlock.data),
        ],
      );
      await capturedHandler(
        NetworkPacket(
          srcPeerId: peer,
          datagram: responseMessage.writeToBuffer(),
        ),
      );

      final result = await future;
      expect(result, isNotNull);
      expect(result!.data, equals(dummyBlock.data));
    });

    test('handleMessage processes new request and unicasts response', () async {
      final capturedHandler = await captureHandler();

      final dummyBlock = await makeBlock(Uint8List.fromList([4, 5, 6]));
      final rootCid = dummyBlock.cid;
      final selector = ipld.ExploreAll(next: ipld.Matcher());
      final selectorBytes = await ipld.encodeSelectorDagCbor(selector);

      final request = GraphsyncRequest()
        ..id = 1
        ..root = rootCid.toBytes()
        ..selector = selectorBytes;

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

      final resultNode = IPLDNode()
        ..kind = Kind.BYTES
        ..bytesValue = dummyBlock.data;
      final selected = ipld.SelectedNode(
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
      ).thenAnswer((_) => Stream.fromIterable([selected]));

      await capturedHandler(packet);
      await pumpEventQueue();

      final calls = verify(
        mockRouter.sendMessage(
          'peerA',
          captureAny,
          protocolId: anyNamed('protocolId'),
        ),
      ).captured;
      expect(calls, isNotEmpty);

      final terminalBuffer = calls.last as Uint8List;
      final terminalMessage = GraphsyncMessage.fromBuffer(terminalBuffer);
      expect(terminalMessage.responses, hasLength(1));
      expect(
        terminalMessage.responses.first.status,
        equals(ResponseStatus.RS_COMPLETED),
      );
      expect(terminalMessage.blocks, isNotEmpty);
      expect(
        terminalMessage.blocks.first.prefix,
        equals(dummyBlock.cid.toPrefixBytes()),
      );
      expect(terminalMessage.blocks.first.data, equals(dummyBlock.data));
    });

    test('handleMessage rejects invalid request via unicast', () async {
      final capturedHandler = await captureHandler();

      final request = GraphsyncRequest()..id = 4; // Missing root and selector
      final message = GraphsyncMessage()..requests.add(request);
      final packet = NetworkPacket(
        srcPeerId: 'peerA',
        datagram: message.writeToBuffer(),
      );

      await capturedHandler(packet);
      await pumpEventQueue();

      final sentBuffer =
          verify(
                mockRouter.sendMessage(
                  'peerA',
                  captureAny,
                  protocolId: anyNamed('protocolId'),
                ),
              ).captured.single
              as Uint8List;
      final responseMessage = GraphsyncMessage.fromBuffer(sentBuffer);
      expect(
        responseMessage.responses.first.status,
        equals(ResponseStatus.RS_REJECTED),
      );
      expect(
        responseMessage.responses.first.metadata['error'],
        contains('missing root'),
      );
    });

    test('handleMessage processes cancel request unicast', () async {
      final capturedHandler = await captureHandler();

      final message = GraphsyncMessage()
        ..requests.add(
          GraphsyncRequest()
            ..id = 1
            ..cancel = true,
        );
      final packet = NetworkPacket(
        srcPeerId: 'peerA',
        datagram: message.writeToBuffer(),
      );

      await capturedHandler(packet);

      final sentBuffer =
          verify(
                mockRouter.sendMessage(
                  'peerA',
                  captureAny,
                  protocolId: anyNamed('protocolId'),
                ),
              ).captured.single
              as Uint8List;
      final responseMessage = GraphsyncMessage.fromBuffer(sentBuffer);
      expect(
        responseMessage.responses.first.status,
        equals(ResponseStatus.RS_CANCELLED),
      );
    });

    test('handleMessage processes pause/unpause request unicast', () async {
      final capturedHandler = await captureHandler();

      final pauseMsg = GraphsyncMessage()
        ..requests.add(
          GraphsyncRequest()
            ..id = 2
            ..pause = true,
        );
      await capturedHandler(
        NetworkPacket(srcPeerId: 'p', datagram: pauseMsg.writeToBuffer()),
      );

      final unpauseMsg = GraphsyncMessage()
        ..requests.add(
          GraphsyncRequest()
            ..id = 2
            ..unpause = true,
        );
      await capturedHandler(
        NetworkPacket(srcPeerId: 'p', datagram: unpauseMsg.writeToBuffer()),
      );

      final calls = verify(
        mockRouter.sendMessage(
          'p',
          captureAny,
          protocolId: anyNamed('protocolId'),
        ),
      ).captured;
      expect(calls, hasLength(2));

      final pauseResponse = GraphsyncMessage.fromBuffer(calls[0] as Uint8List);
      expect(
        pauseResponse.responses.first.status,
        equals(ResponseStatus.RS_PAUSED),
      );

      final unpauseResponse = GraphsyncMessage.fromBuffer(
        calls[1] as Uint8List,
      );
      expect(
        unpauseResponse.responses.first.status,
        equals(ResponseStatus.RS_IN_PROGRESS),
      );
    });

    test('handleMessage rejects request when root block not found', () async {
      final capturedHandler = await captureHandler();

      final dummyBlock = await makeBlock(Uint8List.fromList([4, 5, 6]));
      final rootCid = dummyBlock.cid;
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
      when(mockBlockStore.hasBlock(any)).thenAnswer((_) async => false);

      await capturedHandler(packet);
      await pumpEventQueue();

      final sentBuffer =
          verify(
                mockRouter.sendMessage(
                  'peerA',
                  captureAny,
                  protocolId: anyNamed('protocolId'),
                ),
              ).captured.last
              as Uint8List;
      final responseMessage = GraphsyncMessage.fromBuffer(sentBuffer);
      expect(
        responseMessage.responses.first.status,
        equals(ResponseStatus.RS_REJECTED),
      );
      expect(
        responseMessage.responses.first.metadata['error'],
        contains('root block'),
      );
    });

    test('handleMessage enforces block-count budget', () async {
      final capturedHandler = await captureHandler();

      final dummyBlock = await makeBlock(Uint8List.fromList([4, 5, 6]));
      final rootCid = dummyBlock.cid;
      final childBlock = await makeBlock(Uint8List.fromList([7, 8, 9]));
      final selector = ipld.ExploreAll(next: ipld.Matcher());
      final request = GraphsyncRequest()
        ..id = 7
        ..root = rootCid.toBytes()
        ..selector = await ipld.encodeSelectorDagCbor(selector);
      request.extensions['graphsync/max-blocks'] = [
        1,
      ]; // root only, no children

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

      when(
        mockIpld.executeSelectorStream(
          any,
          any,
          maxDepth: anyNamed('maxDepth'),
          maxNodes: anyNamed('maxNodes'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          ipld.SelectedNode(
            cid: childBlock.cid,
            node: IPLDNode()
              ..kind = Kind.BYTES
              ..bytesValue = childBlock.data,
            path: 'child',
            remainingDepth: 32,
          ),
        ]),
      );

      await capturedHandler(packet);
      await pumpEventQueue();

      final sentBuffer =
          verify(
                mockRouter.sendMessage(
                  'peerA',
                  captureAny,
                  protocolId: anyNamed('protocolId'),
                ),
              ).captured.last
              as Uint8List;
      final responseMessage = GraphsyncMessage.fromBuffer(sentBuffer);
      expect(
        responseMessage.responses.first.status,
        equals(ResponseStatus.RS_REJECTED),
      );
      expect(
        responseMessage.responses.first.metadata['error'],
        contains('block count'),
      );
    });

    test('fetchGraphFromPeer collects blocks from peer', () async {
      final capturedHandler = await captureHandler();

      const peer = 'peerB';
      when(mockRouter.isConnectedPeer(peer)).thenReturn(true);
      when(
        mockBlockStore.putBlock(any),
      ).thenAnswer((_) async => BlockResponseFactory.successAdd('added'));

      final dummyBlock = await makeBlock(Uint8List.fromList([4, 5, 6]));
      final rootCid = dummyBlock.cid;
      final selector = const gs.ExploreAll(next: gs.Matcher());

      final future = handler.fetchGraphFromPeer(peer, rootCid, selector);
      await pumpEventQueue();

      final sentBuffer =
          verify(
                mockRouter.sendMessage(
                  peer,
                  captureAny,
                  protocolId: anyNamed('protocolId'),
                ),
              ).captured.single
              as Uint8List;
      final requestMessage = GraphsyncMessage.fromBuffer(sentBuffer);
      final requestId = requestMessage.requests.first.id;

      final responseMessage = GraphsyncProtocol().createResponse(
        requestId: requestId,
        status: ResponseStatus.RS_COMPLETED,
        blocks: [
          Block(prefix: dummyBlock.cid.toPrefixBytes(), data: dummyBlock.data),
        ],
      );
      await capturedHandler(
        NetworkPacket(
          srcPeerId: peer,
          datagram: responseMessage.writeToBuffer(),
        ),
      );

      final blocks = await future;
      expect(blocks, hasLength(1));
      expect(blocks.first.data, equals(dummyBlock.data));
    });

    test('bidirectional pause pauses server-side request', () async {
      final capturedHandler = await captureHandler();

      final dummyBlock = await makeBlock(Uint8List.fromList([4, 5, 6]));
      final rootCid = dummyBlock.cid;
      final selector = ipld.ExploreAll(next: ipld.Matcher());
      final request = GraphsyncRequest()
        ..id = 8
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

      // Ensure the server accepted the request and is waiting on the stream.
      final allCalls = <Uint8List>[];
      void collectCalls() {
        allCalls.addAll(
          verify(
            mockRouter.sendMessage(
              'peerA',
              captureAny,
              protocolId: anyNamed('protocolId'),
            ),
          ).captured.cast<Uint8List>(),
        );
      }

      collectCalls();
      expect(allCalls, isNotEmpty);
      final acceptance = GraphsyncMessage.fromBuffer(allCalls.first);
      expect(
        acceptance.responses.first.status,
        equals(ResponseStatus.RS_IN_PROGRESS),
      );

      // Send a pause update from the peer.
      final pauseMsg = GraphsyncMessage()
        ..requests.add(
          GraphsyncRequest()
            ..id = 8
            ..pause = true,
        );
      await capturedHandler(
        NetworkPacket(srcPeerId: 'peerA', datagram: pauseMsg.writeToBuffer()),
      );
      collectCalls();
      final pauseResponse = GraphsyncMessage.fromBuffer(allCalls.last);
      expect(
        pauseResponse.responses.first.status,
        equals(ResponseStatus.RS_PAUSED),
      );

      // Send an unpause update and let the stream complete.
      final unpauseMsg = GraphsyncMessage()
        ..requests.add(
          GraphsyncRequest()
            ..id = 8
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

      collectCalls();
      final unpauseResponse = GraphsyncMessage.fromBuffer(
        allCalls[allCalls.length - 2],
      );
      expect(
        unpauseResponse.responses.first.status,
        equals(ResponseStatus.RS_IN_PROGRESS),
      );

      final lastResponse = GraphsyncMessage.fromBuffer(allCalls.last);
      expect(
        lastResponse.responses.first.status,
        equals(ResponseStatus.RS_COMPLETED),
      );
    });

    test('stop cleans up pending requests', () async {
      await handler.start();
      const peer = 'peerC';
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
      final errors = <Object>{};
      stream.listen(null, onError: errors.add);
      await pumpEventQueue();

      await handler.stop();
      await pumpEventQueue();

      final status = await handler.getStatus();
      expect(status['running'], isFalse);
      expect(status['client_requests'], equals(0));
      expect(errors, isNotEmpty);
      expect(errors.first, isA<GraphsyncError>());
    });
  });
}

Future<void> pumpEventQueue() async {
  await Future<void>.delayed(Duration.zero);
}
