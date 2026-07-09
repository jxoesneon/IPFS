// Auto-generated proto coverage tests. Do not hand-edit.

import 'package:test/test.dart';
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart' as $0;
import 'package:dart_ipfs/src/proto/generated/base_messages.pbenum.dart';
import 'package:dart_ipfs/src/proto/generated/base_messages.pb.dart';

void main() {
  group('IPFSMessage', () {
    test('round-trips and accessors work', () {
      final original = IPFSMessage(protocolId: 'a', payload: const [0, 1, 2], timestamp: $0.Timestamp.create(), senderId: 'a', type: IPFSMessage_MessageType.values.first, requestId: 'a');
      expect(original.protocolId, 'a');
      expect(original.payload, const [0, 1, 2]);
      expect(original.timestamp, isNotNull);
      expect(original.senderId, 'a');
      expect(original.type, isNotNull);
      expect(original.requestId, 'a');
      original.hasProtocolId();
      original.clearProtocolId();
      original.hasPayload();
      original.clearPayload();
      original.hasTimestamp();
      original.clearTimestamp();
      original.hasSenderId();
      original.clearSenderId();
      original.hasType();
      original.clearType();
      original.hasRequestId();
      original.clearRequestId();
      expect(IPFSMessage.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = IPFSMessage.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(IPFSMessage.fromJson(json), isNotNull);
    });
  });

  group('NetworkEvent', () {
    test('round-trips and accessors work', () {
      final original = NetworkEvent(timestamp: $0.Timestamp.create(), eventType: 'a', peerId: 'a', data: const [0, 1, 2]);
      expect(original.timestamp, isNotNull);
      expect(original.eventType, 'a');
      expect(original.peerId, 'a');
      expect(original.data, const [0, 1, 2]);
      original.hasTimestamp();
      original.clearTimestamp();
      original.hasEventType();
      original.clearEventType();
      original.hasPeerId();
      original.clearPeerId();
      original.hasData();
      original.clearData();
      expect(NetworkEvent.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = NetworkEvent.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(NetworkEvent.fromJson(json), isNotNull);
    });
  });

}
