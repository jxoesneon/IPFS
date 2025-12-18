import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/responses/block_operation_response.dart';
import 'package:dart_ipfs/src/core/responses/block_response_handler.dart';
import 'package:dart_ipfs/src/core/responses/block_responses.dart';
import 'package:dart_ipfs/src/core/responses/response_handler.dart';
import 'package:dart_ipfs/src/proto/generated/core/block.pb.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';
import 'package:test/test.dart';

void main() {
  group('BlockResponseHandler', () {
    test('success returns successful AddBlockResponse', () {
      final resp = BlockResponseHandler.success('Added');
      expect(resp.success, isTrue);
      expect(resp.message, 'Added');
    });

    test('failure returns failed AddBlockResponse', () {
      final resp = BlockResponseHandler.failure('Failed');
      expect(resp.success, isFalse);
      expect(resp.message, 'Failed');
    });

    test('found returns valid GetBlockResponse', () {
      final block = BlockProto()..data = Uint8List(0);
      final resp = BlockResponseHandler.found(block);
      expect(resp.found, isTrue);
      expect(resp.block, block);
    });

    test('notFound returns empty GetBlockResponse', () {
      final resp = BlockResponseHandler.notFound();
      expect(resp.found, isFalse);
    });
  });

  group('ResponseHandler', () {
    test('toAddBlockResponse', () {
      final op = const BlockOperationResponse<dynamic>(success: true, message: 'OK');
      final proto = ResponseHandler.toAddBlockResponse(op);
      expect(proto.success, isTrue);
      expect(proto.message, 'OK');
    });

    test('toGetBlockResponse', () {
      // Need Block instance
      final bytes = Uint8List(1);
      final cid = CID.computeForDataSync(bytes);
      final block = Block(cid: cid, data: bytes);

      final op = BlockOperationResponse<Block>(
        success: true,
        message: 'OK',
        data: block,
      );
      final proto = ResponseHandler.toGetBlockResponse(op);

      expect(proto.found, isTrue);
      expect(proto.block.data, bytes);
      expect(proto.block.cid, isNotNull);
    });

    test('fromProtoResponse handles AddBlockResponse', () {
      final proto = AddBlockResponse()
        ..success = true
        ..message = 'Yes';
      final op = ResponseHandler.fromProtoResponse(proto);
      expect(op.success, isTrue);
      expect(op.message, 'Yes');
    });
  });

  group('BlockResponses Wrapper Classes', () {
    test('BlockAddResponse', () {
      final proto = AddBlockResponse()
        ..success = true
        ..message = 'Done';
      final wrapper = BlockAddResponse.fromProto(proto);
      expect(wrapper.success, isTrue);
      expect(wrapper.toJson(), {'success': true, 'message': 'Done'});
      expect(wrapper.toProto().success, isTrue);
      expect(wrapper.toString(), contains('success: true'));
    });

    test('BlockGetResponse', () {
      final proto = GetBlockResponse()..found = false;
      final wrapper = BlockGetResponse.fromProto(proto);
      expect(wrapper.success, isFalse);
      expect(wrapper.message, 'Block not found');
      expect(
        wrapper.toProto().found,
        isFalse,
      ); // Need to check if toProto handles null block
      // BlockGetResponse.toProto calls block!, so we shouldn't call it if block is null?
      // Let's check logic.
    });
  });
}
