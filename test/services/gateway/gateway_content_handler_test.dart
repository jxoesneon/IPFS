// test/services/gateway/gateway_content_handler_test.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/dart_ipfs.dart' hide CID, Block, IBlockStore;
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/interfaces/i_block_store.dart';
import 'package:dart_ipfs/src/core/responses/block_response_factory.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_directory.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart';
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart';
import 'package:dart_ipfs/src/services/gateway/gateway_content_handler.dart';
import 'package:dart_ipfs/src/services/gateway/gateway_directory_handler.dart';
import 'package:fixnum/fixnum.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'gateway_handler_test.mocks.dart';

class _MemoryBlockStore implements BlockStore {
  final _blocks = <String, Block>{};

  @override
  Future<GetBlockResponse> getBlock(String cid) async {
    final block = _blocks[cid];
    if (block == null) return BlockResponseFactory.notFound();
    return BlockResponseFactory.successGet(block.toProto());
  }

  @override
  Future<AddBlockResponse> putBlock(Block block) async {
    _blocks[block.cid.encode()] = block;
    return BlockResponseFactory.successAdd('ok');
  }

  @override
  Future<bool> hasBlock(String cid) async => _blocks.containsKey(cid);

  @override
  Future<RemoveBlockResponse> removeBlock(String cid) async {
    _blocks.remove(cid);
    return BlockResponseFactory.successRemove('ok');
  }

  @override
  Future<Map<String, dynamic>> getStatus() async => {'count': _blocks.length};

  @override
  Future<List<Block>> getAllBlocks() async => _blocks.values.toList();

