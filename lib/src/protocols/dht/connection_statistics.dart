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


  void incrementTotalConnections() {
    totalConnections++;
  }

  void incrementDisconnections() {
    disconnections++;
    lastDisconnectionTime = DateTime.now();
  }

  void updateConnectionDuration(Duration duration) {
    // Calculate average connection duration using a moving average or other suitable method
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
    // Calculate average latency using a moving average or other suitable method
  }
}
