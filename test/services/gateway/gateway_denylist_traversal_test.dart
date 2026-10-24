// test/services/gateway/gateway_denylist_traversal_test.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/security_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/car.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/security/denylist_service.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart' as dag_pb;
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart'
    as unixfs_pb;
import 'package:dart_ipfs/src/services/gateway/gateway_handler.dart';
import 'package:dart_ipfs_core/dart_ipfs_core.dart' show MultihashInfo;
import 'package:fixnum/fixnum.dart';
import 'package:mockito/mockito.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'gateway_handler_test.mocks.dart';

class _MockMetricsCollector implements MetricsCollector {
  final List<String> securityEvents = [];

  @override
  void recordSecurityEvent(String type) => securityEvents.add(type);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MockBlockStore mockBlockStore;
  late _MockMetricsCollector metrics;

  DenylistService makeDenylist({String action = 'block', bool enabled = true}) {
    return DenylistService(
      SecurityConfig(enableDenylist: enabled, denylistDefaultAction: action),
      metrics,
    );
  }

  GatewayHandler makeHandler(DenylistService? denylist) {
    return GatewayHandler(mockBlockStore, denylistService: denylist);
  }

  GetBlockResponse foundResponse(Block block) {
    return GetBlockResponse()
      ..found = true
      ..block = block.toProto();
  }

  void stubBlock(CID cid, Uint8List data) {
    when(mockBlockStore.getBlock(cid.encode()))
        .thenAnswer((_) async => foundResponse(Block(cid: cid, data: data)));
  }

  /// Builds a UnixFS directory node with a single named link to [childCid]
  /// and returns the node bytes and the directory CID.
  Future<(CID, Uint8List)> makeDir(String linkName, CID childCid) async {
    final node = dag_pb.PBNode(
      links: <dag_pb.PBLink>[
        dag_pb.PBLink(name: linkName, hash: childCid.toBytes()),
      ],
      data: unixfs_pb.Data(type: unixfs_pb.Data_DataType.Directory)
          .writeToBuffer(),
    );
    final bytes = Uint8List.fromList(node.writeToBuffer());
    return (await CID.computeForData(bytes, format: 'dag-pb'), bytes);
  }

  /// Builds a UnixFS file node whose payload lives in [chunkCid] and returns
  /// the node bytes and the file CID.
  Future<(CID, Uint8List)> makeFile(CID chunkCid, int chunkSize) async {
    final node = dag_pb.PBNode(
      links: <dag_pb.PBLink>[
        dag_pb.PBLink(hash: chunkCid.toBytes(), size: Int64(chunkSize)),
      ],
      data: unixfs_pb.Data(
        type: unixfs_pb.Data_DataType.File,
        filesize: Int64(chunkSize),
        blocksizes: [Int64(chunkSize)],
      ).writeToBuffer(),
    );
    final bytes = Uint8List.fromList(node.writeToBuffer());
    return (await CID.computeForData(bytes, format: 'dag-pb'), bytes);
  }

  setUp(() {
    mockBlockStore = MockBlockStore();
    metrics = _MockMetricsCollector();
    when(mockBlockStore.getBlock(any))
        .thenAnswer((_) async => GetBlockResponse()..found = false);
  });

