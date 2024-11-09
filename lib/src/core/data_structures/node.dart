import 'dart:async';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/bitswap_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/datastore_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/dht_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/pubsub_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/routing_handler.dart';
import 'package:dart_ipfs/src/network/router.dart';
import 'package:dart_ipfs/src/storage/datastore.dart';
import 'package:fixnum/fixnum.dart';

enum IPFSNodeType { file, directory, symlink, unknown }

class IPFSDataNode {
  final CID cid;
  final List<NodeLink> links;
  final IPFSNodeType nodeType;
  final Map<String, String> metadata;
  final Int64 size;
  final IPFSConfig _config;

  late final BitswapHandler bitswapHandler;
  late final DHTHandler dhtHandler;
  late final DatastoreHandler datastoreHandler;
  late final RoutingHandler routingHandler;
  late final NetworkHandler networkHandler;
  late final PubSubHandler pubSubHandler;

  final _newContentController = StreamController<String>.broadcast();

  // Add getters for the handlers
  Datastore get datastore => datastoreHandler.datastore;
  Router get router => networkHandler.router;
  BitswapHandler get bitswap => bitswapHandler;
  IPFSConfig get config => _config;

  // Add the onNewContent stream getter
  Stream<String> get onNewContent => _newContentController.stream;

  // Add this field to store the peer ID
  late final String _peerID;

  // Add this getter
  String get peerID => _peerID;

  IPFSDataNode({
    required this.cid,
    required this.links,
    required this.nodeType,
    this.metadata = const {},
    required this.size,
    required IPFSConfig config,
  }) : _config = config;
}

class NodeLink {
  final String name;
  final CID cid;
  final Int64 size;
  final Map<String, String> metadata;

  NodeLink({
    required this.name,
    required this.cid,
    required this.size,
    this.metadata = const {},
  });
}
