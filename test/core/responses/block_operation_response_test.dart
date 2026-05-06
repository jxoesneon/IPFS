import 'package:test/test.dart';
import 'package:dart_ipfs/src/core/responses/block_operation_response.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';
import 'package:dart_ipfs/src/proto/generated/core/block.pb.dart';

void main() {
  group('BlockOperationResponse', () {
    test('success and failure factories', () {
      final success = BlockOperationResponse<int>.success('OK', 123);
      expect(success.success, isTrue);
      expect(success.data, equals(123));

      final failure = BlockOperationResponse<int>.failure('Error');
      expect(failure.success, isFalse);
    });

    test('fromProto AddBlockResponse', () {
      final proto = AddBlockResponse()
        ..success = true
        ..message = 'Added';
      final resp = BlockOperationResponse.fromProto(proto);
      expect(resp.success, isTrue);
      expect(resp.message, equals('Added'));
    });

    test('fromProto GetBlockResponse success', () {
      final blockProto = BlockProto()..data = [1, 2, 3];
      final proto = GetBlockResponse()
        ..found = true
        ..block = blockProto;
      final resp = BlockOperationResponse<BlockProto>.fromProto(proto);
      expect(resp.success, isTrue);
      expect(resp.data?.data, equals([1, 2, 3]));
    });

    test('fromProto GetBlockResponse not found', () {
      final proto = GetBlockResponse()..found = false;
      final resp = BlockOperationResponse<BlockProto>.fromProto(proto);
      expect(resp.success, isFalse);
    });

    test('fromProto unsupported type', () {
      expect(
        () => BlockOperationResponse.fromProto('not a proto'),
        throwsArgumentError,
      );
    });
  });
}
