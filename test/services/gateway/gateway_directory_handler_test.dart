// test/services/gateway/gateway_directory_handler_test.dart
import 'dart:typed_data';

import 'package:dart_ipfs/dart_ipfs.dart' hide CID, Block, IBlockStore;
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/interfaces/i_block_store.dart';
import 'package:dart_ipfs/src/core/responses/block_response_factory.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_directory.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_hamt.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart'
    show PBNode, PBLink;
import 'package:dart_ipfs/src/services/gateway/gateway_directory_handler.dart';
import 'package:fixnum/fixnum.dart' show Int64;
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

class _MemoryBlockStore implements IBlockStore {
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
  Future<RemoveBlockResponse> removeBlock(String cid) async {
    _blocks.remove(cid);
    return BlockResponseFactory.successRemove('ok');
  }

  @override
  Future<bool> hasBlock(String cid) async => _blocks.containsKey(cid);

  @override
  Future<List<Block>> getAllBlocks() async => _blocks.values.toList();

  @override
  Future<Map<String, dynamic>> getStatus() async => {'count': _blocks.length};

  @override
  Future<int> gc() async => 0;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}

void main() {
  late GatewayDirectoryHandler handler;

  final cidStr = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
  final childCid = CID.decode('QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG');

  setUp(() {
    handler = GatewayDirectoryHandler();
  });

  group('GatewayDirectoryHandler', () {
    group('renderDirectory', () {
      test('renders HTML with correct title and headers', () async {
        final pbNode = PBNode();

        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr'),
        );
        final response = handler.renderDirectory(cidStr, pbNode, request);

        expect(response.statusCode, equals(200));
        expect(
          response.headers['content-type'],
          equals('text/html; charset=utf-8'),
        );
        expect(response.headers['x-ipfs-path'], equals('/ipfs/$cidStr'));
        final body = await response.readAsString();
        expect(body, contains('<!DOCTYPE html>'));
        expect(body, contains('Index of /ipfs/$cidStr'));
      });

      test('renders links for directory entries', () async {
        final link = PBLink()
          ..name = 'file.txt'
          ..size = Int64(1024)
          ..hash = childCid.toBytes();
        final pbNode = PBNode()..links.add(link);

        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr'),
        );
        final response = handler.renderDirectory(cidStr, pbNode, request);
        final body = await response.readAsString();

        expect(body, contains('file.txt'));
        expect(body, contains('/ipfs/${childCid.encode()}'));
        expect(body, contains('1.0 KB'));
      });

      test('escapes HTML in file names to prevent XSS', () async {
        final link = PBLink()
          ..name = '<script>alert("xss")</script>'
          ..size = Int64(0)
          ..hash = childCid.toBytes();
        final pbNode = PBNode()..links.add(link);

        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr'),
        );
        final response = handler.renderDirectory(cidStr, pbNode, request);
        final body = await response.readAsString();

        expect(body, isNot(contains('<script>alert')));
        expect(body, contains('&lt;script&gt;'));
      });

      test('formats sizes correctly', () async {
        final sizes = [
          (512, '512 B'),
          (2048, '2.0 KB'),
          (1048576, '1.0 MB'),
          (1073741824, '1.0 GB'),
        ];

        for (final (size, expected) in sizes) {
          final link = PBLink()
            ..name = 'file_$size'
            ..size = Int64(size)
            ..hash = childCid.toBytes();
          final pbNode = PBNode()..links.add(link);

          final request = Request(
            'GET',
            Uri.parse('http://localhost/ipfs/$cidStr'),
          );
          final response = handler.renderDirectory(cidStr, pbNode, request);
          final body = await response.readAsString();

          expect(body, contains(expected));
        }
      });
    });

    group('navigateDirectory', () {
      test('returns 404 when path not found', () async {
        final pbNode = PBNode();

        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr/missing'),
        );
        final response = await handler.navigateDirectory(
          cidStr,
          pbNode,
          'missing',
          request,
          serveContentCallback: (_, __, ___) async => Response.ok('callback'),
        );

        expect(response.statusCode, equals(404));
        expect(
          await response.readAsString(),
          contains('Path not found: missing'),
        );
      });

      test('calls serveContentCallback for matching link', () async {
        final link = PBLink()
          ..name = 'myfile'
          ..size = Int64(100)
          ..hash = childCid.toBytes();
        final pbNode = PBNode()..links.add(link);

        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr/myfile'),
        );
        String? calledCidStr;
        String? calledSubPath;

        final response = await handler.navigateDirectory(
          cidStr,
          pbNode,
          'myfile',
          request,
          serveContentCallback: (cid, subPath, req) async {
            calledCidStr = cid;
            calledSubPath = subPath;
            return Response.ok('served');
          },
        );

        expect(response.statusCode, equals(200));
        expect(await response.readAsString(), equals('served'));
        expect(calledCidStr, equals(childCid.encode()));
        expect(calledSubPath, equals(''));
      });

      test('passes remaining path to callback for nested navigation', () async {
        final link = PBLink()
          ..name = 'dir'
          ..size = Int64(0)
          ..hash = childCid.toBytes();
        final pbNode = PBNode()..links.add(link);

        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr/dir/subfile'),
        );
        String? calledSubPath;

        await handler.navigateDirectory(
          cidStr,
          pbNode,
          'dir/subfile',
          request,
          serveContentCallback: (cid, subPath, req) async {
            calledSubPath = subPath;
            return Response.ok('ok');
          },
        );

        expect(calledSubPath, equals('subfile'));
      });
    });

    group('findChildCid', () {
      test('returns null for non-dag-pb codec', () async {
        final cid = CID.v1('raw', CID.decode(cidStr).multihash);
        final block = Block(cid: cid, data: Uint8List(0));

        final result = await handler.findChildCid(block, 'test');
        expect(result, isNull);
      });

      test('returns CID for matching link name', () async {
        final link = PBLink()
          ..name = 'target'
          ..size = Int64(0)
          ..hash = childCid.toBytes();
        final pbNode = PBNode()..links.add(link);
        final parentCid = CID.decode(cidStr);
        final block = Block(cid: parentCid, data: pbNode.writeToBuffer());

        final result = await handler.findChildCid(block, 'target');
        expect(result, isNotNull);
        expect(result!.encode(), equals(childCid.encode()));
      });

      test('returns null when link name does not match', () async {
        final link = PBLink()
          ..name = 'other'
          ..size = Int64(0)
          ..hash = childCid.toBytes();
        final pbNode = PBNode()..links.add(link);
        final parentCid = CID.decode(cidStr);
        final block = Block(cid: parentCid, data: pbNode.writeToBuffer());

        final result = await handler.findChildCid(block, 'target');
        expect(result, isNull);
      });

      test('returns null for invalid DAG-PB data', () async {
        final parentCid = CID.decode(cidStr);
        final block = Block(
          cid: parentCid,
          data: Uint8List.fromList([0xFF, 0xFF, 0xFF]),
        );

        final result = await handler.findChildCid(block, 'test');
        expect(result, isNull);
      });
    });

    group('renderDirectory extras', () {
      test(
        'includes parent directory link when parentPath is provided',
        () async {
          final pbNode = PBNode();
          final request = Request(
            'GET',
            Uri.parse('http://localhost/ipfs/$cidStr'),
          );
          final response = handler.renderDirectory(
            cidStr,
            pbNode,
            request,
            parentPath: '/ipfs/$cidStr',
          );
          final body = await response.readAsString();

          expect(body, contains('../'));
          expect(body, contains('/ipfs/$cidStr'));
        },
      );

      test('findIndexHtml returns CID for index.html child', () async {
        final link = PBLink()
          ..name = 'index.html'
          ..size = Int64(100)
          ..hash = childCid.toBytes();
        final pbNode = PBNode()..links.add(link);

        final result = handler.findIndexHtml(pbNode);
        expect(result, isNotNull);
        expect(result!.encode(), equals(childCid.encode()));
      });

      test('findIndexHtml returns null when no index.html child', () async {
        final pbNode = PBNode();
        expect(handler.findIndexHtml(pbNode), isNull);
      });
    });

    group('HAMT directory navigation', () {
      late _MemoryBlockStore store;

      setUp(() {
        store = _MemoryBlockStore();
      });

      Future<CID> _addRaw(String name, List<int> data) async {
        final cid = await CID.fromContent(
          Uint8List.fromList(data),
          codec: 'raw',
        );
        await store.putBlock(Block(cid: cid, data: Uint8List.fromList(data)));
        return cid;
      }

      Future<(CID, Block)> _buildShardedDirectory() async {
        final entries = <UnixFSDirectoryEntry>[];
        for (var i = 0; i < 100; i++) {
          final cid = await _addRaw('file_$i.txt', [i]);
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
        final dirBlock = Block(cid: dirNode.cid, data: dirNode.data);
        return (dirNode.cid, dirBlock);
      }

      Future<Block?> _resolveBlock(String cidStr) async {
        final response = await store.getBlock(cidStr);
        if (!response.found) return null;
        return Block.fromProto(response.block);
      }

      test('findChildCid resolves entry in HAMT-sharded directory', () async {
        final (dirCid, dirBlock) = await _buildShardedDirectory();

        final result = await handler.findChildCid(
          dirBlock,
          'file_42.txt',
          resolveBlock: _resolveBlock,
        );

        expect(result, isNotNull);
        final expectedCid = await _addRaw('file_42.txt', [42]);
        expect(result!.encode(), equals(expectedCid.encode()));
      });

      test('findChildCid returns null for missing HAMT entry', () async {
        final (dirCid, dirBlock) = await _buildShardedDirectory();

        final result = await handler.findChildCid(
          dirBlock,
          'missing.txt',
          resolveBlock: _resolveBlock,
        );

        expect(result, isNull);
      });

      test('navigateDirectory resolves HAMT sub-path', () async {
        final (dirCid, dirBlock) = await _buildShardedDirectory();
        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/${dirCid.encode()}/file_42.txt'),
        );
        final expectedCid = await _addRaw('file_42.txt', [42]);
        final dirPbNode = PBNode.fromBuffer(dirBlock.data);

        String? calledCidStr;
        await handler.navigateDirectory(
          dirCid.encode(),
          dirPbNode,
          'file_42.txt',
          request,
          serveContentCallback: (cid, subPath, req) async {
            calledCidStr = cid;
            return Response.ok('ok');
          },
          resolveBlock: _resolveBlock,
        );

        expect(calledCidStr, equals(expectedCid.encode()));
      });
    });
  });
}
