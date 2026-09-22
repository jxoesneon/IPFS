import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart' as dag_pb;
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart'
    as unixfs_pb;
import 'package:dart_ipfs/src/protocols/bitswap/bitswap_handler.dart';
import 'package:dart_ipfs/src/services/gateway/gateway_handler.dart';
import 'package:fixnum/fixnum.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:multibase/multibase.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'gateway_handler_test.mocks.dart';

@GenerateNiceMocks([MockSpec<BlockStore>()])
void main() {
  late GatewayHandler handler;
  late MockBlockStore mockBlockStore;

  setUp(() {
    mockBlockStore = MockBlockStore();
    handler = GatewayHandler(mockBlockStore);
  });

  group('GatewayHandler', () {
    test('handlePath ipfs root content', () async {
      final cidStr = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      final block = Block(
        cid: CID.decode(cidStr),
        data: Uint8List.fromList([1, 2, 3]),
      );

      final pbResp = GetBlockResponse()
        ..found = true
        ..block = block.toProto();
      when(mockBlockStore.getBlock(cidStr)).thenAnswer((_) async => pbResp);

      final request = Request(
        'GET',
        Uri.parse('http://localhost/ipfs/$cidStr'),
      );
      final response = await handler.handlePath(request);

      expect(response.statusCode, equals(200));
      final body = await response.read().expand((i) => i).toList();
      expect(body, equals([1, 2, 3]));
    });

    test('handlePath ipns', () async {
      handler = GatewayHandler(
        mockBlockStore,
        ipnsResolver: (name) async => 'QmResolved',
      );
      final request = Request(
        'GET',
        Uri.parse('http://localhost/ipns/test.local'),
      );

      // Should fail because QmResolved not in blockstore
      final pbResp = GetBlockResponse()..found = false;
      when(
        mockBlockStore.getBlock('QmResolved'),
      ).thenAnswer((_) async => pbResp);

      final response = await handler.handlePath(request);
      expect(response.statusCode, equals(404));
    });

    test('handleSubdomain', () async {
      final cidV0 = CID.decode(
        'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn',
      );
      final cidStr = CID
          .v1('dag-pb', cidV0.multihash, base: Multibase.base32)
          .encode();
      final request = Request(
        'GET',
        Uri.parse('http://localhost/'),
        headers: {'host': '$cidStr.ipfs.localhost'},
      );

      final pbResp = GetBlockResponse()
        ..found = true
        ..block = Block(cid: CID.decode(cidStr), data: Uint8List(0)).toProto();
      when(mockBlockStore.getBlock(cidStr)).thenAnswer((_) async => pbResp);

      final response = await handler.handleSubdomain(request);
      expect(response.statusCode, equals(200));
    });

    test('range request', () async {
      final cidStr = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      final data = Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
      final block = Block(cid: CID.decode(cidStr), data: data);

      final pbResp = GetBlockResponse()
        ..found = true
        ..block = block.toProto();
      when(mockBlockStore.getBlock(cidStr)).thenAnswer((_) async => pbResp);

      final request = Request(
        'GET',
        Uri.parse('http://localhost/ipfs/$cidStr'),
        headers: {'range': 'bytes=2-5'},
      );
      final response = await handler.handlePath(request);

      expect(response.statusCode, equals(206));
      final body = await response.read().expand((i) => i).toList();
      expect(body, equals([2, 3, 4, 5]));
    });

    test('handlePath invalid path', () async {
      final request = Request('GET', Uri.parse('http://localhost/invalid'));
      final response = await handler.handlePath(request);
      expect(response.statusCode, equals(404));
    });

    test('handlePath ipns disabled', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/ipns/test.local'),
      );
      final response = await handler.handlePath(request);
      expect(response.statusCode, equals(501));
    });

    test('handlePath ipns resolution failure', () async {
      handler = GatewayHandler(
        mockBlockStore,
        ipnsResolver: (name) async => throw Exception('Resolution failed'),
      );
      final request = Request(
        'GET',
        Uri.parse('http://localhost/ipns/test.local'),
      );
      final response = await handler.handlePath(request);
      expect(response.statusCode, equals(404));
    });

    test('handleSubdomain missing host header', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/'),
        headers: {},
      );
      final response = await handler.handleSubdomain(request);
      expect(response.statusCode, equals(400));
    });

    test('handleSubdomain invalid subdomain', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/'),
        headers: {'host': 'invalid.localhost'},
      );
      final response = await handler.handleSubdomain(request);
      expect(response.statusCode, equals(400));
    });

    test('handleSubdomain block not found', () async {
      final cidV0 = CID.decode(
        'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn',
      );
      final cidStr = CID
          .v1('dag-pb', cidV0.multihash, base: Multibase.base32)
          .encode();
      final request = Request(
        'GET',
        Uri.parse('http://localhost/'),
        headers: {'host': '$cidStr.ipfs.localhost'},
      );

      final pbResp = GetBlockResponse()..found = false;
      when(mockBlockStore.getBlock(cidStr)).thenAnswer((_) async => pbResp);

      final response = await handler.handleSubdomain(request);
      expect(response.statusCode, equals(404));
    });

    test('handlePath block not found', () async {
      final cidStr = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      final pbResp = GetBlockResponse()..found = false;
      when(mockBlockStore.getBlock(cidStr)).thenAnswer((_) async => pbResp);

      final request = Request(
        'GET',
        Uri.parse('http://localhost/ipfs/$cidStr'),
      );
      final response = await handler.handlePath(request);
      expect(response.statusCode, equals(404));
    });

    test('range request invalid format', () async {
      final cidStr = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      final data = Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
      final block = Block(cid: CID.decode(cidStr), data: data);

      final pbResp = GetBlockResponse()
        ..found = true
        ..block = block.toProto();
      when(mockBlockStore.getBlock(cidStr)).thenAnswer((_) async => pbResp);

      final request = Request(
        'GET',
        Uri.parse('http://localhost/ipfs/$cidStr'),
        headers: {'range': 'invalid'},
      );
      final response = await handler.handlePath(request);
      expect(response.statusCode, equals(416));
    });

    test('range request out of bounds', () async {
      final cidStr = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      final data = Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
      final block = Block(cid: CID.decode(cidStr), data: data);

      final pbResp = GetBlockResponse()
        ..found = true
        ..block = block.toProto();
      when(mockBlockStore.getBlock(cidStr)).thenAnswer((_) async => pbResp);

      final request = Request(
        'GET',
        Uri.parse('http://localhost/ipfs/$cidStr'),
        headers: {'range': 'bytes=100-200'},
      );
      final response = await handler.handlePath(request);
      expect(response.statusCode, equals(416));
    });

    test('handlePath with storage error', () async {
      final cidStr = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      when(
        mockBlockStore.getBlock(cidStr),
      ).thenThrow(Exception('Storage error'));

      final request = Request(
        'GET',
        Uri.parse('http://localhost/ipfs/$cidStr'),
      );
      final response = await handler.handlePath(request);
      expect(response.statusCode, equals(404));
    });

    test('range request with only start', () async {
      final cidStr = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      final data = Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
      final block = Block(cid: CID.decode(cidStr), data: data);

      final pbResp = GetBlockResponse()
        ..found = true
        ..block = block.toProto();
      when(mockBlockStore.getBlock(cidStr)).thenAnswer((_) async => pbResp);

      final request = Request(
        'GET',
        Uri.parse('http://localhost/ipfs/$cidStr'),
        headers: {'range': 'bytes=5-'},
      );
      final response = await handler.handlePath(request);
      expect(response.statusCode, equals(206));
    });

    test('handlePath with trailing slash', () async {
      final cidStr = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      final block = Block(
        cid: CID.decode(cidStr),
        data: Uint8List.fromList([1, 2, 3]),
      );

      final pbResp = GetBlockResponse()
        ..found = true
        ..block = block.toProto();
      when(mockBlockStore.getBlock(cidStr)).thenAnswer((_) async => pbResp);

      final request = Request(
        'GET',
        Uri.parse('http://localhost/ipfs/$cidStr/'),
      );
      final response = await handler.handlePath(request);
      expect(response.statusCode, equals(200));
    });

    test('handlePath with path segments', () async {
      final cidStr = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      final block = Block(
        cid: CID.decode(cidStr),
        data: Uint8List.fromList([1, 2, 3]),
      );

      final pbResp = GetBlockResponse()
        ..found = true
        ..block = block.toProto();
      when(mockBlockStore.getBlock(cidStr)).thenAnswer((_) async => pbResp);

      final request = Request(
        'GET',
        Uri.parse('http://localhost/ipfs/$cidStr/path/to/file'),
      );
      final response = await handler.handlePath(request);
      expect(response.statusCode, equals(200));
    });

    test(
      'handlePath reassembles a chunked UnixFS file across blocks',
      () async {
        // A dag-pb file node whose payload lives in a linked raw block
        // exercises the _getBlockByCid fetcher inside unixfsReadFile.
        final chunk = Block(
          cid: (await Block.fromData(
            Uint8List.fromList('chunk!'.codeUnits),
          )).cid,
          data: Uint8List.fromList('chunk!'.codeUnits),
        );
        when(mockBlockStore.getBlock(chunk.cid.encode())).thenAnswer(
          (_) async => GetBlockResponse()
            ..found = true
            ..block = chunk.toProto(),
        );

        final fileNode = dag_pb.PBNode(
          data: unixfs_pb.Data(
            type: unixfs_pb.Data_DataType.File,
            filesize: Int64(6),
            blocksizes: [Int64(6)],
          ).writeToBuffer(),
          links: [dag_pb.PBLink(hash: chunk.cid.toBytes(), size: Int64(6))],
        );
        final fileBlock = await Block.fromData(
          fileNode.writeToBuffer(),
          format: 'dag-pb',
        );
        when(mockBlockStore.getBlock(fileBlock.cid.encode())).thenAnswer(
          (_) async => GetBlockResponse()
            ..found = true
            ..block = fileBlock.toProto(),
        );

        final response = await handler.handlePath(
          Request(
            'GET',
            Uri.parse('http://localhost/ipfs/${fileBlock.cid.encode()}'),
          ),
        );
        expect(response.statusCode, equals(200));
        final body = await response.read().expand((i) => i).toList();
        expect(body, equals('chunk!'.codeUnits));
      },
    );

    test('handlePath returns 500 for an undecodable IPNS record', () async {
      handler = GatewayHandler(
        mockBlockStore,
        ipnsRecordResolver: (name) async =>
            Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF]),
      );
      final response = await handler.handlePath(
        Request(
          'GET',
          Uri.parse('http://localhost/ipns/test.local'),
          headers: {'accept': 'application/vnd.ipfs.ipns-record'},
        ),
      );
      expect(response.statusCode, equals(500));
      expect(await response.readAsString(), contains('Invalid IPNS record'));
    });

    test(
      'handlePath returns 500 when a linked file block is missing',
      () async {
        // A UnixFS file whose linked chunk cannot be fetched must not fall
        // through to the raw-block path — a 200 would serve PBNode bytes.
        final missingCid = (await Block.fromData(
          Uint8List.fromList([9, 9, 9]),
        )).cid;
        when(
          mockBlockStore.getBlock(missingCid.encode()),
        ).thenAnswer((_) async => GetBlockResponse()..found = false);

        final fileNode = dag_pb.PBNode(
          data: unixfs_pb.Data(
            type: unixfs_pb.Data_DataType.File,
            filesize: Int64(3),
            blocksizes: [Int64(3)],
          ).writeToBuffer(),
          links: [dag_pb.PBLink(hash: missingCid.toBytes(), size: Int64(3))],
        );
        final fileBlock = await Block.fromData(
          fileNode.writeToBuffer(),
          format: 'dag-pb',
        );
        when(mockBlockStore.getBlock(fileBlock.cid.encode())).thenAnswer(
          (_) async => GetBlockResponse()
            ..found = true
            ..block = fileBlock.toProto(),
        );

        final response = await handler.handlePath(
          Request(
            'GET',
            Uri.parse('http://localhost/ipfs/${fileBlock.cid.encode()}'),
          ),
        );
        expect(response.statusCode, equals(500));
        expect(
          await response.readAsString(),
          contains('Failed to resolve content'),
        );
      },
    );

    test(
      'handlePath returns 413 when a file exceeds maxFileResponseBytes',
      () async {
        handler = GatewayHandler(mockBlockStore, maxFileResponseBytes: 4);

        final chunk = await Block.fromData(
          Uint8List.fromList('chunk!'.codeUnits),
        );
        when(mockBlockStore.getBlock(chunk.cid.encode())).thenAnswer(
          (_) async => GetBlockResponse()
            ..found = true
            ..block = chunk.toProto(),
        );

        final fileNode = dag_pb.PBNode(
          data: unixfs_pb.Data(
            type: unixfs_pb.Data_DataType.File,
            filesize: Int64(6),
            blocksizes: [Int64(6)],
          ).writeToBuffer(),
          links: [dag_pb.PBLink(hash: chunk.cid.toBytes(), size: Int64(6))],
        );
        final fileBlock = await Block.fromData(
          fileNode.writeToBuffer(),
          format: 'dag-pb',
        );
        when(mockBlockStore.getBlock(fileBlock.cid.encode())).thenAnswer(
          (_) async => GetBlockResponse()
            ..found = true
            ..block = fileBlock.toProto(),
        );

        final response = await handler.handlePath(
          Request(
            'GET',
            Uri.parse('http://localhost/ipfs/${fileBlock.cid.encode()}'),
          ),
        );
        expect(response.statusCode, equals(413));
        expect(
          await response.readAsString(),
          contains('maximum response size'),
        );
      },
    );

    test('handlePath serves a directory index.html transparently', () async {
      final indexFile = await Block.fromData(
        Uint8List.fromList('<html>index</html>'.codeUnits),
      );
      when(mockBlockStore.getBlock(indexFile.cid.encode())).thenAnswer(
        (_) async => GetBlockResponse()
          ..found = true
          ..block = indexFile.toProto(),
      );

      final dirNode = dag_pb.PBNode(
        data: unixfs_pb.Data(
          type: unixfs_pb.Data_DataType.Directory,
        ).writeToBuffer(),
        links: [
          dag_pb.PBLink(name: 'index.html', hash: indexFile.cid.toBytes()),
        ],
      );
      final dirBlock = await Block.fromData(
        dirNode.writeToBuffer(),
        format: 'dag-pb',
      );
      when(mockBlockStore.getBlock(dirBlock.cid.encode())).thenAnswer(
        (_) async => GetBlockResponse()
          ..found = true
          ..block = dirBlock.toProto(),
      );

      final response = await handler.handlePath(
        Request(
          'GET',
          Uri.parse('http://localhost/ipfs/${dirBlock.cid.encode()}/'),
        ),
      );
      expect(response.statusCode, equals(200));
      final body = await response.read().expand((i) => i).toList();
      expect(body, equals('<html>index</html>'.codeUnits));
    });

    test('handlePath caps index.html indirection depth at 8', () async {
      // Each directory's index.html link points at another directory;
      // the chain exceeds _maxIndexHtmlDepth so serving must stop with a
      // 500 instead of recursing forever.
      CID? childCid;
      for (var i = 0; i < 10; i++) {
        final node = dag_pb.PBNode(
          data: unixfs_pb.Data(
            type: unixfs_pb.Data_DataType.Directory,
          ).writeToBuffer(),
          links: [
            if (childCid != null)
              dag_pb.PBLink(name: 'index.html', hash: childCid.toBytes()),
          ],
        );
        final block = await Block.fromData(
          node.writeToBuffer(),
          format: 'dag-pb',
        );
        when(mockBlockStore.getBlock(block.cid.encode())).thenAnswer(
          (_) async => GetBlockResponse()
            ..found = true
            ..block = block.toProto(),
        );
        childCid = block.cid;
      }

      final response = await handler.handlePath(
        Request(
          'GET',
          Uri.parse('http://localhost/ipfs/${childCid!.encode()}/'),
        ),
      );
      expect(response.statusCode, equals(500));
      expect(
        await response.readAsString(),
        contains('index.html resolution depth exceeded'),
      );
    });

    test('handlePath serves a block fetched through Bitswap', () async {
      final remote = await Block.fromData(
        Uint8List.fromList('network'.codeUnits),
      );
      final bitswap = _FakeBitswapHandler(remote);
      handler = GatewayHandler(mockBlockStore, bitswapHandler: bitswap);

      var calls = 0;
      when(mockBlockStore.getBlock(remote.cid.encode())).thenAnswer(
        (_) async => ++calls == 1
            ? (GetBlockResponse()..found = false)
            : (GetBlockResponse()
                ..found = true
                ..block = remote.toProto()),
      );

      final response = await handler.handlePath(
        Request(
          'GET',
          Uri.parse('http://localhost/ipfs/${remote.cid.encode()}'),
        ),
      );
      expect(response.statusCode, equals(200));
      expect(bitswap.requested, contains(remote.cid.encode()));
    });
  });
}

class _FakeBitswapHandler extends Mock implements BitswapHandler {
  _FakeBitswapHandler(this._block);

  final Block _block;
  final List<String> requested = [];

  @override
  Future<Block?> wantBlock(String cid) async {
    requested.add(cid);
    return cid == _block.cid.encode() ? _block : null;
  }
}
