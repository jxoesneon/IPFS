// Auto-generated proto coverage tests. Do not hand-edit.

import 'package:test/test.dart';
import 'package:dart_ipfs/src/proto/generated/core/bitfield.pb.dart';

void main() {
  group('BitFieldProto_SetBitRequest', () {
    test('round-trips and accessors work', () {
      final original = BitFieldProto_SetBitRequest(index: 1);
      expect(original.index, 1);
      original.hasIndex();
      original.clearIndex();
      expect(BitFieldProto_SetBitRequest.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = BitFieldProto_SetBitRequest.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) {});
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(BitFieldProto_SetBitRequest.fromJson(json), isNotNull);
    });
  });

  group('BitFieldProto_ClearBitRequest', () {
    test('round-trips and accessors work', () {
      final original = BitFieldProto_ClearBitRequest(index: 1);
      expect(original.index, 1);
      original.hasIndex();
      original.clearIndex();
      expect(BitFieldProto_ClearBitRequest.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = BitFieldProto_ClearBitRequest.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) {});
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(BitFieldProto_ClearBitRequest.fromJson(json), isNotNull);
    });
  });

  group('BitFieldProto_GetBitRequest', () {
    test('round-trips and accessors work', () {
      final original = BitFieldProto_GetBitRequest(index: 1);
      expect(original.index, 1);
      original.hasIndex();
      original.clearIndex();
      expect(BitFieldProto_GetBitRequest.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = BitFieldProto_GetBitRequest.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) {});
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(BitFieldProto_GetBitRequest.fromJson(json), isNotNull);
    });
  });

  group('BitFieldProto_BitResponse', () {
    test('round-trips and accessors work', () {
      final original = BitFieldProto_BitResponse(value: true);
      expect(original.value, true);
      original.hasValue();
      original.clearValue();
      expect(BitFieldProto_BitResponse.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = BitFieldProto_BitResponse.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) {});
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(BitFieldProto_BitResponse.fromJson(json), isNotNull);
    });
  });

  group('BitFieldProto', () {
    test('round-trips and accessors work', () {
      final original = BitFieldProto(bits: const [0, 1, 2], size: 1);
      expect(original.bits, const [0, 1, 2]);
      expect(original.size, 1);
      original.hasBits();
      original.clearBits();
      original.hasSize();
      original.clearSize();
      expect(BitFieldProto.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = BitFieldProto.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) {});
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(BitFieldProto.fromJson(json), isNotNull);
    });
  });
}
