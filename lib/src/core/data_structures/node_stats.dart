// lib/src/core/data_structures/node_stats.dart

import 'package:fixnum/fixnum.dart' as fixnum;
import '/../src/proto/dht/node_stats.pb.dart' as proto; // Import the generated Protobuf file

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

  /// Creates a [NodeStats] instance from its Protobuf representation.
  factory NodeStats.fromProto(proto.NodeStats pbNodeStats) {
    return NodeStats(
      numBlocks: pbNodeStats.numBlocks,
      datastoreSize: pbNodeStats.datastoreSize.toInt(),
      numConnectedPeers: pbNodeStats.numConnectedPeers,
      bandwidthSent: pbNodeStats.bandwidthSent.toInt(),
      bandwidthReceived: pbNodeStats.bandwidthReceived.toInt(),
    );
  }

  /// Converts the [NodeStats] instance to its Protobuf representation.
  proto.NodeStats toProto() {
    return proto.NodeStats()
      ..numBlocks = numBlocks
      ..datastoreSize = fixnum.Int64(datastoreSize)
      ..numConnectedPeers = numConnectedPeers
      ..bandwidthSent = fixnum.Int64(bandwidthSent)
      ..bandwidthReceived = fixnum.Int64(bandwidthReceived);
  }

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
