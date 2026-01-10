import 'package:test/test.dart';
import 'package:dart_ipfs/src/protocols/dht/connection_statistics.dart';
import 'package:dart_ipfs/src/proto/generated/dht/common_red_black_tree.pb.dart' as proto;

void main() {
  group('ConnectionStatistics', () {
    late ConnectionStatistics stats;

    setUp(() {
      stats = ConnectionStatistics();
    });

    test('starts with zero values', () {
      expect(stats.totalConnections, 0);
      expect(stats.disconnections, 0);
      expect(stats.averageConnectionDuration, 0);
      expect(stats.averageLatency, 0);
      expect(stats.bytesSent, 0);
      expect(stats.bytesReceived, 0);
    });

    test('incrementTotalConnections increases count', () {
      stats.incrementTotalConnections();
      expect(stats.totalConnections, 1);
    });

    test('incrementDisconnections updates count and time', () {
      stats.incrementDisconnections();
      expect(stats.disconnections, 1);
      expect(stats.lastDisconnectionTime, isNotNull);
    });

    test('updateConnectionDuration calculates simple moving average', () {
      // Add 5 samples of 100ms
      for (var i = 0; i < 5; i++) {
        stats.updateConnectionDuration(Duration(milliseconds: 100));
      }
      expect(stats.averageConnectionDuration, 100.0);

      // Add 5 samples of 200ms
      for (var i = 0; i < 5; i++) {
        stats.updateConnectionDuration(Duration(milliseconds: 200));
      }
      // (500 + 1000) / 10 = 150
      expect(stats.averageConnectionDuration, 150.0);
    });

    test('updateConnectionDuration maintains sliding window', () {
      // Fill window with 10 samples of 100ms
      for (var i = 0; i < 10; i++) {
        stats.updateConnectionDuration(Duration(milliseconds: 100));
      }
      expect(stats.averageConnectionDuration, 100.0);

      // Add a large sample to push out the first
      stats.updateConnectionDuration(Duration(milliseconds: 1100));
      
      // Window: 9 * 100 + 1100 = 2000 / 10 = 200
      expect(stats.averageConnectionDuration, 200.0);
    });

    test('increments data transfer counters', () {
      stats.incrementBytesSent(100);
      expect(stats.bytesSent, 100);

      stats.incrementBytesReceived(200);
      expect(stats.bytesReceived, 200);

      stats.incrementSuccessfulDataTransfers();
      expect(stats.successfulDataTransfers, 1);

      stats.incrementFailedDataTransfers();
      expect(stats.failedDataTransfers, 1);
    });

    test('updateLatency uses exponential moving average', () {
      // Initial update sets value (0 * 0.9 + val * 0.1) actually logic is:
      // averageLatency = alpha * latency + (1 - alpha) * averageLatency;
      // alpha = 0.1
      
      stats.updateLatency(100.0);
      // 0.1 * 100 + 0.9 * 0 = 10
      expect(stats.averageLatency, 10.0);

      stats.updateLatency(100.0);
      // 0.1 * 100 + 0.9 * 10 = 10 + 9 = 19
      expect(stats.averageLatency, 19.0);
    });

    test('updateFromPeerInfo updates status', () {
      final dump = proto.V_PeerInfo();
      
      // First update
      stats.updateFromPeerInfo(dump);
      expect(stats.isConnected, isTrue);
      expect(stats.wasConnected, isTrue);
      expect(stats.totalConnections, 1);
      expect(stats.lastSeen, isNotNull);

      // Second update shouldn't increment connection count
      stats.updateFromPeerInfo(dump);
      expect(stats.totalConnections, 1);
    });
  });
}
