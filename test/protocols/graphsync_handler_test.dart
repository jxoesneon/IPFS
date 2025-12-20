import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/utils/base58.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart'
    as core_block; // generic
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart'; // interface
import 'package:dart_ipfs/src/core/ipfs_node/ipld_handler.dart';
import 'package:dart_ipfs/src/core/ipld/selectors/ipld_selector.dart';
import 'package:dart_ipfs/src/core/responses/block_response_factory.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart'; // for responses
import 'package:dart_ipfs/src/proto/generated/graphsync/graphsync.pb.dart'
    as proto;
import 'package:dart_ipfs/src/protocols/bitswap/bitswap_handler.dart';
import 'package:dart_ipfs/src/protocols/graphsync/graphsync_handler.dart';
import 'package:dart_ipfs/src/protocols/graphsync/graphsync_protocol.dart';
import 'package:dart_ipfs/src/transport/p2plib_router.dart';
import 'package:dart_ipfs/src/transport/router_events.dart'; // For NetworkPacket
import 'package:p2plib/p2plib.dart' as p2p;
import 'package:test/test.dart';

// Mocks

class MockConfig extends IPFSConfig {
  MockConfig() : super();
}

class MockRouter implements P2plibRouter {
  final Map<String, void Function(NetworkPacket)> handlers = {};
  final List<List<int>> sentMessages = [];

  @override
  void registerProtocol(String protocolId) {}

  @override
  void registerProtocolHandler(
    String protocolId,
    void Function(NetworkPacket) handler,
  ) {
    handlers[protocolId] = handler;
  }

  // Custom mock method for broadcast
  @override
  Future<void> broadcastMessage(String protocolId, List<int> data) async {
    sentMessages.add(data);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockBitswap extends BitswapHandler {
  MockBitswap() : super(MockConfig(), MockBlockStore(), MockRouter());

  final Map<String, core_block.Block> blocks = {};

  @override
  Future<core_block.Block?> wantBlock(String cid) async {
    return blocks[cid];
  }
}

class MockBlockStore implements BlockStore {
  final Map<String, core_block.Block> stored = {};

  @override
  Future<bool> hasBlock(String cid) async => stored.containsKey(cid);

  @override
  Future<AddBlockResponse> putBlock(core_block.Block block) async {
    stored[block.cid.toString()] = block;
    return BlockResponseFactory.successAdd('ok');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockIPLD extends IPLDHandler {
  MockIPLD() : super(MockConfig(), MockBlockStore());

  @override
  Future<dynamic> get(CID cid) async {
    return 'RootNodeData'; // Helper to avoid null Check
  }

  @override
  Future<List<IPLDNode>> executeSelector(
    CID root,
    IPLDSelector selector,
  ) async {
    return []; // Empty results by default
  }
}

// Minimal dummy for result in executeSelector if needed
class IPLDNode {
  IPLDNode(this.cid);
  final CID cid;
}

void main() {
  group('GraphsyncHandler', () {
    late GraphsyncHandler handler;
    late MockRouter mockRouter;
    late MockBitswap mockBitswap;
    late MockBlockStore mockStore;
    late MockIPLD mockIPLD;

    setUp(() async {
      mockRouter = MockRouter();
      mockBitswap = MockBitswap();
      mockStore = MockBlockStore();
      mockIPLD = MockIPLD();

      handler = GraphsyncHandler(
        MockConfig(),
        mockRouter,
        mockBitswap,
        mockIPLD,
        mockStore,
      );

      await handler.start();
    });

    tearDown(() async {
      await handler.stop();
    });

    test('start registers protocol handler', () {
      expect(
        mockRouter.handlers.containsKey(GraphsyncProtocol.protocolID),
        isTrue,
      );
    });

    test('requestGraph sends request and calls bitswap', () async {
      final cid = CID.computeForDataSync(
        Uint8List.fromList([1, 2, 3]),
        codec: 'dag-pb',
      );
      final selector = IPLDSelector(type: SelectorType.all);

      // Setup bitswap response
      final block = core_block.Block(
        cid: cid,
        data: Uint8List.fromList([1, 2, 3]),
      );
      mockBitswap.blocks[cid.toString()] = block;

      final result = await handler.requestGraph(cid.toString(), selector);

      expect(result, isNotNull);
      // It returns proto.Block, check data
      expect(result!.data, equals(block.data));
      // Verify request broadcast
      expect(mockRouter.sentMessages, isNotEmpty);

      // Parse sent message to verify it's a Request
      final msg = proto.GraphsyncMessage.fromBuffer(
        mockRouter.sentMessages.first,
      );
      expect(msg.requests, isNotEmpty);
      expect(msg.requests.first.root, equals(cid.toBytes()));
    });

    test('handles cancel request by sending response', () async {
      final requestMsg = proto.GraphsyncMessage();
      requestMsg.requests.add(
        proto.GraphsyncRequest()
          ..id = 123
          ..cancel = true,
      );

      final packet = NetworkPacket(
        datagram: requestMsg.writeToBuffer(),
        srcPeerId: Base58().encode(Uint8List.fromList(List.filled(64, 1))),
      );

      // Manually trigger handler
      mockRouter.handlers[GraphsyncProtocol.protocolID]!(packet);

      // Expect response
      expect(mockRouter.sentMessages, isNotEmpty);
      final respMsg = proto.GraphsyncMessage.fromBuffer(
        mockRouter.sentMessages.last,
      );
      expect(respMsg.responses.first.id, 123);
      expect(respMsg.responses.first.status, proto.ResponseStatus.RS_CANCELLED);
    });
  });
}
