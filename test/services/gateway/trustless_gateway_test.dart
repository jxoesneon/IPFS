import 'dart:typed_data';

import 'package:cbor/cbor.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/car.dart';
import 'package:dart_ipfs/src/core/security/denylist_service.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';
import 'package:dart_ipfs/src/protocols/bitswap/bitswap_handler.dart';
import 'package:dart_ipfs/src/protocols/ipns/ipns_record.dart';
import 'package:dart_ipfs/src/services/gateway/gateway_handler.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'gateway_handler_test.mocks.dart';
import 'trustless_gateway_test.mocks.dart';

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
          equals('application/vnd.ipfs.raw-block'),
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
          headers: {'accept': 'application/vnd.ipfs.raw-block'},
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(200));
        expect(
          response.headers['content-type'],
          equals('application/vnd.ipfs.raw-block'),
        );
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
          equals('application/vnd.ipfs.raw-block'),
        );
        expect(response.headers['x-ipfs-path'], equals('/ipfs/$cidStr'));
        final body = await response.read().expand((i) => i).toList();
        expect(body, equals(rawData));
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
          equals('application/vnd.ipfs.car'),
        );
        expect(
          response.headers['content-disposition'],
          equals('attachment; filename="$cidStr.car"'),
        );

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
          equals('application/vnd.ipfs.car'),
        );
        verify(mockBitswap.wantBlock(cidStr)).called(1);
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
        final body = await response.readAsString();
        expect(body, contains('"bytes"'));
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
    });

    group('?format=ipns-record', () {
      test('returns signed record bytes via resolver', () async {
        final record = IPNSRecord.internal(
          value: Uint8List.fromList('/ipfs/QmResolvedCid'.codeUnits),
          validity: DateTime.now().add(const Duration(hours: 1)),
          ttl: const Duration(minutes: 5),
        );
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
        expect(body, equals(recordBytes));
      });

      test('returns default TTL when record TTL is missing', () async {
        final recordBytes = Uint8List.fromList(cbor.encode(CborMap({})));

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
    });

    group('subdomain gateway', () {
      test('detects trustless format in subdomain request', () async {
        final block = makeBlock();
        when(
          mockBlockStore.getBlock(cidStr),
        ).thenAnswer((_) async => foundResponse(block));

        final request = Request(
          'GET',
          Uri.parse('http://localhost/'),
          headers: {
            'host': '$cidStr.ipfs.localhost',
            'accept': 'application/vnd.ipfs.raw-block',
          },
        );
        final response = await handler.handleSubdomain(request);
        expect(response.statusCode, equals(200));
        expect(
          response.headers['content-type'],
          equals('application/vnd.ipfs.raw-block'),
        );
      });
    });

    group('denylist', () {
      test('returns 451 for blocked CID with ?format=raw', () async {
        final denylist = DenylistService();
        denylist.blockCidString(cidStr);

        handler = GatewayHandler(mockBlockStore, denylistService: denylist);

        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr?format=raw'),
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(451));
        final body = await response.readAsString();
        expect(body, equals('Unavailable For Legal Reasons'));
      });

      test('returns 451 for blocked CID via path', () async {
        final denylist = DenylistService();
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
        final denylist = DenylistService();
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
