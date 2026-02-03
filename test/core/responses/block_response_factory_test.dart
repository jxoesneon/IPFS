// test/core/responses/block_response_factory_test.dart
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/responses/block_response_factory.dart';
import 'package:dart_ipfs/src/proto/generated/core/block.pb.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';
import 'package:test/test.dart';

/// Comprehensive tests for BlockResponseFactory utility methods.
void main() {
  group('BlockResponseFactory', () {
    group('Success Responses', () {
      test('successGet creates valid GetBlockResponse', () {
        final data = Uint8List.fromList([1, 2, 3, 4]);
        final cid = CID.computeForDataSync(data);

        final blockProto = BlockProto()
          ..cid = cid.toProto()
          ..data = data;

        final response = BlockResponseFactory.successGet(blockProto);

        expect(response.found, isTrue);
        expect(response.hasBlock(), isTrue);
        expect(response.block.data, equals(data));
      });

      test('successAdd creates valid AddBlockResponse', () {
        final message = 'Block added successfully';

        final response = BlockResponseFactory.successAdd(message);

        expect(response.success, isTrue);
        expect(response.message, equals(message));
      });

      test('successRemove creates valid RemoveBlockResponse', () {
        final message = 'Block removed successfully';

        final response = BlockResponseFactory.successRemove(message);

        expect(response.success, isTrue);
        expect(response.message, equals(message));
      });
    });

    group('Failure Responses', () {
      test('notFound creates GetBlockResponse with found=false', () {
        final response = BlockResponseFactory.notFound();

        expect(response.found, isFalse);
        expect(response.hasBlock(), isFalse);
      });

      test('failureAdd creates AddBlockResponse with success=false', () {
        final errorMsg = 'Failed to add block';

        final response = BlockResponseFactory.failureAdd(errorMsg);

        expect(response.success, isFalse);
        expect(response.message, equals(errorMsg));
      });

      test('failureRemove creates RemoveBlockResponse with success=false', () {
        final errorMsg = 'Failed to remove block';

        final response = BlockResponseFactory.failureRemove(errorMsg);

        expect(response.success, isFalse);
        expect(response.message, equals(errorMsg));
      });
    });

    group('Edge Cases', () {
      test('handles empty message strings', () {
        final response = BlockResponseFactory.successAdd('');

        expect(response.success, isTrue);
        expect(response.message, isEmpty);
      });

      test('handles very long error messages', () {
        final longMessage = 'Error: ${'x' * 1000}';

        final response = BlockResponseFactory.failureAdd(longMessage);

        expect(response.success, isFalse);
        expect(response.message.length, greaterThan(1000));
      });

      test('handles special characters in messages', () {
        final specialMsg = 'Error: \n\t"test" \${value}';

        final response = BlockResponseFactory.failureRemove(specialMsg);

        expect(response.message, contains('\n'));
        expect(response.message, contains('test'));
      });
    });

    group('Response Consistency', () {
      test('multiple successGet calls create independent responses', () {
        final data1 = Uint8List.fromList([1, 2, 3]);
        final data2 = Uint8List.fromList([4, 5, 6]);

        final block1 = BlockProto()..data = data1;
        final block2 = BlockProto()..data = data2;

        final response1 = BlockResponseFactory.successGet(block1);
        final response2 = BlockResponseFactory.successGet(block2);

        expect(response1.block.data, isNot(equals(response2.block.data)));
      });

      test('responses are properly typed', () {
        final getResp = BlockResponseFactory.notFound();
        final addResp = BlockResponseFactory.successAdd('test');
        final removeResp = BlockResponseFactory.successRemove('test');

        expect(getResp, isA<GetBlockResponse>());
        expect(addResp, isA<AddBlockResponse>());
        expect(removeResp, isA<RemoveBlockResponse>());
      });
    });
  });
}

