// Auto-generated proto coverage tests. Do not hand-edit.

import 'package:test/test.dart';
import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:dart_ipfs/src/proto/generated/ipns.pbenum.dart';
import 'package:dart_ipfs/src/proto/generated/ipns.pb.dart';

void main() {
  group('IpnsEntry', () {
    test('round-trips and accessors work', () {
      final original = IpnsEntry(value: const [0, 1, 2], signature: const [0, 1, 2], validityType: IpnsEntry_ValidityType.values.first, validity: const [0, 1, 2], sequence: $fixnum.Int64(1), ttl: $fixnum.Int64(1), pubKey: const [0, 1, 2]);
      expect(original.value, const [0, 1, 2]);
      expect(original.signature, const [0, 1, 2]);
      expect(original.validityType, isNotNull);
      expect(original.validity, const [0, 1, 2]);
      expect(original.sequence, $fixnum.Int64(1));
      expect(original.ttl, $fixnum.Int64(1));
      expect(original.pubKey, const [0, 1, 2]);
      original.hasValue();
      original.clearValue();
      original.hasSignature();
      original.clearSignature();
      original.hasValidityType();
      original.clearValidityType();
      original.hasValidity();
      original.clearValidity();
      original.hasSequence();
      original.clearSequence();
      original.hasTtl();
      original.clearTtl();
      original.hasPubKey();
      original.clearPubKey();
      expect(IpnsEntry.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = IpnsEntry.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(IpnsEntry.fromJson(json), isNotNull);
    });
  });

}
