class NetworkConfig {
  final List<String> bootstrapPeers;
  final Map<String, dynamic> protocolSettings;
  final Duration connectionTimeout;
  final int maxConnections;

  NetworkConfig({
    required this.bootstrapPeers,
    required this.protocolSettings,
    this.connectionTimeout = const Duration(seconds: 30),
    this.maxConnections = 50,
  });
}

class ProtocolConfig {
  final String protocolId;
  final Duration messageTimeout;
  final int maxRetries;

  ProtocolConfig({
    required this.protocolId,
    this.messageTimeout = const Duration(seconds: 10),
    this.maxRetries = 3,
  });
}
