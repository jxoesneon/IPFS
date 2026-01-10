import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/data_structures/pin_manager.dart';
import 'package:dart_ipfs/src/proto/generated/core/block.pb.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart';
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart';
import 'package:dart_ipfs/src/services/gateway/gateway_handler.dart';
import 'package:fixnum/fixnum.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

// Mock BlockStore
class MockBlockStore implements BlockStore {
  final Map<String, Block> blocks = {};

  @override
  Future<GetBlockResponse> getBlock(String cid) async {
    if (blocks.containsKey(cid)) {
      final b = blocks[cid]!;
      final blockProto = BlockProto()
        ..cid = b.cid.toProto()
        ..data = b.data;
      return GetBlockResponse()
        ..found = true
        ..block = blockProto;
    }
    return GetBlockResponse()..found = false;
  }

  // Stubs
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  String get path => '';
  @override
  Future<List<Block>> getAllBlocks() async => [];
  @override
  Future<bool> hasBlock(String cid) async => blocks.containsKey(cid);
  @override
  Future<AddBlockResponse> putBlock(Block block) async {
    blocks[block.cid.encode()] = block;
    return AddBlockResponse();
  }

  @override
  Future<RemoveBlockResponse> removeBlock(String cid) async =>
      RemoveBlockResponse();
  @override
  Future<Map<String, dynamic>> getStatus() async => {};
  @override
  PinManager get pinManager => throw UnimplementedError('Mock');
}

