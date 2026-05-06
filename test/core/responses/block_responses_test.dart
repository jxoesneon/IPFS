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

    test('toJson returns correct map', () {
      final resp = BlockAddResponse(success: true, message: 'Test message');
      final json = resp.toJson();
      expect(json['success'], isTrue);
      expect(json['message'], equals('Test message'));
    });

    test('toString returns formatted string', () {
      final resp = BlockAddResponse(success: false, message: 'Error');
      final str = resp.toString();
      expect(str, contains('BlockAddResponse'));
      expect(str, contains('success: false'));
      expect(str, contains('message: Error'));
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

    test('toJson returns correct map', () {
      final blockProto = BlockProto()..data = [4, 5, 6];
      final resp = BlockGetResponse(
        success: true,
        message: 'Retrieved',
        block: blockProto,
      );
      final json = resp.toJson();
      expect(json['success'], isTrue);
      expect(json['message'], equals('Retrieved'));
      expect(json['block'], isNotNull);
    });

    test('toJson with null block', () {
      final resp = BlockGetResponse(
        success: false,
        message: 'Not found',
        block: null,
      );
      final json = resp.toJson();
      expect(json['success'], isFalse);
      expect(json['block'], isNull);
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

    test('toJson returns correct map', () {
      final resp = BlockRemoveResponse(success: true, message: 'Deleted');
      final json = resp.toJson();
      expect(json['success'], isTrue);
      expect(json['message'], equals('Deleted'));
    });

    test('toString returns formatted string', () {
      final resp = BlockRemoveResponse(success: false, message: 'Failed');
      final str = resp.toString();
      expect(str, contains('BlockRemoveResponse'));
      expect(str, contains('success: false'));
      expect(str, contains('message: Failed'));
    });
  });
}
