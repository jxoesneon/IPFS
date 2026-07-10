// Auto-generated proto coverage tests. Do not hand-edit.

import 'package:test/test.dart';
import 'package:dart_ipfs/src/proto/generated/dht/common_kademlia.pb.dart'
    as $0;
import 'package:dart_ipfs/src/proto/generated/dht/dht_messages.pb.dart';

void main() {
  group('PingRequest', () {
    test('round-trips and accessors work', () {
      final original = PingRequest(peerId: $0.KademliaId.create());
      expect(original.peerId, isNotNull);
      original.hasPeerId();
      original.clearPeerId();
      expect(PingRequest.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = PingRequest.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) {});
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(PingRequest.fromJson(json), isNotNull);
    });
  });

  group('PingResponse', () {
    test('round-trips and accessors work', () {
      final original = PingResponse(
        peerId: $0.KademliaId.create(),
        success: true,
      );
      expect(original.peerId, isNotNull);
      expect(original.success, true);
      original.hasPeerId();
      original.clearPeerId();
      original.hasSuccess();
      original.clearSuccess();
      expect(PingResponse.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = PingResponse.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) {});
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(PingResponse.fromJson(json), isNotNull);
    });
  });
}
