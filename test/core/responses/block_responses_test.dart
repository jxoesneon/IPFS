import 'package:test/test.dart';
import 'package:dart_ipfs/src/core/responses/block_responses.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';
import 'package:dart_ipfs/src/proto/generated/core/block.pb.dart';

void main() {
  group('BlockAddResponse', () {
    test('toProto and fromProto', () {
      final resp = BlockAddResponse(success: true, message: 'Added');
      final pb = resp.toProto();
      expect(pb.success, isTrue);

      final fromPb = BlockAddResponse.fromProto(pb);
      expect(fromPb.success, isTrue);
      expect(fromPb.toJson()['message'], equals('Added'));
    });
  });

  group('BlockGetResponse', () {
    test('toProto and fromProto', () {
      final blockProto = BlockProto()..data = [1, 2, 3];
      final resp = BlockGetResponse(
        success: true,
        message: 'Found',
        block: blockProto,
      );

      final pb = resp.toProto();
      expect(pb.found, isTrue);

      final fromPb = BlockGetResponse.fromProto(pb);
      expect(fromPb.success, isTrue);
      expect(fromPb.block?.data, equals([1, 2, 3]));
      expect(resp.toString(), contains('success: true'));
    });
  });

  group('BlockRemoveResponse', () {
    test('toProto and fromProto', () {
      final resp = BlockRemoveResponse(success: true, message: 'Removed');
      final pb = resp.toProto();
      expect(pb.success, isTrue);

      final fromPb = BlockRemoveResponse.fromProto(pb);
      expect(fromPb.success, isTrue);
    });
  });
}
