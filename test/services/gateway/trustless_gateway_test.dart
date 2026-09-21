import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/security_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/car.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/security/denylist_service.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart' as dag_pb;
import 'package:dart_ipfs/src/proto/generated/ipns.pb.dart';
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart'
    as unixfs_pb;
import 'package:dart_ipfs/src/protocols/bitswap/bitswap_handler.dart';
import 'package:dart_ipfs/src/protocols/ipns/ipns_record.dart';
import 'package:dart_ipfs/src/services/gateway/gateway_handler.dart';
import 'package:fixnum/fixnum.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:multibase/multibase.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'gateway_handler_test.mocks.dart';
import 'trustless_gateway_test.mocks.dart';

class _MockMetrics implements MetricsCollector {
  final List<Map<String, dynamic>> securityEvents = [];

  @override
  void recordSecurityEvent(String type) {
    securityEvents.add({'type': type});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

@GenerateMocks([BitswapHandler])
void main() {
  group('TrustlessGateway', () {
    late MockBlockStore mockBlockStore;
    late MockBitswapHandler mockBitswap;
    late GatewayHandler handler;

    final cidStr = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
    final rawData = Uint8List.fromList([1, 2, 3, 4, 5]);

    Block makeBlock({String? cid, Uint8List? data}) {
      return Block(cid: CID.decode(cid ?? cidStr), data: data ?? rawData);
    }

    GetBlockResponse foundResponse(Block block) {
      return GetBlockResponse()
        ..found = true
        ..block = block.toProto();
    }

    GetBlockResponse notFoundResponse() {
      return GetBlockResponse()..found = false;
    }

    setUp(() {
      mockBlockStore = MockBlockStore();
      mockBitswap = MockBitswapHandler();
      handler = GatewayHandler(mockBlockStore, bitswapHandler: mockBitswap);
    });

    group('format detection', () {
      test('?format=raw takes precedence over Accept text/html', () async {
        final block = makeBlock();
        when(
          mockBlockStore.getBlock(cidStr),
        ).thenAnswer((_) async => foundResponse(block));

        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr?format=raw'),
          headers: {'accept': 'text/html'},
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(200));
        expect(
          response.headers['content-type'],
          equals('application/vnd.ipld.raw'),
        );
        final body = await response.read().expand((i) => i).toList();
        expect(body, equals(rawData));
      });

      test('Accept header selects raw-block when no ?format', () async {
        final block = makeBlock();
        when(
          mockBlockStore.getBlock(cidStr),
        ).thenAnswer((_) async => foundResponse(block));

        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr'),
          headers: {'accept': 'application/vnd.ipld.raw'},
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(200));
        expect(
          response.headers['content-type'],
          equals('application/vnd.ipld.raw'),
        );
        expect(
          response.headers['content-location'],
          equals('/ipfs/$cidStr?format=raw'),
        );
      });

      test('Accept q-values prefer the highest-weight supported type', () async {
        final block = makeBlock();
        when(
          mockBlockStore.getBlock(cidStr),
        ).thenAnswer((_) async => foundResponse(block));

        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr'),
          headers: {
            'accept':
                'application/vnd.ipld.dag-json;q=0.5, '
                'application/vnd.ipld.raw;q=1.0',
          },
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(200));
        expect(
          response.headers['content-type'],
          equals('application/vnd.ipld.raw'),
        );
      });

      test('?format accepts full media type values', () async {
        final block = makeBlock();
        when(
          mockBlockStore.getBlock(cidStr),
        ).thenAnswer((_) async => foundResponse(block));

        final request = Request(
          'GET',
          Uri.parse(
            'http://localhost/ipfs/$cidStr?format=application%2Fvnd.ipld.raw',
          ),
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(200));
        expect(
          response.headers['content-type'],
          equals('application/vnd.ipld.raw'),
        );
      });

      test('unknown ?format value returns 400', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr?format=bogus'),
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(400));
      });

      test('known but unimplemented ?format value returns 406', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr?format=tar'),
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(406));
      });

      test('unsupported Accept falls back to path gateway', () async {
        final block = makeBlock();
        when(
          mockBlockStore.getBlock(cidStr),
        ).thenAnswer((_) async => foundResponse(block));

        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr'),
          headers: {'accept': 'application/unsupported'},
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(200));
        expect(
          response.headers['content-type'],
          equals('application/octet-stream'),
        );
      });
    });

    group('?format=raw', () {
      test('returns raw block bytes', () async {
        final block = makeBlock();
        when(
          mockBlockStore.getBlock(cidStr),
        ).thenAnswer((_) async => foundResponse(block));

        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr?format=raw'),
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(200));
        expect(
          response.headers['content-type'],
          equals('application/vnd.ipld.raw'),
        );
        expect(
          response.headers['content-disposition'],
          equals('attachment; filename="$cidStr.bin"'),
        );
        expect(response.headers['etag'], equals('"$cidStr.raw"'));
        expect(response.headers['x-ipfs-path'], equals('/ipfs/$cidStr'));
        final body = await response.read().expand((i) => i).toList();
        expect(body, equals(rawData));
      });

      test('honors a custom ?filename for the download', () async {
        final block = makeBlock();
        when(
          mockBlockStore.getBlock(cidStr),
        ).thenAnswer((_) async => foundResponse(block));

        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr?format=raw&filename=x.dat'),
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(200));
        expect(
          response.headers['content-disposition'],
          equals('attachment; filename="x.dat"'),
        );
      });

      test('Cache-Control: only-if-cached returns 412 without Bitswap', () async {
        when(
          mockBlockStore.getBlock(cidStr),
        ).thenAnswer((_) async => notFoundResponse());

        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr?format=raw'),
          headers: {'cache-control': 'only-if-cached'},
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(412));
        verifyNever(mockBitswap.wantBlock(any));
      });

      test('identity CID bafkqaaa returns an empty raw block', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/bafkqaaa?format=raw'),
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(200));
        expect(
          response.headers['content-type'],
          equals('application/vnd.ipld.raw'),
        );
        final body = await response.read().expand((i) => i).toList();
        expect(body, isEmpty);
        verifyNever(mockBlockStore.getBlock(any));
      });

      test('uses Bitswap fallback when block is missing locally', () async {
        final block = makeBlock();
        when(
          mockBlockStore.getBlock(cidStr),
        ).thenAnswer((_) async => notFoundResponse());
        when(mockBitswap.wantBlock(cidStr)).thenAnswer((_) async => block);

        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr?format=raw'),
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(200));
        final body = await response.read().expand((i) => i).toList();
        expect(body, equals(rawData));
        verify(mockBitswap.wantBlock(cidStr)).called(1);
      });

      test('returns 404 when block is missing and Bitswap fails', () async {
        when(
          mockBlockStore.getBlock(cidStr),
        ).thenAnswer((_) async => notFoundResponse());
        when(mockBitswap.wantBlock(cidStr)).thenAnswer((_) async => null);

        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr?format=raw'),
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(404));
      });
    });

    group('?format=car', () {
      test('returns CAR archive with correct root CID', () async {
        final block = makeBlock();
        when(
          mockBlockStore.getBlock(cidStr),
        ).thenAnswer((_) async => foundResponse(block));

        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr?format=car'),
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(200));
        expect(
          response.headers['content-type'],
          equals('application/vnd.ipld.car; version=1; order=dfs; dups=n'),
        );
        expect(
          response.headers['content-disposition'],
          equals('attachment; filename="$cidStr.car"'),
        );
        expect(response.headers['etag'], equals('"all.$cidStr.car"'));

        final body = await response.read().expand((i) => i).toList();
        final carBytes = Uint8List.fromList(body);
        final reader = CarReader.fromBytes(carBytes);
        final header = await reader.header;
        expect(header.roots.length, equals(1));
        expect(header.roots.first.encode(), equals(cidStr));

        final sections = await reader.sections().toList();
        expect(sections.length, equals(1));
        expect(sections.first.cid.encode(), equals(cidStr));
        expect(sections.first.bytes, equals(rawData));
      });

      test('uses Bitswap fallback for missing root block', () async {
        final block = makeBlock();
        when(
          mockBlockStore.getBlock(cidStr),
        ).thenAnswer((_) async => notFoundResponse());
        when(mockBitswap.wantBlock(cidStr)).thenAnswer((_) async => block);

        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr?format=car'),
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(200));
        expect(
          response.headers['content-type'],
          equals('application/vnd.ipld.car; version=1; order=dfs; dups=n'),
        );
        verify(mockBitswap.wantBlock(cidStr)).called(1);
      });

      test('CAR with sub-path archives the requested root block too', () async {
        final fileData = Uint8List.fromList([9, 8, 7]);
        final fileCid = await CID.computeForData(fileData, format: 'raw');
        final fileBlock = makeBlock(cid: fileCid.encode(), data: fileData);

        final dirNode = dag_pb.PBNode(
          links: <dag_pb.PBLink>[
            dag_pb.PBLink(name: 'file.txt', hash: fileCid.toBytes()),
          ],
        );
        final dirData = Uint8List.fromList(dirNode.writeToBuffer());
        final dirCid = await CID.computeForData(dirData, format: 'dag-pb');
        final dirBlock = makeBlock(cid: dirCid.encode(), data: dirData);

        when(
          mockBlockStore.getBlock(dirCid.encode()),
        ).thenAnswer((_) async => foundResponse(dirBlock));
        when(
          mockBlockStore.getBlock(fileCid.encode()),
        ).thenAnswer((_) async => foundResponse(fileBlock));

        final request = Request(
          'GET',
          Uri.parse(
            'http://localhost/ipfs/${dirCid.encode()}/file.txt?format=car',
          ),
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(200));

        final body = await response.read().expand((i) => i).toList();
        final reader = CarReader.fromBytes(Uint8List.fromList(body));
        final sections = await reader.sections().toList();
        // The archive must contain both the resolved file target and the
        // originally requested directory root.
        final cids = sections.map((s) => s.cid.encode()).toSet();
        expect(cids, containsAll([dirCid.encode(), fileCid.encode()]));
      });

      test('rejects unsupported car-order with 406', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr?format=car&car-order=bfs'),
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(406));
      });

      test('rejects unsupported car-version with 406', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr?format=car&car-version=2'),
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(406));
      });

      test('rejects unsatisfiable Accept car params with 406', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr'),
          headers: {'accept': 'application/vnd.ipld.car; version=2'},
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(406));
      });

      test('falls back to a satisfiable lower-q Accept variant', () async {
        final block = makeBlock();
        when(
          mockBlockStore.getBlock(cidStr),
        ).thenAnswer((_) async => foundResponse(block));

        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr'),
          headers: {
            'accept':
                'application/vnd.ipld.car; order=bfs, '
                'application/vnd.ipld.raw; q=0.5',
          },
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(200));
        expect(
          response.headers['content-type'],
          equals('application/vnd.ipld.raw'),
        );
      });

      test('rejects invalid car-dups with 400', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr?format=car&car-dups=x'),
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(400));
      });

      test('rejects invalid dag-scope with 400', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr?format=car&dag-scope=no'),
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(400));
      });

      test('rejects malformed entity-bytes with 400', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr?format=car&entity-bytes=x'),
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(400));
      });

      test('car-dups=y emits duplicate blocks and advertises dups=y', () async {
        final childData = Uint8List.fromList([7, 7, 7]);
        final childCid = await CID.computeForData(childData, format: 'raw');
        final childBlock = makeBlock(cid: childCid.encode(), data: childData);

        final dirNode = dag_pb.PBNode(
          links: <dag_pb.PBLink>[
            dag_pb.PBLink(name: 'a', hash: childCid.toBytes()),
            dag_pb.PBLink(name: 'b', hash: childCid.toBytes()),
          ],
        );
        final dirData = Uint8List.fromList(dirNode.writeToBuffer());
        final dirCid = await CID.computeForData(dirData, format: 'dag-pb');
        final dirBlock = makeBlock(cid: dirCid.encode(), data: dirData);

        when(
          mockBlockStore.getBlock(dirCid.encode()),
        ).thenAnswer((_) async => foundResponse(dirBlock));
        when(
          mockBlockStore.getBlock(childCid.encode()),
        ).thenAnswer((_) async => foundResponse(childBlock));

        Future<List<String>> carSectionCids(String url) async {
          final response = await handler.handlePath(
            Request('GET', Uri.parse(url)),
          );
          expect(response.statusCode, equals(200));
          final body = await response.read().expand((i) => i).toList();
          final reader = CarReader.fromBytes(Uint8List.fromList(body));
          final sections = await reader.sections().toList();
          return sections.map((s) => s.cid.encode()).toList();
        }

        final base = 'http://localhost/ipfs/${dirCid.encode()}?format=car';
        final deduped = await carSectionCids('$base&car-dups=n');
        expect(
          deduped.where((c) => c == childCid.encode()).length,
          equals(1),
        );

        final duplicated = await carSectionCids('$base&car-dups=y');
        expect(
          duplicated.where((c) => c == childCid.encode()).length,
          equals(2),
        );

        final response = await handler.handlePath(
          Request('GET', Uri.parse('$base&car-dups=y')),
        );
        expect(
          response.headers['content-type'],
          contains('dups=y'),
        );
      });

      test('dag-scope=block returns only path and terminal blocks', () async {
        final leafData = Uint8List.fromList([1]);
        final leafCid = await CID.computeForData(leafData, format: 'raw');
        final leafBlock = makeBlock(cid: leafCid.encode(), data: leafData);

        final innerNode = dag_pb.PBNode(
          links: <dag_pb.PBLink>[
            dag_pb.PBLink(name: 'leaf', hash: leafCid.toBytes()),
          ],
        );
        final innerData = Uint8List.fromList(innerNode.writeToBuffer());
        final innerCid = await CID.computeForData(innerData, format: 'dag-pb');
        final innerBlock = makeBlock(cid: innerCid.encode(), data: innerData);

        final rootNode = dag_pb.PBNode(
          links: <dag_pb.PBLink>[
            dag_pb.PBLink(name: 'sub', hash: innerCid.toBytes()),
          ],
        );
        final rootData = Uint8List.fromList(rootNode.writeToBuffer());
        final rootCid = await CID.computeForData(rootData, format: 'dag-pb');
        final rootBlock = makeBlock(cid: rootCid.encode(), data: rootData);

        for (final b in [rootBlock, innerBlock, leafBlock]) {
          when(
            mockBlockStore.getBlock(b.cid.encode()),
          ).thenAnswer((_) async => foundResponse(b));
        }

        Future<List<String>> sectionsFor(String query) async {
          final response = await handler.handlePath(
            Request(
              'GET',
              Uri.parse('http://localhost/ipfs/${rootCid.encode()}/sub$query'),
            ),
          );
          expect(response.statusCode, equals(200));
          final body = await response.read().expand((i) => i).toList();
          final reader = CarReader.fromBytes(Uint8List.fromList(body));
          final sections = await reader.sections().toList();
          return sections.map((s) => s.cid.encode()).toList();
        }

        // dag-scope=block: path blocks (root) + terminal (sub dir) only.
        final blockScope = await sectionsFor('?format=car&dag-scope=block');
        expect(
          blockScope,
          unorderedEquals([rootCid.encode(), innerCid.encode()]),
        );

        // dag-scope=entity on a directory: still only the directory block.
        final entityScope = await sectionsFor('?format=car&dag-scope=entity');
        expect(
          entityScope,
          unorderedEquals([rootCid.encode(), innerCid.encode()]),
        );

        // dag-scope=all (default): the leaf block is included as well.
        final allScope = await sectionsFor('?format=car');
        expect(
          allScope,
          unorderedEquals([
            rootCid.encode(),
            innerCid.encode(),
            leafCid.encode(),
          ]),
        );
      });

      test('entity-bytes returns only the blocks covering the range', () async {
        final chunk1 = Uint8List.fromList([1, 1, 1]);
        final chunk2 = Uint8List.fromList([2, 2]);
        final chunk1Cid = await CID.computeForData(chunk1, format: 'raw');
        final chunk2Cid = await CID.computeForData(chunk2, format: 'raw');
        final chunk1Block = makeBlock(cid: chunk1Cid.encode(), data: chunk1);
        final chunk2Block = makeBlock(cid: chunk2Cid.encode(), data: chunk2);

        final fileNode = dag_pb.PBNode(
          data: unixfs_pb.Data(
            type: unixfs_pb.Data_DataType.File,
            filesize: Int64(5),
            blocksizes: <Int64>[Int64(3), Int64(2)],
          ).writeToBuffer(),
          links: <dag_pb.PBLink>[
            dag_pb.PBLink(hash: chunk1Cid.toBytes()),
            dag_pb.PBLink(hash: chunk2Cid.toBytes()),
          ],
        );
        final fileData = Uint8List.fromList(fileNode.writeToBuffer());
        final fileCid = await CID.computeForData(fileData, format: 'dag-pb');
        final fileBlock = makeBlock(cid: fileCid.encode(), data: fileData);

        for (final b in [fileBlock, chunk1Block, chunk2Block]) {
          when(
            mockBlockStore.getBlock(b.cid.encode()),
          ).thenAnswer((_) async => foundResponse(b));
        }

        Future<List<String>> sectionsFor(String range) async {
          final response = await handler.handlePath(
            Request(
              'GET',
              Uri.parse(
                'http://localhost/ipfs/${fileCid.encode()}'
                '?format=car&entity-bytes=$range',
              ),
            ),
          );
          expect(response.statusCode, equals(200));
          final body = await response.read().expand((i) => i).toList();
          final reader = CarReader.fromBytes(Uint8List.fromList(body));
          final sections = await reader.sections().toList();
          return sections.map((s) => s.cid.encode()).toList();
        }

        // Bytes 0-2 are covered entirely by chunk1.
        final first = await sectionsFor('0:2');
        expect(
          first,
          unorderedEquals([fileCid.encode(), chunk1Cid.encode()]),
        );

        // Bytes 3-* are covered entirely by chunk2.
        final last = await sectionsFor('3:*');
        expect(
          last,
          unorderedEquals([fileCid.encode(), chunk2Cid.encode()]),
        );
      });

      test('entity-bytes outside the entity returns 400', () async {
        final fileNode = dag_pb.PBNode(
          data: unixfs_pb.Data(
            type: unixfs_pb.Data_DataType.File,
            filesize: Int64(5),
            data: <int>[1, 2, 3, 4, 5],
          ).writeToBuffer(),
        );
        final fileData = Uint8List.fromList(fileNode.writeToBuffer());
        final fileCid = await CID.computeForData(fileData, format: 'dag-pb');
        final fileBlock = makeBlock(cid: fileCid.encode(), data: fileData);
        when(
          mockBlockStore.getBlock(fileCid.encode()),
        ).thenAnswer((_) async => foundResponse(fileBlock));

        final request = Request(
          'GET',
          Uri.parse(
            'http://localhost/ipfs/${fileCid.encode()}'
            '?format=car&entity-bytes=100:*',
          ),
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(400));
      });

      test('identity CID bafkqaaa returns a CAR with no data sections', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/bafkqaaa?format=car'),
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(200));
        expect(
          response.headers['content-type'],
          contains('application/vnd.ipld.car'),
        );
        final body = await response.read().expand((i) => i).toList();
        // The CAR is a single varint-prefixed dag-cbor header
        // {roots: [bafkqaaa], version: 1} with an empty data section.
        // CarReader/DagCborCodec cannot decode the zero-length identity
        // multihash, so the header bytes are checked directly.
        // bafkqaaa bytes: CIDv1 | raw codec (0x55) | identity mh | size 0.
        const cidBytes = [0x01, 0x55, 0x00, 0x00];
        final taggedCid = <int>[0x00, ...cidBytes];
        final expectedHeader = <int>[
          0xa2, // map(2)
          0x65, ...'roots'.codeUnits,
          0x81, // array(1)
          0xd8, 0x2a, // tag 42 (CID link)
          0x40 + taggedCid.length, ...taggedCid,
          0x67, ...'version'.codeUnits,
          0x01,
        ];
        expect(body, equals([expectedHeader.length, ...expectedHeader]));
        verifyNever(mockBlockStore.getBlock(any));
      });
    });

    group('?format=dag-json', () {
      test('returns DAG-JSON for raw block', () async {
        final rawCid = await CID.computeForData(rawData, format: 'raw');
        final block = makeBlock(cid: rawCid.encode());
        when(
          mockBlockStore.getBlock(rawCid.encode()),
        ).thenAnswer((_) async => foundResponse(block));

        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/${rawCid.encode()}?format=dag-json'),
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(200));
        expect(
          response.headers['content-type'],
          equals('application/vnd.ipld.dag-json'),
        );
        expect(response.headers['etag'], equals('"${rawCid.encode()}.dag.json"'));
        final body = await response.readAsString();
        expect(body, contains('"bytes"'));
      });

      test('returns dag-json block bytes verbatim when codec matches', () async {
        final jsonBytes = Uint8List.fromList('{"a":1}'.codeUnits);
        final jsonCid = await CID.computeForData(jsonBytes, format: 'dag-json');
        final block = makeBlock(cid: jsonCid.encode(), data: jsonBytes);
        when(
          mockBlockStore.getBlock(jsonCid.encode()),
        ).thenAnswer((_) async => foundResponse(block));

        final request = Request(
          'GET',
          Uri.parse(
            'http://localhost/ipfs/${jsonCid.encode()}?format=dag-json',
          ),
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(200));
        final body = await response.read().expand((i) => i).toList();
        expect(body, equals(jsonBytes));
      });
    });

    group('?format=dag-cbor', () {
      test('returns DAG-CBOR for raw block', () async {
        final rawCid = await CID.computeForData(rawData, format: 'raw');
        final block = makeBlock(cid: rawCid.encode());
        when(
          mockBlockStore.getBlock(rawCid.encode()),
        ).thenAnswer((_) async => foundResponse(block));

        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/${rawCid.encode()}?format=dag-cbor'),
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(200));
        expect(
          response.headers['content-type'],
          equals('application/vnd.ipld.dag-cbor'),
        );
        final body = await response.read().expand((i) => i).toList();
        expect(body, isNotEmpty);
      });

      test('returns dag-cbor block bytes verbatim when codec matches', () async {
        final cborBytes = Uint8List.fromList([0xa1, 0x61, 0x61, 0x01]);
        final cborCid = await CID.computeForData(cborBytes, format: 'dag-cbor');
        final block = makeBlock(cid: cborCid.encode(), data: cborBytes);
        when(
          mockBlockStore.getBlock(cborCid.encode()),
        ).thenAnswer((_) async => foundResponse(block));

        final request = Request(
          'GET',
          Uri.parse(
            'http://localhost/ipfs/${cborCid.encode()}?format=dag-cbor',
          ),
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(200));
        expect(
          response.headers['content-disposition'],
          equals('attachment; filename="${cborCid.encode()}.cbor"'),
        );
        final body = await response.read().expand((i) => i).toList();
        expect(body, equals(cborBytes));
      });
    });

    group('?format=ipns-record', () {
      IPNSRecord makeRecord({Duration ttl = const Duration(minutes: 5)}) {
        return IPNSRecord.internal(
          value: Uint8List.fromList('/ipfs/QmResolvedCid'.codeUnits),
          validity: DateTime.now().add(const Duration(hours: 1)),
          ttl: ttl,
          publicKey: Uint8List.fromList([9, 9, 9]),
          signature: Uint8List.fromList([8, 8]),
          signatureV2: Uint8List.fromList([7, 7, 7]),
        );
      }

      test('returns IpnsEntry protobuf bytes via resolver', () async {
        final record = makeRecord();
        // Resolver stores the internal CBOR encoding; the trustless
        // response must carry Kubo-compatible IpnsEntry protobuf bytes.
        final recordBytes = record.toCBOR();

        handler = GatewayHandler(
          mockBlockStore,
          ipnsRecordResolver: (name) async => recordBytes,
        );

        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipns/test.local?format=ipns-record'),
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(200));
        expect(
          response.headers['content-type'],
          equals('application/vnd.ipfs.ipns-record'),
        );
        expect(
          response.headers['cache-control'],
          equals('public, max-age=300'),
        );
        final body = await response.read().expand((i) => i).toList();
        expect(body, equals(record.toIpnsEntry()));
        final entry = IpnsEntry.fromBuffer(Uint8List.fromList(body));
        expect(entry.value, equals('/ipfs/QmResolvedCid'.codeUnits));
      });

      test('returns default TTL when record TTL is zero', () async {
        final record = makeRecord(ttl: Duration.zero);

        handler = GatewayHandler(
          mockBlockStore,
          ipnsRecordResolver: (name) async => record.toCBOR(),
        );

        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipns/test.local?format=ipns-record'),
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(200));
        expect(response.headers['cache-control'], equals('public, max-age=60'));
      });

      test('returns 501 when resolver is disabled', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipns/test.local?format=ipns-record'),
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(501));
      });

      test('Accept header selects the ipns-record format', () async {
        final record = makeRecord();
        handler = GatewayHandler(
          mockBlockStore,
          ipnsRecordResolver: (name) async => record.toCBOR(),
        );

        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipns/test.local'),
          headers: {'accept': 'application/vnd.ipfs.ipns-record'},
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(200));
        expect(
          response.headers['content-type'],
          equals('application/vnd.ipfs.ipns-record'),
        );
        expect(
          response.headers['content-disposition'],
          equals('attachment; filename="test.local.ipns-record"'),
        );
        // Mutable records carry a weak Etag derived from the record bytes.
        expect(response.headers['etag'], startsWith('W/"'));
      });

      test('ipns-record with a sub-path returns 400', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipns/test.local/a?format=ipns-record'),
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(400));
      });
    });

    group('subdomain gateway', () {
      test('detects trustless format in subdomain request', () async {
        final block = makeBlock();
        final cid = CID.decode(cidStr);
        final subdomainCid = CID
            .v1(cid.codec ?? 'dag-pb', cid.multihash, base: Multibase.base32)
            .encode();
        when(
          mockBlockStore.getBlock(subdomainCid),
        ).thenAnswer((_) async => foundResponse(block));

        final request = Request(
          'GET',
          Uri.parse('http://localhost/'),
          headers: {
            'host': '$cidStr.ipfs.localhost',
            'accept': 'application/vnd.ipld.raw',
          },
        );
        final response = await handler.handleSubdomain(request);
        expect(response.statusCode, equals(200));
        expect(
          response.headers['content-type'],
          equals('application/vnd.ipld.raw'),
        );
      });
    });

    group('denylist', () {
      test('returns 451 for blocked CID with ?format=raw', () async {
        final denylist = DenylistService(
          const SecurityConfig(enableDenylist: true),
          _MockMetrics(),
        );
        denylist.blockCidString(cidStr);

        handler = GatewayHandler(mockBlockStore, denylistService: denylist);

        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr?format=raw'),
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(451));
        final body = await response.readAsString();
        expect(body, equals('Content blocked by operator policy'));
      });

      test('returns 451 for blocked CID via path', () async {
        final denylist = DenylistService(
          const SecurityConfig(enableDenylist: true),
          _MockMetrics(),
        );
        denylist.blockCidString(cidStr);

        handler = GatewayHandler(mockBlockStore, denylistService: denylist);

        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr'),
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(451));
      });

      test('returns 451 for blocked IPNS name', () async {
        final denylist = DenylistService(
          const SecurityConfig(enableDenylist: true),
          _MockMetrics(),
        );
        denylist.blockCidString('blocked.local');

        handler = GatewayHandler(mockBlockStore, denylistService: denylist);

        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipns/blocked.local?format=ipns-record'),
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(451));
      });
    });
  });
}
