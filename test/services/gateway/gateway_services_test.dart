import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/data_structures/pin_manager.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart'
    as blockstore_pb;
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart';
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart';
import 'package:dart_ipfs/src/services/gateway/gateway_handler.dart';
import 'package:fixnum/fixnum.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

// Mocks
class MockBlockStore implements BlockStore {
  final Map<String, Block> _storage = {};

  @override
  String get path => '/tmp/mock_blockstore';

  @override
  late final PinManager pinManager = PinManager(this);

  @override
  Future<blockstore_pb.AddBlockResponse> putBlock(Block block) async {
    _storage[block.cid.encode()] = block;
    return blockstore_pb.AddBlockResponse();
  }

  @override
  Future<blockstore_pb.GetBlockResponse> getBlock(String cid) async {
    if (_storage.containsKey(cid)) {
      return blockstore_pb.GetBlockResponse()
        ..found = true
        ..block = _storage[cid]!.toProto();
    }
    return blockstore_pb.GetBlockResponse()..found = false;
  }

  Future<void> deleteBlock(String cid) async {
    _storage.remove(cid);
  }

  Stream<String> get keys => Stream.fromIterable(_storage.keys);

  @override
  Future<bool> hasBlock(String cid) async {
    return _storage.containsKey(cid);
  }

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<List<Block>> getAllBlocks() async {
    return _storage.values.toList();
  }

  @override
  Future<Map<String, dynamic>> getStatus() async {
    return {
      'total_blocks': _storage.length,
      'total_size': _storage.values.fold(0, (sum, b) => sum + b.size),
      'pinned_blocks': 0,
    };
  }

  @override
  Future<blockstore_pb.RemoveBlockResponse> removeBlock(String cid) async {
    if (_storage.containsKey(cid)) {
      _storage.remove(cid);
      return blockstore_pb.RemoveBlockResponse()..success = true;
    }
    return blockstore_pb.RemoveBlockResponse()..success = false;
  }

  @override
  Future<int> gc() async => 0;

  @override
  Future<void> flush() async {}
}

void main() {
  group('GatewayHandler', () {
    late MockBlockStore mockBlockStore;
    late GatewayHandler gatewayHandler;

    setUp(() {
      mockBlockStore = MockBlockStore();
      gatewayHandler = GatewayHandler(mockBlockStore);
    });

    test('should serve text file', () async {
      final content = utf8.encode('Hello IPFS World');
      final block = await Block.fromData(
        Uint8List.fromList(content),
        format: 'raw',
      ); // Test raw first
      await mockBlockStore.putBlock(block);

      final request = Request(
        'GET',
        Uri.parse('http://localhost:8080/ipfs/${block.cid.encode()}'),
      );
      final response = await gatewayHandler.handlePath(request);

      expect(response.statusCode, equals(200));
      expect(await response.readAsString(), equals('Hello IPFS World'));
      expect(
        response.headers['X-IPFS-Path'],
        equals('/ipfs/${block.cid.encode()}'),
      );
    });

    test('should return 404 for missing block', () async {
      final missingCid = CID
          .computeForDataSync(
            Uint8List.fromList([0xde, 0xad, 0xbe, 0xef]),
            codec: 'raw',
          )
          .encode();
      final request = Request(
        'GET',
        Uri.parse('http://localhost:8080/ipfs/$missingCid'),
      );
      final response = await gatewayHandler.handlePath(request);

      expect(response.statusCode, equals(404));
    });

    // ... class definitions ...

    test('should handle range request', () async {
      final content = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
      // Create UnixFS block
      final unixFsData = Data()
        ..type = Data_DataType.File
        ..data = content
        ..filesize = Int64(content.length);

      final pbNode = PBNode()..data = unixFsData.writeToBuffer();

      final block = await Block.fromData(
        pbNode.writeToBuffer(),
        format: 'dag-pb',
      );

      await mockBlockStore.putBlock(block);

      final request = Request(
        'GET',
        Uri.parse('http://localhost:8080/ipfs/${block.cid.encode()}'),
        headers: {'range': 'bytes=2-5'},
      );
      final response = await gatewayHandler.handlePath(request);

      expect(response.statusCode, equals(206));
      final bytes = await response.read().reduce((a, b) => [...a, ...b]);
      expect(bytes, equals([2, 3, 4, 5]));
      expect(response.headers['Content-Range'], equals('bytes 2-5/10'));
    });
  });
}
