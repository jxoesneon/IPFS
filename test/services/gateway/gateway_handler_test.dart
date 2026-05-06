import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dart_ipfs/src/services/gateway/gateway_handler.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';
import 'package:shelf/shelf.dart';

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
      final cidStr = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
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
      final cidStr = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
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
  });
}