void main() {
  group('GatewayHandler', () {
    late MockBlockStore blockStore;
    late GatewayHandler handler;

    setUp(() {
      blockStore = MockBlockStore();
      handler = GatewayHandler(blockStore);
    });

    test('handlePath returns 404 for missing block', () async {
      // Use a valid CID string even if missing in store
      final cid = CID.computeForDataSync(Uint8List(0));
      final request = Request(
        'GET',
        Uri.parse('http://localhost:8080/ipfs/${cid.encode()}'),
      );
      final response = await handler.handlePath(request);
      expect(response.statusCode, 404);
      expect(await response.readAsString(), 'Block not found');
    });

    test('handlePath serves raw block if not UnixFS', () async {
      final data = Uint8List.fromList(utf8.encode('Hello Raw World'));
      final cid = CID.computeForDataSync(data, codec: 'raw');
      final cidStr = cid.encode();

      final block = Block(cid: cid, data: data);
      blockStore.blocks[cidStr] = block;

      final request = Request(
        'GET',
        Uri.parse('http://localhost:8080/ipfs/$cidStr'),
      );
      final response = await handler.handlePath(request);

      expect(response.statusCode, 200);
      expect(
        response.headers['Content-Type'],
        'application/octet-stream',
      ); // Fallback for raw/unknown
      expect(await response.readAsString(), 'Hello Raw World');
    });

    test('handlePath serves UnixFS File', () async {
      final content = Uint8List.fromList(utf8.encode('Hello UnixFS'));

      // Create UnixFS Data
      final unixHeader = Data()
        ..type = Data_DataType.File
        ..data = content
        ..filesize = Int64(content.length);

      // Create DAG-PB Node
      final pbNode = PBNode()..data = unixHeader.writeToBuffer();

      final blockData = pbNode.writeToBuffer();
      final cid = CID.computeForDataSync(blockData, codec: 'dag-pb');
      final cidStr = cid.encode();

      final block = Block(cid: cid, data: blockData);
      blockStore.blocks[cidStr] = block;

      final request = Request(
        'GET',
        Uri.parse('http://localhost:8080/ipfs/$cidStr'),
      );
      final response = await handler.handlePath(request);

      expect(response.statusCode, 200);
      expect(response.headers['Content-Type'], contains('text/plain'));
      expect(await response.readAsString(), 'Hello UnixFS');
    });

    test('handlePath serves range request', () async {
      final content = Uint8List.fromList(utf8.encode('0123456789')); // 10 bytes

      final unixHeader = Data()
        ..type = Data_DataType.File
        ..data = content;
      final pbNode = PBNode()..data = unixHeader.writeToBuffer();
      final blockData = pbNode.writeToBuffer();

      final cid = CID.computeForDataSync(blockData, codec: 'dag-pb');
      final cidStr = cid.encode();

      blockStore.blocks[cidStr] = Block(cid: cid, data: blockData);

      final request = Request(
        'GET',
        Uri.parse('http://localhost:8080/ipfs/$cidStr'),
        headers: {'range': 'bytes=2-5'},
      );
      final response = await handler.handlePath(request);

      expect(response.statusCode, 206);
      expect(response.headers['Content-Range'], 'bytes 2-5/10');
      expect(await response.readAsString(), '2345');
    });

    test('handlePath renders Directory', () async {
      // Create Link Target
      final fileContent = utf8.encode('file content');
      final fileHeader = Data()
        ..type = Data_DataType.File
        ..data = fileContent;
      final fileNode = PBNode()..data = fileHeader.writeToBuffer();
      final fileData = fileNode.writeToBuffer();
      final fileCid = CID.computeForDataSync(fileData, codec: 'dag-pb');

      blockStore.blocks[fileCid.encode()] = Block(cid: fileCid, data: fileData);

      // Create Link
      final pbLink = PBLink()
        ..name = 'testfile.txt'
        ..size = Int64(fileData.length)
        ..hash = fileCid.toBytes();

      // Setup Directory block
      final unixHeader = Data()..type = Data_DataType.Directory;
      final pbNode = PBNode()
        ..data = unixHeader.writeToBuffer()
        ..links.add(pbLink);

      final dirData = pbNode.writeToBuffer();
      final dirCid = CID.computeForDataSync(dirData, codec: 'dag-pb');
      final dirCidStr = dirCid.encode();

      blockStore.blocks[dirCidStr] = Block(cid: dirCid, data: dirData);

      final request = Request(
        'GET',
        Uri.parse('http://localhost:8080/ipfs/$dirCidStr'),
      );
      final response = await handler.handlePath(request);

      expect(response.statusCode, 200);
      expect(response.headers['Content-Type'], contains('text/html'));
      final body = await response.readAsString();
      expect(body, contains('Index of /ipfs/$dirCidStr'));
      expect(body, contains('testfile.txt'));
    });

    test('handlePath navigates directory to subpath', () async {
      // Target File
      final fileContent = utf8.encode('SubContent');
      final fileHeader = Data()
        ..type = Data_DataType.File
        ..data = fileContent;
      final fileNode = PBNode()..data = fileHeader.writeToBuffer();
      final fileData = fileNode.writeToBuffer();
      final fileCid = CID.computeForDataSync(fileData, codec: 'dag-pb');

      blockStore.blocks[fileCid.encode()] = Block(cid: fileCid, data: fileData);

      // Root Dir with link
      final pbLink = PBLink()
        ..name = 'subdir'
        ..hash = fileCid.toBytes();

      final dirHeader = Data()..type = Data_DataType.Directory;
      final dirNode = PBNode()
        ..data = dirHeader.writeToBuffer()
        ..links.add(pbLink);
      final dirData = dirNode.writeToBuffer();
      final dirCid = CID.computeForDataSync(dirData, codec: 'dag-pb');

      blockStore.blocks[dirCid.encode()] = Block(cid: dirCid, data: dirData);

      // Note: the link name is "subdir", but the test expects "SubContent".
      // If we request /ipfs/Root/subdir, it should resolve to the fileCid and serve SubContent.

      final request = Request(
        'GET',
        Uri.parse('http://localhost:8080/ipfs/${dirCid.encode()}/subdir'),
      );
      final response = await handler.handlePath(request);

      expect(response.statusCode, 200);
      expect(await response.readAsString(), 'SubContent');
    });

    test('handlePath resolves IPNS name', () async {
      // Mock resolver function
      Future<String> mockResolver(String name) async {
        if (name == 'k51qzi5uqu5dlvj2baxnqnds23059p5483n5m8t4s6p7j7j2j') {
          // Resolve to a CID that exists in our mock store
          final data = utf8.encode('Resolved Content');
          final cid = CID.computeForDataSync(data);

          await blockStore.putBlock(
            Block(cid: cid, data: Uint8List.fromList(data)),
          );
          return cid.encode();
        }
        throw Exception('Not found');
      }

      // Re-create handler with resolver
      handler = GatewayHandler(blockStore, ipnsResolver: mockResolver);

      final validName = 'k51qzi5uqu5dlvj2baxnqnds23059p5483n5m8t4s6p7j7j2j';
      final request = Request(
        'GET',
        Uri.parse('http://localhost:8080/ipns/$validName'),
      );

      final response = await handler.handlePath(request);

      expect(response.statusCode, 200);
      expect(await response.readAsString(), 'Resolved Content');
    });

    test('handlePath returns 404 for unknown IPNS name', () async {
      handler = GatewayHandler(
        blockStore,
        ipnsResolver: (name) async => throw Exception('Failed'),
      );

      final request = Request(
        'GET',
        Uri.parse('http://localhost:8080/ipns/unknown'),
      );

      final response = await handler.handlePath(request);
      expect(response.statusCode, 404);
    });
  });
}
