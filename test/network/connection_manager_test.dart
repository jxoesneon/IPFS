import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/network/connection_manager.dart';
import 'package:dart_ipfs/src/proto/generated/connection.pb.dart';
import 'package:fixnum/fixnum.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'connection_manager_test.mocks.dart';

@GenerateMocks([MetricsCollector])
void main() {
  late MockMetricsCollector mockMetrics;
  late ConnectionManager manager;

  setUp(() {
    mockMetrics = MockMetricsCollector();

    // Set up default stubs for metrics
    when(mockMetrics.getMessagesSent(any)).thenReturn(Int64(10));
    when(mockMetrics.getMessagesReceived(any)).thenReturn(Int64(20));
    when(mockMetrics.getBytesSent(any)).thenReturn(Int64(1024));
    when(mockMetrics.getBytesReceived(any)).thenReturn(Int64(2048));
    when(
      mockMetrics.getAverageLatency(any),
    ).thenReturn(Duration(milliseconds: 50));
    when(mockMetrics.updateConnectionMetrics(any)).thenAnswer((_) async => {});

    manager = ConnectionManager(mockMetrics);
  });

  group('ConnectionManager', () {
    test('handleNewConnection creates state and updates metrics', () async {
      final peerId = 'peer-123';
      await manager.handleNewConnection(peerId);

      final captured =
          verify(
                mockMetrics.updateConnectionMetrics(captureAny),
              ).captured.single
              as ConnectionMetrics;
      expect(captured.peerId, equals(peerId));
      expect(captured.messagesSent, equals(Int64(10)));
      expect(captured.messagesReceived, equals(Int64(20)));
      expect(captured.bytesSent, equals(Int64(1024)));
      expect(captured.bytesReceived, equals(Int64(2048)));
      expect(captured.averageLatencyMs, equals(50));
    });
  });
}
