import 'peer_score.dart';

/// Configuration for Gossipsub v1.1.
class PubSubConfig {
  /// Creates a Gossipsub configuration.
  const PubSubConfig({
    this.protocolId = '/meshsub/1.1.0',
    this.fallbackProtocolId = '/meshsub/1.0.0',
    this.historyLength = 5,
    this.gossipFactor = 3,
    this.d = 6,
    this.dLow = 4,
    this.dHigh = 12,
    this.heartbeatIntervalMs = 1000,
    this.signMessages = true,
    this.strictSign = true,
    this.maxMessageSize = 1048576, // 1 MiB
    this.topicScoreParams = const {},
    this.floodPublish = true,
    this.gossipRetransmission = 3,
    this.maxIHaveLength = 5000,
    this.maxIWantLength = 5000,
    this.pruneBackoffSeconds = 60,
  });

  /// Primary Gossipsub protocol ID.
  final String protocolId;

  /// Optional Gossipsub v1.0 protocol ID.
  final String? fallbackProtocolId;

  /// Number of heartbeats worth of message IDs to advertise in IHAVE.
  final int historyLength;

  /// Number of peers to gossip with per heartbeat (minimum).
  final int gossipFactor;

  /// Target topic mesh degree.
  final int d;

  /// Lower bound for mesh degree.
  final int dLow;

  /// Upper bound for mesh degree.
  final int dHigh;

  /// Heartbeat interval in milliseconds.
  final int heartbeatIntervalMs;

  /// Whether to sign outgoing messages.
  final bool signMessages;

  /// Whether to reject unsigned messages.
  final bool strictSign;

  /// Maximum allowed message size in bytes.
  final int maxMessageSize;

  /// Per-topic scoring parameters.
  final Map<String, TopicScoreParams> topicScoreParams;

  /// Whether to publish to all connected peers with acceptable score.
  final bool floodPublish;

  /// Number of times to retransmit an IHAVE gossip entry.
  final int gossipRetransmission;

  /// Maximum IHAVE message IDs to include per peer.
  final int maxIHaveLength;

  /// Maximum IWANT message IDs to request per peer.
  final int maxIWantLength;

  /// Backoff period in seconds after being pruned from a mesh.
  final int pruneBackoffSeconds;
}
