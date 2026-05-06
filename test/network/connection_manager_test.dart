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
    when(mockMetrics.getMessagesSent(any)).thenReturn(10);
    when(mockMetrics.getMessagesReceived(any)).thenReturn(20);
    when(mockMetrics.getBytesSent(any)).thenReturn(1024);
    when(mockMetrics.getBytesReceived(any)).thenReturn(2048);
    when(mockMetrics.getAverageLatency(any)).thenReturn(50.0);
    when(
      mockMetrics.updateConnectionMetrics(any, any),
    ).thenAnswer((_) async {});

    manager = ConnectionManager(mockMetrics);
  });

  group('ConnectionManager', () {
    test('handleNewConnection creates state and updates metrics', () async {
      final peerId = 'peer-123';
      await manager.handleNewConnection(peerId);

      final captured = verify(
        mockMetrics.updateConnectionMetrics(captureAny, captureAny),
      ).captured;
      expect(captured[0], equals(peerId));
      expect(captured[1], isA<Map<String, dynamic>>());
    });
  });
}
