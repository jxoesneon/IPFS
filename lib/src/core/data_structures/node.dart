import 'dart:async';
import 'package:fixnum/fixnum.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/network/router.dart';
import 'package:dart_ipfs/src/core/storage/datastore.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/pubsub_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/routing_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/datastore_handler.dart';
import 'package:dart_ipfs/src/protocols/bitswap/bitswap_handler.dart';

/// Types of IPFS nodes in the UnixFS data model.
enum IPFSNodeType { file, directory, symlink, unknown }

/// Represents an IPFS data node with links and handlers.
///
/// IPFSDataNode is a high-level representation of content in IPFS,
/// combining the CID, links to child nodes, and access to node services.
class IPFSDataNode {
  /// The content identifier for this node.
  final CID cid;

  /// Links to child nodes in the DAG.
  final List<NodeLink> links;

  /// The type of this node (file, directory, etc).
  final IPFSNodeType nodeType;

  /// Custom metadata attached to this node.
  final Map<String, String> metadata;

  /// The cumulative size of this node and its children.
  final Int64 size;

  final IPFSConfig _config;

  late final BitswapHandler bitswapHandler;
  late final DHTHandler dhtHandler;
  late final DatastoreHandler datastoreHandler;
  late final RoutingHandler routingHandler;
  late final NetworkHandler networkHandler;
  late final PubSubHandler pubSubHandler;

  final _newContentController = StreamController<String>.broadcast();

  /// Access to the datastore.
  Datastore get datastore => datastoreHandler.datastore;

  /// Access to the network router.
  Router get router => networkHandler.router;

  /// Access to the Bitswap handler.
  BitswapHandler get bitswap => bitswapHandler;

  /// The node configuration.
  IPFSConfig get config => _config;

  /// Stream of new content CIDs.
  Stream<String> get onNewContent => _newContentController.stream;

  late final String _peerID;

  /// This node's peer ID.
  String get peerID => _peerID;

  /// Creates an IPFS data node.
  IPFSDataNode({
    required this.cid,
    required this.links,
    required this.nodeType,
    this.metadata = const {},
    required this.size,
    required IPFSConfig config,
  }) : _config = config;
}

/// A named link to another node in the DAG.
class NodeLink {
  /// The link name (filename in directories).
  final String name;

  /// The CID of the linked node.
  final CID cid;

  /// The size of the linked content.
  final Int64 size;

  /// Custom metadata for this link.
  final Map<String, String> metadata;

  /// Creates a node link.
  NodeLink({
    required this.name,
    required this.cid,
    required this.size,
    this.metadata = const {},
  });
}
