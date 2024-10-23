// lib/src/protocols/dht/connection_statistics.dart

class ConnectionStatistics {
  int totalConnections = 0;
  int disconnections = 0;
  double averageConnectionDuration = 0; 
  DateTime? lastDisconnectionTime;
  int bytesSent = 0;
  int bytesReceived = 0;
  int successfulDataTransfers = 0;
  int failedDataTransfers = 0;
  double averageLatency = 0;
  final List<int> _connectionDurations = [];




  void incrementTotalConnections() {
    totalConnections++;
  }

  void incrementDisconnections() {
    disconnections++;
    lastDisconnectionTime = DateTime.now();
  }

void updateConnectionDuration(Duration duration) {
  // Simple moving average
  const int windowSize = 10; // Adjust the window size as needed
  _connectionDurations.add(duration.inMilliseconds);

  if (_connectionDurations.length > windowSize) {
      _connectionDurations.removeAt(0);
  }

  averageConnectionDuration = _connectionDurations.reduce((a, b) => a + b) / _connectionDurations.length;
}

  void incrementBytesSent(int bytes) {
    bytesSent += bytes;
  }

  void incrementBytesReceived(int bytes) {
    bytesReceived += bytes;
  }

  void incrementSuccessfulDataTransfers() {
    successfulDataTransfers++;
  }

  void incrementFailedDataTransfers() {
    failedDataTransfers++;
  }

void updateLatency(double latency) {
  // Exponential moving average
  const double alpha = 0.1; // Adjust the smoothing factor (alpha) as needed
  averageLatency = alpha * latency + (1 - alpha) * averageLatency;
}



}
