import 'package:test/test.dart';
import 'package:dart_ipfs/src/core/responses/response_handler.dart';
import 'package:dart_ipfs/src/core/responses/block_operation_response.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'dart:typed_data';

void main() {
  group('ResponseHandler', () {
    test('toAddBlockResponse', () {
      final resp = BlockOperationResponse.success('Added');
      final pb = ResponseHandler.toAddBlockResponse(resp);
      expect(pb.success, isTrue);
      expect(pb.message, equals('Added'));
    });

    test('toGetBlockResponse', () {
      final cid = CID.decode('QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn');
      final block = Block(cid: cid, data: Uint8List.fromList([1, 2, 3]));
      final resp = BlockOperationResponse<Block>.success('Found', block);

      final pb = ResponseHandler.toGetBlockResponse(resp);
      expect(pb.found, isTrue);
      expect(pb.block.data, equals([1, 2, 3]));
    });

    test('toRemoveBlockResponse', () {
      final resp = BlockOperationResponse.success('Removed');
      final pb = ResponseHandler.toRemoveBlockResponse(resp);
      expect(pb.success, isTrue);
    });

    test('fromProtoResponse GetBlockResponse', () {
      final cid = CID.decode('QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn');
      final block = Block(cid: cid, data: Uint8List.fromList([1, 2, 3]));
      final pb = GetBlockResponse()
        ..found = true
        ..block = block.toProto();

      final resp = ResponseHandler.fromProtoResponse(pb);
      expect(resp.success, isTrue);
      expect((resp.data as Block).data, equals([1, 2, 3]));
    });
  });
}
