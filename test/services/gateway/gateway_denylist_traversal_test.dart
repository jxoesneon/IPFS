// test/services/gateway/gateway_denylist_traversal_test.dart
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
    when(
      mockBlockStore.getBlock(cid.encode()),
    ).thenAnswer((_) async => foundResponse(Block(cid: cid, data: data)));
  }

  /// Builds a UnixFS directory node with a single named link to [childCid]
  /// and returns the node bytes and the directory CID.
  Future<(CID, Uint8List)> makeDir(String linkName, CID childCid) async {
    final node = dag_pb.PBNode(
      links: <dag_pb.PBLink>[
        dag_pb.PBLink(name: linkName, hash: childCid.toBytes()),
      ],
      data: unixfs_pb.Data(
        type: unixfs_pb.Data_DataType.Directory,
      ).writeToBuffer(),
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
    when(
      mockBlockStore.getBlock(any),
    ).thenAnswer((_) async => GetBlockResponse()..found = false);
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
  });
}
