// test/services/gateway/gateway_trustless_handler_test.dart
import 'dart:typed_data';

import 'package:cbor/cbor.dart';
import 'package:dart_ipfs/dart_ipfs.dart' hide CID, Block;
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/config/security_config.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/security/denylist_service.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart';
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart';
import 'package:dart_ipfs/src/services/gateway/gateway_content_handler.dart';
import 'package:dart_ipfs/src/services/gateway/gateway_directory_handler.dart';
import 'package:dart_ipfs/src/services/gateway/gateway_handler.dart';
import 'package:dart_ipfs/src/services/gateway/gateway_trustless_handler.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'gateway_handler_test.mocks.dart';

@GenerateNiceMocks([MockSpec<BlockStore>()])
class _MockMetrics implements MetricsCollector {
  @override
  void recordSecurityEvent(String type) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MockBlockStore mockBlockStore;
  late GatewayContentHandler contentHandler;
  late GatewayTrustlessHandler trustlessHandler;

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
    final dirHandler = GatewayDirectoryHandler();
    contentHandler = GatewayContentHandler(
      blockStore: mockBlockStore,
      directoryHandler: dirHandler,
    );
    trustlessHandler = GatewayTrustlessHandler(contentHandler: contentHandler);
  });

  group('GatewayTrustlessHandler', () {
    group('detectTrustlessFormat', () {
      test('detects raw from ?format=raw', () {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr?format=raw'),
        );
        expect(
          trustlessHandler.detectTrustlessFormat(request),
          equals(TrustlessFormat.raw),
        );
      });

      test('detects car from ?format=car', () {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr?format=car'),
        );
        expect(
          trustlessHandler.detectTrustlessFormat(request),
          equals(TrustlessFormat.car),
        );
      });

      test('detects dag-json from ?format=dag-json', () {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr?format=dag-json'),
        );
        expect(
          trustlessHandler.detectTrustlessFormat(request),
          equals(TrustlessFormat.dagJson),
        );
      });

      test('detects dag-cbor from ?format=dag-cbor', () {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr?format=dag-cbor'),
        );
        expect(
          trustlessHandler.detectTrustlessFormat(request),
          equals(TrustlessFormat.dagCbor),
        );
      });

      test('detects ipns-record from ?format=ipns-record', () {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr?format=ipns-record'),
        );
        expect(
          trustlessHandler.detectTrustlessFormat(request),
          equals(TrustlessFormat.ipnsRecord),
        );
      });

      test('returns null for unknown format', () {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr?format=unknown'),
        );
        expect(trustlessHandler.detectTrustlessFormat(request), isNull);
      });

      test('detects from Accept header', () {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr'),
          headers: {'accept': 'application/vnd.ipfs.car'},
        );
        expect(
          trustlessHandler.detectTrustlessFormat(request),
          equals(TrustlessFormat.car),
        );
      });

      test('?format= takes precedence over Accept header', () {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr?format=raw'),
          headers: {'accept': 'application/vnd.ipfs.car'},
        );
        expect(
          trustlessHandler.detectTrustlessFormat(request),
          equals(TrustlessFormat.raw),
        );
      });

      test('returns null when no format specified', () {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr'),
          headers: {'accept': 'text/html'},
        );
        expect(trustlessHandler.detectTrustlessFormat(request), isNull);
      });

      test('parses Accept header with q-values', () {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr'),
          headers: {
            'accept': 'text/html;q=0.9, application/vnd.ipfs.car;q=1.0',
          },
        );
        expect(
          trustlessHandler.detectTrustlessFormat(request),
          equals(TrustlessFormat.car),
        );
      });
    });

    group('serveRawBlock', () {
      test('serves raw block with correct headers', () async {
        final block = makeBlock();
        when(
          mockBlockStore.getBlock(cidStr),
        ).thenAnswer((_) async => foundResponse(block));

        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr'),
        );
        final response = await trustlessHandler.serveRawBlock(
          CID.decode(cidStr),
          request,
        );

        expect(response.statusCode, equals(200));
        expect(
          response.headers['content-type'],
          equals('application/vnd.ipfs.raw-block'),
        );
        expect(response.headers['x-content-type-options'], equals('nosniff'));
        final body = await response.read().expand((i) => i).toList();
        expect(body, equals(rawData));
      });

      test('returns 404 when block not found', () async {
        when(
          mockBlockStore.getBlock(any),
        ).thenAnswer((_) async => notFoundResponse());

        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr'),
        );
        final response = await trustlessHandler.serveRawBlock(
          CID.decode(cidStr),
          request,
        );

        expect(response.statusCode, equals(404));
      });

      test('sets X-IPFS-Path from ipnsPath when provided', () async {
        final block = makeBlock();
        when(
          mockBlockStore.getBlock(cidStr),
        ).thenAnswer((_) async => foundResponse(block));

        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr'),
        );
        final response = await trustlessHandler.serveRawBlock(
          CID.decode(cidStr),
          request,
          ipnsPath: '/ipns/test.example.com',
        );

        expect(
          response.headers['x-ipfs-path'],
          equals('/ipns/test.example.com'),
        );
      });
    });

    group('serveDagJson', () {
      test('serves raw codec as DAG-JSON', () async {
        final rawCid = CID.v1('raw', CID.decode(cidStr).multihash);
        final block = Block(cid: rawCid, data: rawData);
        when(
          mockBlockStore.getBlock(rawCid.encode()),
        ).thenAnswer((_) async => foundResponse(block));

        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/${rawCid.encode()}'),
        );
        final response = await trustlessHandler.serveDagJson(rawCid, request);

        expect(response.statusCode, equals(200));
        expect(
          response.headers['content-type'],
          equals('application/vnd.ipld.dag-json'),
        );
      });

      test('returns 404 when block not found', () async {
        when(
          mockBlockStore.getBlock(any),
        ).thenAnswer((_) async => notFoundResponse());

        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr'),
        );
        final response = await trustlessHandler.serveDagJson(
          CID.decode(cidStr),
          request,
        );

        expect(response.statusCode, equals(404));
      });
    });

    group('serveDagCbor', () {
      test('serves raw codec as DAG-CBOR', () async {
        final rawCid = CID.v1('raw', CID.decode(cidStr).multihash);
        final block = Block(cid: rawCid, data: rawData);
        when(
          mockBlockStore.getBlock(rawCid.encode()),
        ).thenAnswer((_) async => foundResponse(block));

        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/${rawCid.encode()}'),
        );
        final response = await trustlessHandler.serveDagCbor(rawCid, request);

        expect(response.statusCode, equals(200));
        expect(
          response.headers['content-type'],
          equals('application/vnd.ipld.dag-cbor'),
        );
      });

      test('returns 404 when block not found', () async {
        when(
          mockBlockStore.getBlock(any),
        ).thenAnswer((_) async => notFoundResponse());

        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr'),
        );
        final response = await trustlessHandler.serveDagCbor(
          CID.decode(cidStr),
          request,
        );

        expect(response.statusCode, equals(404));
      });
    });

    group('serveIpnsRecord', () {
      test('returns 501 when no resolver configured', () async {
        final request = Request('GET', Uri.parse('http://localhost/ipns/test'));
        final response = await trustlessHandler.serveIpnsRecord(
          'test',
          request,
        );

        expect(response.statusCode, equals(501));
      });

      test('returns 404 when record not found', () async {
        trustlessHandler = GatewayTrustlessHandler(
          contentHandler: contentHandler,
          ipnsRecordResolver: (_) async => null,
        );

        final request = Request('GET', Uri.parse('http://localhost/ipns/test'));
        final response = await trustlessHandler.serveIpnsRecord(
          'test',
          request,
        );

        expect(response.statusCode, equals(404));
      });

      test('returns 404 when record is empty', () async {
        trustlessHandler = GatewayTrustlessHandler(
          contentHandler: contentHandler,
          ipnsRecordResolver: (_) async => Uint8List(0),
        );

        final request = Request('GET', Uri.parse('http://localhost/ipns/test'));
        final response = await trustlessHandler.serveIpnsRecord(
          'test',
          request,
        );

        expect(response.statusCode, equals(404));
      });

      test('serves record with correct content type', () async {
        final recordBytes = Uint8List.fromList([1, 2, 3, 4]);
        trustlessHandler = GatewayTrustlessHandler(
          contentHandler: contentHandler,
          ipnsRecordResolver: (_) async => recordBytes,
        );

        final request = Request('GET', Uri.parse('http://localhost/ipns/test'));
        final response = await trustlessHandler.serveIpnsRecord(
          'test',
          request,
        );

        expect(response.statusCode, equals(200));
        expect(
          response.headers['content-type'],
          equals('application/vnd.ipfs.ipns-record'),
        );
        expect(response.headers['x-ipfs-path'], equals('/ipns/test'));
        final body = await response.read().expand((i) => i).toList();
        expect(body, equals(recordBytes));
      });
    });

    group('serveTrustless dispatch', () {
      test('dispatches to raw block for raw format', () async {
        final block = makeBlock();
        when(
          mockBlockStore.getBlock(cidStr),
        ).thenAnswer((_) async => foundResponse(block));

        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr'),
        );
        final response = await trustlessHandler.serveTrustless(
          CID.decode(cidStr),
          '',
          TrustlessFormat.raw,
          request,
        );

        expect(response.statusCode, equals(200));
        expect(
          response.headers['content-type'],
          equals('application/vnd.ipfs.raw-block'),
        );
      });

      test('returns 400 for ipns-record format on /ipfs/ path', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr'),
        );
        final response = await trustlessHandler.serveTrustless(
          CID.decode(cidStr),
          '',
          TrustlessFormat.ipnsRecord,
          request,
        );

        expect(response.statusCode, equals(400));
      });
    });

    group('checkDenylist', () {
      test('returns null when no denylist service configured', () {
        expect(trustlessHandler.checkDenylist('/ipfs/$cidStr'), isNull);
      });

      test('returns 451 when content is blocked', () {
        final denylist = DenylistService(
          const SecurityConfig(enableDenylist: true),
          _MockMetrics(),
        )..blockCidString(cidStr);
        trustlessHandler = GatewayTrustlessHandler(
          contentHandler: contentHandler,
          denylistService: denylist,
        );

        final response = trustlessHandler.checkDenylist('/ipfs/$cidStr');
        expect(response, isNotNull);
        expect(response!.statusCode, equals(451));
      });
    });
  });
}