  group('denylist traversal gating', () {
    test('CAR request is 451 when a traversal child is denylisted', () async {
      final denylist = makeDenylist();
      final handler = makeHandler(denylist);

      final leafData = Uint8List.fromList([1, 2, 3]);
      final leafCid = await CID.computeForData(leafData, format: 'raw');
      final (dirCid, dirBytes) = await makeDir('leaf.bin', leafCid);
      stubBlock(leafCid, leafData);
      stubBlock(dirCid, dirBytes);

      denylist.blockCidString(leafCid.encode());

      final response = await handler.handlePath(
        Request(
          'GET',
          Uri.parse('http://localhost/ipfs/${dirCid.encode()}?format=car'),
        ),
      );
      expect(response.statusCode, equals(451));
      expect(
        await response.readAsString(),
        equals('Content blocked by operator policy'),
      );

      final hit = denylist.getAuditLog().single;
      expect(hit.cidOrMultihash, equals(leafCid.encode()));
      expect(hit.source, equals('gateway'));
      expect(hit.action, equals('block'));
    });

    test('log action still serves the CAR and records the hit', () async {
      final denylist = makeDenylist(action: 'log');
      final handler = makeHandler(denylist);

      final leafData = Uint8List.fromList([4, 5, 6]);
      final leafCid = await CID.computeForData(leafData, format: 'raw');
      final (dirCid, dirBytes) = await makeDir('leaf.bin', leafCid);
      stubBlock(leafCid, leafData);
      stubBlock(dirCid, dirBytes);

      denylist.blockCidString(leafCid.encode());

      final response = await handler.handlePath(
        Request(
          'GET',
          Uri.parse('http://localhost/ipfs/${dirCid.encode()}?format=car'),
        ),
      );
      expect(response.statusCode, equals(200));

      final body = await response.read().expand((i) => i).toList();
      final reader = CarReader.fromBytes(Uint8List.fromList(body));
      final cids = (await reader.sections().toList())
          .map((s) => s.cid.encode())
          .toSet();
      expect(cids, containsAll([dirCid.encode(), leafCid.encode()]));
      expect(metrics.securityEvents, contains('denylist_logged'));
    });

    test('directory navigation to a denylisted child is 451', () async {
      final denylist = makeDenylist();
      final handler = makeHandler(denylist);

      final fileData = Uint8List.fromList([7, 8, 9]);
      final fileCid = await CID.computeForData(fileData, format: 'raw');
      final (dirCid, dirBytes) = await makeDir('secret.txt', fileCid);
      stubBlock(fileCid, fileData);
      stubBlock(dirCid, dirBytes);

      denylist.blockCidString(fileCid.encode());

      final response = await handler.handlePath(
        Request(
          'GET',
          Uri.parse('http://localhost/ipfs/${dirCid.encode()}/secret.txt'),
        ),
      );
      expect(response.statusCode, equals(451));
    });

    test('UnixFS file with a denylisted chunk is 451', () async {
      final denylist = makeDenylist();
      final handler = makeHandler(denylist);

      final chunkData = Uint8List.fromList([10, 11, 12]);
      final chunkCid = await CID.computeForData(chunkData, format: 'raw');
      final (fileCid, fileBytes) = await makeFile(chunkCid, chunkData.length);
      stubBlock(chunkCid, chunkData);
      stubBlock(fileCid, fileBytes);

      denylist.blockCidString(chunkCid.encode());

      final response = await handler.handlePath(
        Request('GET', Uri.parse('http://localhost/ipfs/${fileCid.encode()}')),
      );
      expect(response.statusCode, equals(451));
    });

    test('disabled denylist serves traversal children normally', () async {
      final denylist = makeDenylist(enabled: false);
      final handler = makeHandler(denylist);

      final leafData = Uint8List.fromList([13, 14, 15]);
      final leafCid = await CID.computeForData(leafData, format: 'raw');
      final (dirCid, dirBytes) = await makeDir('leaf.bin', leafCid);
      stubBlock(leafCid, leafData);
      stubBlock(dirCid, dirBytes);

      denylist.blockCidString(leafCid.encode());

      final response = await handler.handlePath(
        Request(
          'GET',
          Uri.parse('http://localhost/ipfs/${dirCid.encode()}?format=car'),
        ),
      );
      expect(response.statusCode, equals(200));
      expect(denylist.getAuditLog(), isEmpty);
    });

    test('IPNS path traversal reaching a denylisted child is 451', () async {
      final denylist = makeDenylist();
      final chunkData = Uint8List.fromList([19, 20, 21]);
      final chunkCid = await CID.computeForData(chunkData, format: 'raw');
      final (fileCid, fileBytes) = await makeFile(chunkCid, chunkData.length);
      stubBlock(chunkCid, chunkData);
      stubBlock(fileCid, fileBytes);

      denylist.blockCidString(chunkCid.encode());

      final handler = GatewayHandler(
        mockBlockStore,
        denylistService: denylist,
        ipnsResolver: (name) async => fileCid.encode(),
      );
      final response = await handler.handlePath(
        Request('GET', Uri.parse('http://localhost/ipns/test.local')),
      );
      expect(response.statusCode, equals(451));
    });

    test('subdomain traversal reaching a denylisted child is 451', () async {
      final denylist = makeDenylist();
      final chunkData = Uint8List.fromList([22, 23, 24]);
      final chunkCid = await CID.computeForData(chunkData, format: 'raw');
      final (fileCid, fileBytes) = await makeFile(chunkCid, chunkData.length);
      stubBlock(chunkCid, chunkData);
      stubBlock(fileCid, fileBytes);

      denylist.blockCidString(chunkCid.encode());

      final handler = makeHandler(denylist);
      final response = await handler.handleSubdomain(
        Request(
          'GET',
          Uri.parse('http://localhost/'),
          headers: {'host': '${fileCid.encode()}.ipfs.localhost'},
        ),
      );
      expect(response.statusCode, equals(451));
    });

    test('non-denylisted CAR traversal is unaffected', () async {
      final denylist = makeDenylist();
      final handler = makeHandler(denylist);

      final leafData = Uint8List.fromList([16, 17, 18]);
      final leafCid = await CID.computeForData(leafData, format: 'raw');
      final (dirCid, dirBytes) = await makeDir('leaf.bin', leafCid);
      stubBlock(leafCid, leafData);
      stubBlock(dirCid, dirBytes);

      final response = await handler.handlePath(
        Request(
          'GET',
          Uri.parse('http://localhost/ipfs/${dirCid.encode()}?format=car'),
        ),
      );
      expect(response.statusCode, equals(200));
    });

    test('CAR traversal audits a denylisted identity-CID child', () async {
      final denylist = makeDenylist();
      final handler = makeHandler(denylist);

      // An identity CID carries its data inline in the multihash digest —
      // no block is ever stored or fetched for it.
      final inlineData = Uint8List.fromList([31, 32, 33]);
      final idCid = CID.v1(
        'raw',
        MultihashInfo(
          code: 0x00,
          name: 'identity',
          digest: inlineData,
          size: inlineData.length,
        ),
      );
      final (dirCid, dirBytes) = await makeDir('inline.bin', idCid);
      stubBlock(dirCid, dirBytes);

      denylist.blockCidString(idCid.encode());

      final response = await handler.handlePath(
        Request(
          'GET',
          Uri.parse('http://localhost/ipfs/${dirCid.encode()}?format=car'),
        ),
      );
      // Identity children are silently skipped — never fetched, never
      // written to the CAR — but the denylist hit is audited as 'car'.
      expect(response.statusCode, equals(200));
      final body = await response.read().expand((i) => i).toList();
      final sections = await CarReader.fromBytes(Uint8List.fromList(body))
          .sections()
          .toList();
      expect(
        sections.map((s) => s.cid.encode()).toList(),
        equals([dirCid.encode()]),
      );

      final hit = denylist.getAuditLog().single;
      expect(hit.cidOrMultihash, equals(idCid.encode()));
      expect(hit.source, equals('car'));
      expect(hit.action, equals('block'));
    });

    test('CAR traversal omits a non-denylisted identity-CID child', () async {
      final handler = makeHandler(null);

      final inlineData = Uint8List.fromList([41, 42, 43]);
      final idCid = CID.v1(
        'raw',
        MultihashInfo(
          code: 0x00,
          name: 'identity',
          digest: inlineData,
          size: inlineData.length,
        ),
      );
      final (dirCid, dirBytes) = await makeDir('inline.bin', idCid);
      stubBlock(dirCid, dirBytes);

      final response = await handler.handlePath(
        Request(
          'GET',
          Uri.parse('http://localhost/ipfs/${dirCid.encode()}?format=car'),
        ),
      );
      expect(response.statusCode, equals(200));
      final body = await response.read().expand((i) => i).toList();
      final sections = await CarReader.fromBytes(Uint8List.fromList(body))
          .sections()
          .toList();
      // Identity content is inline in the link; the CAR data section holds
      // only the directory block.
      expect(
        sections.map((s) => s.cid.encode()).toList(),
        equals([dirCid.encode()]),
      );
      verifyNever(mockBlockStore.getBlock(idCid.encode()));
    });

    test('path serving returns content linked via an identity CID', () async {
      final handler = makeHandler(null);

      final inlineData = Uint8List.fromList(utf8.encode('inline file'));
      final idCid = CID.v1(
        'raw',
        MultihashInfo(
          code: 0x00,
          name: 'identity',
          digest: inlineData,
          size: inlineData.length,
        ),
      );
      final (dirCid, dirBytes) = await makeDir('inline.txt', idCid);
      stubBlock(dirCid, dirBytes);

      final response = await handler.handlePath(
        Request(
          'GET',
          Uri.parse('http://localhost/ipfs/${dirCid.encode()}/inline.txt'),
        ),
      );
      expect(response.statusCode, equals(200));
      expect(
        await response.read().expand((i) => i).toList(),
        equals(inlineData),
      );
      verifyNever(mockBlockStore.getBlock(idCid.encode()));
    });

    test('a CAR request for an identity-CID root writes no section', () async {
      final handler = makeHandler(null);

      // The root's content is inline in the digest, so there is nothing to
      // write: identity CIDs never appear in CAR data sections.
      final inlineData = Uint8List.fromList([51, 52, 53]);
      final idCid = CID.v1(
        'raw',
        MultihashInfo(
          code: 0x00,
          name: 'identity',
          digest: inlineData,
          size: inlineData.length,
        ),
      );

      final response = await handler.handlePath(
        Request(
          'GET',
          Uri.parse('http://localhost/ipfs/${idCid.encode()}?format=car'),
        ),
      );
      expect(response.statusCode, equals(200));
      final body = await response.read().expand((i) => i).toList();
      final reader = CarReader.fromBytes(Uint8List.fromList(body));
      // The header names the identity root, but no data section is written
      // for it — identity CIDs never appear in CAR data sections.
      expect(
        (await reader.header).roots.map((c) => c.encode()).toList(),
        equals([idCid.encode()]),
      );
      await expectLater(
        reader.sections().toList(),
        throwsA(isA<CarException>()),
      );
    });

    test('entity scope skips an identity-CID child', () async {
      final handler = makeHandler(null);

      final inlineData = Uint8List.fromList([61, 62, 63]);
      final idCid = CID.v1(
        'raw',
        MultihashInfo(
          code: 0x00,
          name: 'identity',
          digest: inlineData,
          size: inlineData.length,
        ),
      );
      final (dirCid, dirBytes) = await makeDir('inline.bin', idCid);
      stubBlock(dirCid, dirBytes);

      final response = await handler.handlePath(
        Request(
          'GET',
          Uri.parse(
            'http://localhost/ipfs/${dirCid.encode()}'
            '?format=car&dag-scope=entity',
          ),
        ),
      );
      expect(response.statusCode, equals(200));
      final body = await response.read().expand((i) => i).toList();
      final sections = await CarReader.fromBytes(Uint8List.fromList(body))
          .sections()
          .toList();
      // Only the directory itself is part of the entity — the identity
      // child is skipped, never fetched and never written.
      expect(
        sections.map((s) => s.cid.encode()).toList(),
        equals([dirCid.encode()]),
      );
      verifyNever(mockBlockStore.getBlock(idCid.encode()));
    });

    test('entity scope over a byte range skips identity children', () async {
      final handler = makeHandler(null);

      // A directory is not byte-addressable, so an entity-bytes request
      // degrades to entity scope; the identity child is skipped there too.
      final inlineData = Uint8List.fromList([71, 72, 73]);
      final idCid = CID.v1(
        'raw',
        MultihashInfo(
          code: 0x00,
          name: 'identity',
          digest: inlineData,
          size: inlineData.length,
        ),
      );
      final (dirCid, dirBytes) = await makeDir('inline.bin', idCid);
      stubBlock(dirCid, dirBytes);

      final response = await handler.handlePath(
        Request(
          'GET',
          Uri.parse(
            'http://localhost/ipfs/${dirCid.encode()}'
            '?format=car&entity-bytes=0:2',
          ),
        ),
      );
      expect(response.statusCode, equals(200));
      final body = await response.read().expand((i) => i).toList();
      final sections = await CarReader.fromBytes(Uint8List.fromList(body))
          .sections()
          .toList();
      expect(
        sections.map((s) => s.cid.encode()).toList(),
        equals([dirCid.encode()]),
      );
      verifyNever(mockBlockStore.getBlock(idCid.encode()));
    });

    test('entity scope over a file skips identity chunks', () async {
      final handler = makeHandler(null);

      final inlineData = Uint8List.fromList([81, 82, 83]);
      final idCid = CID.v1(
        'raw',
        MultihashInfo(
          code: 0x00,
          name: 'identity',
          digest: inlineData,
          size: inlineData.length,
        ),
      );
      // A UnixFS file whose chunk is an identity CID: the chunk is skipped
      // in the entity traversal (and in the byte-range traversal).
      final node = dag_pb.PBNode(
        links: <dag_pb.PBLink>[
          dag_pb.PBLink(hash: idCid.toBytes(), size: Int64(3)),
        ],
        data: unixfs_pb.Data(
          type: unixfs_pb.Data_DataType.File,
          filesize: Int64(3),
          blocksizes: [Int64(3)],
        ).writeToBuffer(),
      );
      final fileBytes = Uint8List.fromList(node.writeToBuffer());
      final fileCid = await CID.computeForData(fileBytes, format: 'dag-pb');
      stubBlock(fileCid, fileBytes);

      for (final query in const [
        '?format=car&dag-scope=entity',
        '?format=car&entity-bytes=0:2',
      ]) {
        final response = await handler.handlePath(
          Request(
            'GET',
            Uri.parse('http://localhost/ipfs/${fileCid.encode()}$query'),
          ),
        );
        expect(response.statusCode, equals(200), reason: query);
        final body = await response.read().expand((i) => i).toList();
        final sections = await CarReader.fromBytes(Uint8List.fromList(body))
            .sections()
            .toList();
        expect(
          sections.map((s) => s.cid.encode()).toList(),
          equals([fileCid.encode()]),
          reason: query,
        );
      }
      verifyNever(mockBlockStore.getBlock(idCid.encode()));
    });

    test(
      'entity scope over a file without blocksizes skips identity chunks',
      () async {
        final handler = makeHandler(null);

        final inlineData = Uint8List.fromList([91, 92, 93]);
        final idCid = CID.v1(
          'raw',
          MultihashInfo(
            code: 0x00,
            name: 'identity',
            digest: inlineData,
            size: inlineData.length,
          ),
        );
        // No blocksizes: the traversal cannot map the file's byte range, so it
        // falls back to walking the node's links.
        final node = dag_pb.PBNode(
          links: <dag_pb.PBLink>[
            dag_pb.PBLink(hash: idCid.toBytes(), size: Int64(3)),
          ],
          data: unixfs_pb.Data(
            type: unixfs_pb.Data_DataType.File,
            filesize: Int64(3),
          ).writeToBuffer(),
        );
        final fileBytes = Uint8List.fromList(node.writeToBuffer());
        final fileCid = await CID.computeForData(fileBytes, format: 'dag-pb');
        stubBlock(fileCid, fileBytes);

        final response = await handler.handlePath(
          Request(
            'GET',
            Uri.parse(
              'http://localhost/ipfs/${fileCid.encode()}'
              '?format=car&entity-bytes=0:2',
            ),
          ),
        );
        expect(response.statusCode, equals(200));
        final body = await response.read().expand((i) => i).toList();
        final sections = await CarReader.fromBytes(Uint8List.fromList(body))
            .sections()
            .toList();
        expect(
          sections.map((s) => s.cid.encode()).toList(),
          equals([fileCid.encode()]),
        );
        verifyNever(mockBlockStore.getBlock(idCid.encode()));
      },
    );

    test('a malformed link target surfaces the decoder error', () async {
      final handler = makeHandler(null);

      // A link target that is neither a CID nor an identity CID: the
      // traversal surfaces the strict decoder's error instead of crashing.
      // A UnixFS file node is used because a directory's links are not part
      // of its entity.
      final node = dag_pb.PBNode(
        links: <dag_pb.PBLink>[
          dag_pb.PBLink(name: 'broken', hash: Uint8List.fromList([0x02, 0x03])),
        ],
        data: unixfs_pb.Data(
          type: unixfs_pb.Data_DataType.File,
          filesize: Int64(3),
          blocksizes: [Int64(3)],
        ).writeToBuffer(),
      );
      final fileBytes = Uint8List.fromList(node.writeToBuffer());
      final fileCid = await CID.computeForData(fileBytes, format: 'dag-pb');
      stubBlock(fileCid, fileBytes);

      final response = await handler.handlePath(
        Request(
          'GET',
          Uri.parse(
            'http://localhost/ipfs/${fileCid.encode()}'
            '?format=car&dag-scope=entity',
          ),
        ),
      );
      expect(response.statusCode, isNot(equals(200)));
    });
  });
}