  @override
  Future<int> gc() async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

@GenerateNiceMocks([MockSpec<BlockStore>()])
void main() {
  late MockBlockStore mockBlockStore;
  late GatewayDirectoryHandler directoryHandler;
  late GatewayContentHandler contentHandler;

  setUp(() {
    mockBlockStore = MockBlockStore();
    directoryHandler = GatewayDirectoryHandler();
    contentHandler = GatewayContentHandler(
      blockStore: mockBlockStore,
      directoryHandler: directoryHandler,
    );
  });

  group('GatewayContentHandler', () {
    group('serveContent', () {
      test('returns 404 when block not found', () async {
        when(
          mockBlockStore.getBlock(any),
        ).thenAnswer((_) async => GetBlockResponse()..found = false);

        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/QmTest'),
        );
        final response = await contentHandler.serveContent(
          'QmTest',
          '',
          request,
        );

        expect(response.statusCode, equals(404));
      });

      test('serves raw block when not UnixFS', () async {
        final cidStr = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
        final data = Uint8List.fromList([1, 2, 3, 4, 5]);
        final block = Block(cid: CID.decode(cidStr), data: data);

        when(mockBlockStore.getBlock(cidStr)).thenAnswer(
          (_) async => GetBlockResponse()
            ..found = true
            ..block = block.toProto(),
        );

        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr'),
        );
        final response = await contentHandler.serveContent(cidStr, '', request);

        expect(response.statusCode, equals(200));
        expect(
          response.headers['content-type'],
          equals('application/octet-stream'),
        );
        final body = await response.read().expand((i) => i).toList();
        expect(body, equals(data));
      });

      test('serves UnixFS file with correct content type', () async {
        final cidStr = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
        final fileData = Uint8List.fromList(utf8.encode('Hello World'));
        final unixfsData = Data()
          ..type = Data_DataType.File
          ..data = fileData;
        final pbNode = PBNode()..data = unixfsData.writeToBuffer();
        final block = Block(
          cid: CID.decode(cidStr),
          data: pbNode.writeToBuffer(),
        );

        when(mockBlockStore.getBlock(cidStr)).thenAnswer(
          (_) async => GetBlockResponse()
            ..found = true
            ..block = block.toProto(),
        );

        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr'),
        );
        final response = await contentHandler.serveContent(cidStr, '', request);

        expect(response.statusCode, equals(200));
        expect(
          response.headers['content-type'],
          equals('text/plain; charset=utf-8'),
        );
        final body = await response.read().expand((i) => i).toList();
        expect(body, equals(fileData));
      });

      test('serves directory listing for UnixFS directory', () async {
        final cidStr = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
        final unixfsData = Data()..type = Data_DataType.Directory;
        final pbNode = PBNode()..data = unixfsData.writeToBuffer();
        final block = Block(
          cid: CID.decode(cidStr),
          data: pbNode.writeToBuffer(),
        );

        when(mockBlockStore.getBlock(cidStr)).thenAnswer(
          (_) async => GetBlockResponse()
            ..found = true
            ..block = block.toProto(),
        );

        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr'),
        );
        final response = await contentHandler.serveContent(cidStr, '', request);

        expect(response.statusCode, equals(200));
        expect(
          response.headers['content-type'],
          equals('text/html; charset=utf-8'),
        );
        final body = await response.readAsString();
        expect(body, contains('Index of /ipfs/$cidStr'));
      });
    });

    group('serveContent with range requests', () {
      test('handles range request on raw block', () async {
        final cidStr = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
        final data = Uint8List.fromList(List.generate(10, (i) => i));
        final block = Block(cid: CID.decode(cidStr), data: data);

        when(mockBlockStore.getBlock(cidStr)).thenAnswer(
          (_) async => GetBlockResponse()
            ..found = true
            ..block = block.toProto(),
        );

        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr'),
          headers: {'range': 'bytes=2-5'},
        );
        final response = await contentHandler.serveContent(cidStr, '', request);

        expect(response.statusCode, equals(206));
        expect(response.headers['content-range'], equals('bytes 2-5/10'));
        final body = await response.read().expand((i) => i).toList();
        expect(body, equals([2, 3, 4, 5]));
      });

      test('returns 416 for invalid range format', () async {
        final cidStr = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
        final data = Uint8List.fromList([1, 2, 3]);
        final block = Block(cid: CID.decode(cidStr), data: data);

        when(mockBlockStore.getBlock(cidStr)).thenAnswer(
          (_) async => GetBlockResponse()
            ..found = true
            ..block = block.toProto(),
        );

        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr'),
          headers: {'range': 'invalid'},
        );
        final response = await contentHandler.serveContent(cidStr, '', request);

        expect(response.statusCode, equals(416));
      });

      test('returns 416 for range beyond data length', () async {
        final cidStr = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
        final data = Uint8List.fromList([1, 2, 3]);
        final block = Block(cid: CID.decode(cidStr), data: data);

        when(mockBlockStore.getBlock(cidStr)).thenAnswer(
          (_) async => GetBlockResponse()
            ..found = true
            ..block = block.toProto(),
        );

        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr'),
          headers: {'range': 'bytes=10-20'},
        );
        final response = await contentHandler.serveContent(cidStr, '', request);

        expect(response.statusCode, equals(416));
      });

      test('handles open-ended range (start only)', () async {
        final cidStr = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
        final data = Uint8List.fromList(List.generate(10, (i) => i));
        final block = Block(cid: CID.decode(cidStr), data: data);

        when(mockBlockStore.getBlock(cidStr)).thenAnswer(
          (_) async => GetBlockResponse()
            ..found = true
            ..block = block.toProto(),
        );

        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr'),
          headers: {'range': 'bytes=5-'},
        );
        final response = await contentHandler.serveContent(cidStr, '', request);

        expect(response.statusCode, equals(206));
        final body = await response.read().expand((i) => i).toList();
        expect(body, equals([5, 6, 7, 8, 9]));
      });
    });

    group('getBlockByCid', () {
      test('returns block from blockstore when found', () async {
        final cidStr = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
        final block = Block(
          cid: CID.decode(cidStr),
          data: Uint8List.fromList([1]),
        );

        when(mockBlockStore.getBlock(cidStr)).thenAnswer(
          (_) async => GetBlockResponse()
            ..found = true
            ..block = block.toProto(),
        );

        final result = await contentHandler.getBlockByCid(cidStr);
        expect(result, isNotNull);
        expect(result!.data, equals([1]));
      });

      test('returns null when block not found and no bitswap', () async {
        when(
          mockBlockStore.getBlock(any),
        ).thenAnswer((_) async => GetBlockResponse()..found = false);

        final result = await contentHandler.getBlockByCid('QmNotFound');
        expect(result, isNull);
      });

      test('handles blockstore exception gracefully', () async {
        when(
          mockBlockStore.getBlock(any),
        ).thenThrow(Exception('Storage error'));

        final result = await contentHandler.getBlockByCid('QmError');
        expect(result, isNull);
      });
    });

    group('resolveSubPath', () {
      test('returns root block when subPath is empty', () async {
        final cidStr = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
        final block = Block(
          cid: CID.decode(cidStr),
          data: Uint8List.fromList([1]),
        );

        when(mockBlockStore.getBlock(cidStr)).thenAnswer(
          (_) async => GetBlockResponse()
            ..found = true
            ..block = block.toProto(),
        );

        final (cid, resultBlock) = await contentHandler.resolveSubPath(
          CID.decode(cidStr),
          '',
        );
        expect(cid.encode(), equals(cidStr));
        expect(resultBlock, isNotNull);
      });

      test('returns null block when root not found', () async {
        when(
          mockBlockStore.getBlock(any),
        ).thenAnswer((_) async => GetBlockResponse()..found = false);

        final (cid, resultBlock) = await contentHandler.resolveSubPath(
          CID.decode('QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn'),
          'sub/path',
        );
        expect(resultBlock, isNull);
      });
    });

    group('index.html resolution', () {
      test('serves index.html content when directory contains it', () async {
        final store = _MemoryBlockStore();
        final fileData = Uint8List.fromList(utf8.encode('<h1>Index</h1>'));
        final fileUnixfsData = Data()
          ..type = Data_DataType.File
          ..data = fileData;
        final filePbNode = PBNode()..data = fileUnixfsData.writeToBuffer();
        final fileCid = await CID.fromContent(
          filePbNode.writeToBuffer(),
          codec: 'dag-pb',
        );
        await store.putBlock(
          Block(
            cid: fileCid,
            data: filePbNode.writeToBuffer(),
            format: 'dag-pb',
          ),
        );

        final dirData = Data()..type = Data_DataType.Directory;
        final dirPbNode = PBNode()
          ..data = dirData.writeToBuffer()
          ..links.add(
            PBLink()
              ..name = 'index.html'
              ..size = Int64(fileData.length)
              ..hash = Uint8List.fromList(fileCid.toBytes()),
          );
        final dirCid = await CID.fromContent(
          dirPbNode.writeToBuffer(),
          codec: 'dag-pb',
        );
        await store.putBlock(
          Block(cid: dirCid, data: dirPbNode.writeToBuffer(), format: 'dag-pb'),
        );

        final handler = GatewayContentHandler(
          blockStore: store,
          directoryHandler: GatewayDirectoryHandler(),
        );
        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/${dirCid.encode()}'),
        );
        final response = await handler.serveContent(
          dirCid.encode(),
          '',
          request,
        );

        expect(response.statusCode, equals(200));
        // Should serve the file content, not the directory listing.
        final body = await response.read().expand((i) => i).toList();
        expect(body, equals(fileData));
        expect(utf8.decode(body), isNot(contains('Index of')));
      });
    });

    group('HAMT directory rendering', () {
      test('renders directory listing for HAMT shard root', () async {
        final store = _MemoryBlockStore();
        final entries = <UnixFSDirectoryEntry>[];
        for (var i = 0; i < 100; i++) {
          final data = Uint8List.fromList([i]);
          final cid = await CID.fromContent(data, codec: 'raw');
          await store.putBlock(Block(cid: cid, data: data));
          entries.add(
            UnixFSDirectoryEntry(name: 'file_$i.txt', cid: cid, tsize: 1),
          );
        }
        final dirNode = await createDirectory(
          store,
          entries,
          cidVersion: 1,
          shardThreshold: 32,
        );

        final handler = GatewayContentHandler(
          blockStore: store,
          directoryHandler: GatewayDirectoryHandler(),
        );
        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/${dirNode.cid.encode()}'),
        );
        final response = await handler.serveContent(
          dirNode.cid.encode(),
          '',
          request,
        );

        expect(response.statusCode, equals(200));
        expect(
          response.headers['content-type'],
          equals('text/html; charset=utf-8'),
        );
        final body = await response.readAsString();
        expect(body, contains('Index of'));
      });

      test('resolves sub-path in HAMT-sharded directory', () async {
        final store = _MemoryBlockStore();
        final entries = <UnixFSDirectoryEntry>[];
        for (var i = 0; i < 100; i++) {
          final data = Uint8List.fromList([i]);
          final cid = await CID.fromContent(data, codec: 'raw');
          await store.putBlock(Block(cid: cid, data: data));
          entries.add(
            UnixFSDirectoryEntry(name: 'file_$i.txt', cid: cid, tsize: 1),
          );
        }
        final dirNode = await createDirectory(
          store,
          entries,
          cidVersion: 1,
          shardThreshold: 32,
        );

        final handler = GatewayContentHandler(
          blockStore: store,
          directoryHandler: GatewayDirectoryHandler(),
        );
        final request = Request(
          'GET',
          Uri.parse(
            'http://localhost/ipfs/${dirNode.cid.encode()}/file_42.txt',
          ),
        );
        final response = await handler.serveContent(
          dirNode.cid.encode(),
          'file_42.txt',
          request,
        );

        expect(response.statusCode, equals(200));
        final body = await response.read().expand((i) => i).toList();
        expect(body, equals([42]));
      });
    });
  });
}
