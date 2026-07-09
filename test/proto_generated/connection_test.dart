// Auto-generated proto coverage tests. Do not hand-edit.

import 'package:test/test.dart';
import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart' as $0;
import 'package:dart_ipfs/src/proto/generated/connection.pbenum.dart';
import 'package:dart_ipfs/src/proto/generated/connection.pb.dart';

void main() {
  group('ConnectionState', () {
    test('round-trips and accessors work', () {
      final original = ConnectionState(peerId: 'a', status: ConnectionState_Status.values.first, connectedAt: $0.Timestamp.create(), metadata: [MapEntry('k', 'v')]);
      expect(original.peerId, 'a');
      expect(original.status, isNotNull);
      expect(original.connectedAt, isNotNull);
      expect(original.metadata['k'], isNotNull);
      expect(original.metadata.length, 1);
      original.hasPeerId();
      original.clearPeerId();
      original.hasStatus();
      original.clearStatus();
      original.hasConnectedAt();
      original.clearConnectedAt();
      original.metadata.clear();
      expect(ConnectionState.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = ConnectionState.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(ConnectionState.fromJson(json), isNotNull);
    });
  });

  group('ConnectionMetrics', () {
    test('round-trips and accessors work', () {
      final original = ConnectionMetrics(peerId: 'a', messagesSent: $fixnum.Int64(1), messagesReceived: $fixnum.Int64(1), bytesSent: $fixnum.Int64(1), bytesReceived: $fixnum.Int64(1), averageLatencyMs: 1);
      expect(original.peerId, 'a');
      expect(original.messagesSent, $fixnum.Int64(1));
      expect(original.messagesReceived, $fixnum.Int64(1));
      expect(original.bytesSent, $fixnum.Int64(1));
      expect(original.bytesReceived, $fixnum.Int64(1));
      expect(original.averageLatencyMs, 1);
      original.hasPeerId();
      original.clearPeerId();
      original.hasMessagesSent();
      original.clearMessagesSent();
      original.hasMessagesReceived();
      original.clearMessagesReceived();
      original.hasBytesSent();
      original.clearBytesSent();
      original.hasBytesReceived();
      original.clearBytesReceived();
      original.hasAverageLatencyMs();
      original.clearAverageLatencyMs();
      expect(ConnectionMetrics.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = ConnectionMetrics.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(ConnectionMetrics.fromJson(json), isNotNull);
    });
  });

}
