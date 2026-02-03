import 'package:dart_ipfs/src/proto/generated/dht/common_red_black_tree.pb.dart'
    show V_PeerInfo;

/// Statistics for a peer connection in the DHT.
///
/// Tracks connection count, duration, bandwidth, latency, and
/// success/failure rates for data transfers.
class ConnectionStatistics {
  /// Total number of connections established.
  int totalConnections = 0;

  /// Number of disconnections.
  int disconnections = 0;

  /// Moving average of connection duration in milliseconds.
  double averageConnectionDuration = 0;

  /// When the peer last disconnected.
  DateTime? lastDisconnectionTime;

  /// Total bytes sent to this peer.
  int bytesSent = 0;

  /// Total bytes received from this peer.
  int bytesReceived = 0;

  /// Number of successful data transfers.
  int successfulDataTransfers = 0;

  /// Number of failed data transfers.
  int failedDataTransfers = 0;

  /// Exponential moving average of latency in milliseconds.
  double averageLatency = 0;

  final List<int> _connectionDurations = [];

  /// Whether the peer is currently connected.
  bool isConnected = false;

  /// Whether the peer was previously connected.
  bool wasConnected = false;

  /// When this peer was last seen.
  DateTime? lastSeen;

  /// Increments the total connection count.
  void incrementTotalConnections() {
    totalConnections++;
  }

  /// Increments disconnection count and records the time.
  void incrementDisconnections() {
    disconnections++;
    lastDisconnectionTime = DateTime.now();
  }

  /// Updates average connection duration with a new sample.
  void updateConnectionDuration(Duration duration) {
    // Simple moving average
    const int windowSize = 10; // Adjust the window size as needed
    _connectionDurations.add(duration.inMilliseconds);

    if (_connectionDurations.length > windowSize) {
      _connectionDurations.removeAt(0);
    }

    averageConnectionDuration =
        _connectionDurations.reduce((a, b) => a + b) /
        _connectionDurations.length;
  }

  /// Adds to the bytes sent counter.
  void incrementBytesSent(int bytes) {
    bytesSent += bytes;
  }

  /// Adds to the bytes received counter.
  void incrementBytesReceived(int bytes) {
    bytesReceived += bytes;
  }

  /// Increments the successful transfer count.
  void incrementSuccessfulDataTransfers() {
    successfulDataTransfers++;
  }

  /// Increments the failed transfer count.
  void incrementFailedDataTransfers() {
    failedDataTransfers++;
  }

  /// Updates average latency using exponential moving average.
  void updateLatency(double latency) {
    // Exponential moving average
    const double alpha = 0.1; // Adjust the smoothing factor (alpha) as needed
    averageLatency = alpha * latency + (1 - alpha) * averageLatency;
  }

  /// Updates statistics based on peer info.
  void updateFromPeerInfo(V_PeerInfo peerInfo) {
    // Update relevant statistics based on peer info
    lastSeen = DateTime.now();
    isConnected = true;

    // Update connection count if this is a new connection
    if (!wasConnected) {
      totalConnections++;
      wasConnected = true;
    }
  }
}

