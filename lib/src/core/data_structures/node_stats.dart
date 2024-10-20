// lib/src/core/data_structures/node_stats.dart (create this file)

/// Represents statistics about the IPFS node.
class NodeStats {
  /// The number of blocks stored in the datastore.
  final int numBlocks;

  /// The total size of the blocks stored in the datastore (in bytes).
  final int datastoreSize;

  /// The number of connected peers.
  final int numConnectedPeers;

  /// The total bandwidth used for sending data (in bytes).
  final int bandwidthSent;

  /// The total bandwidth used for receiving data (in bytes).
  final int bandwidthReceived;

  /// Creates a new [NodeStats] instance.
  NodeStats({
    required this.numBlocks,
    required this.datastoreSize,
    required this.numConnectedPeers,
    required this.bandwidthSent,
    required this.bandwidthReceived,
  });

  @override
  String toString() {
    return 'NodeStats{'
        'numBlocks: $numBlocks, '
        'datastoreSize: $datastoreSize, '
        'numConnectedPeers: $numConnectedPeers, '
        'bandwidthSent: $bandwidthSent, '
        'bandwidthReceived: $bandwidthReceived'
        '}';
  }
}
