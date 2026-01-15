// src/ipfs.dart
import 'dart:typed_data';

import 'package:dart_ipfs/src/protocols/bitswap/bitswap_handler.dart';

import 'core/config/ipfs_config.dart';
import 'core/data_structures/link.dart';
import 'core/data_structures/node_stats.dart';
import 'core/data_structures/peer.dart';
import 'core/ipfs_node/ipfs_node.dart';
import 'core/storage/datastore.dart';
import 'transport/router_interface.dart';

/// Main entry point for the IPFS (InterPlanetary File System) implementation.
///
/// This class provides a high-level interface for interacting with IPFS,
/// including content storage, retrieval, pinning, and networking operations.
///
/// **Example Usage:**
/// ```dart
/// final ipfs = IPFS();
///
/// // Add content
/// final block = await Block.fromData(utf8.encode('Hello IPFS'));
/// await ipfs.store(block);
///
/// // Retrieve content
/// final retrieved = await ipfs.retrieve(block.cid.toString());
/// ```
///
/// For more advanced usage, consider using [IPFSNode] directly which provides
/// full control over configuration, networking, and services.
///
/// See also:
/// - [IPFSNode] for full-featured node operations
/// - `Block` for content-addressed data storage
/// - [CID] for content identifier operations
class IPFS {
  // Private constructor to enforce factory pattern
  IPFS._(this._node)
    : _datastore = _node.datastore,
      _router = _node.router,
      _bitswap = _node.bitswap;

  /// The underlying IPFSNode instance
  final IPFSNode _node;

  /// The datastore for persistent storage.
  final Datastore _datastore;

  /// The router for P2P networking.
  /// Null if running in offline mode.
  final RouterInterface? _router;

  /// The Bitswap protocol handler.
  /// Null if running in offline mode.
  final BitswapHandler? _bitswap;

  /// Creates a new IPFS node.
  ///
  /// You can optionally provide an [IPFSConfig] object to customize
  /// the node's configuration.
  static Future<IPFS> create({IPFSConfig? config}) async {
    config ??= IPFSConfig();
    final node = await IPFSNode.create(config);
    return IPFS._(node);
  }

  /// Starts the IPFS node.
  ///
  /// This initializes the networking, connects to the IPFS network,
  /// and starts all the necessary services and protocols.
  Future<void> start() async {
    await _node.start();
  }

  /// Stops the IPFS node.
  ///
  /// This closes all connections and shuts down the server gracefully.
  Future<void> stop() async {
    await _node.stop();
  }

  /// Gets the node's statistics.
  Future<NodeStats> stats() async {
    // Gather the actual statistics from the node's components

    // 1. Compute datastore stats by querying all blocks
    int numBlocks = 0;
    int datastoreSize = 0;

    await for (final entry in _datastore.query(Query(prefix: '/blocks/'))) {
      numBlocks++;
      if (entry.value != null) {
        datastoreSize += entry.value!.length;
      }
    }

    // 2. Get router stats
    final numConnectedPeers = _router?.connectedPeers.length ?? 0;

    // 3. Get Bitswap stats
    final bandwidthSent = _bitswap?.bandwidthSent ?? 0;
    final bandwidthReceived = _bitswap?.bandwidthReceived ?? 0;

    // 4. Construct and return the NodeStats object
    return NodeStats(
      numBlocks: numBlocks,
      datastoreSize: datastoreSize,
      numConnectedPeers: numConnectedPeers,
      bandwidthSent: bandwidthSent,
      bandwidthReceived: bandwidthReceived,
    );
  }

  /// Stream of new content CIDs added to the node.
  Stream<String> get onNewContent => _node.onNewContent;

  /// Gets the peer ID of the IPFS node.
  String get peerID => _node.peerID;

  /// Adds a file to the IPFS network from its raw data.
  ///
  /// Returns the CID of the added file as a string.
  Future<String> addFile(Uint8List data) async {
    return _node.addFile(data);
  }

  /// Adds a directory to IPFS.
  ///
  /// The [directoryContent] is a map where keys are file/directory names
  /// and values are either `Uint8List` (for files) or nested maps
  /// (for subdirectories).
  ///
  /// Returns the CID of the added directory.
  Future<String> addDirectory(Map<String, dynamic> directoryContent) async {
    return _node.addDirectory(directoryContent);
  }

  /// Gets the content of a file or directory from IPFS.
  ///
  /// You can optionally provide a [path] within the directory
  /// to retrieve a specific file.
  ///
  /// Returns the raw data of the file or directory.
  Future<Uint8List?> get(String cid, {String path = ''}) async {
    return _node.get(cid, path: path);
  }

  /// Lists the contents of a directory in IPFS.
  ///
  /// Returns a list of [Link] objects representing the directory entries.
  Future<List<Link>> ls(String cid) async {
    return _node.ls(cid);
  }

  /// Pins a CID to prevent it from being garbage collected.
  Future<void> pin(String cid) async {
    return _node.pin(cid);
  }

  /// Unpins a CID.
  Future<void> unpin(String cid) async {
    final success = await _node.unpin(cid);
    if (!success) {
      throw Exception('Failed to unpin CID: $cid');
    }
  }

  /// Resolves an IPNS name to its corresponding CID.
  Future<String> resolveIPNS(String ipnsName) async {
    final dht = _node.dhtHandler;
    if (dht == null) {
      throw Exception('DHT not available (offline)');
    }
    final resolvedCid = await dht.resolveIPNS(ipnsName);
    return resolvedCid;
  }

  /// Publishes an IPNS record.
  ///
  /// Requires an IPNS key to be configured in the keystore.
  Future<void> publishIPNS(String cid, {required String keyName}) async {
    return _node.publishIPNS(cid, keyName: keyName);
  }

  /// Imports a CAR file.
  Future<void> importCAR(Uint8List carFile) async {
    return _node.importCAR(carFile);
  }

  /// Exports a CAR file for the given CID.
  Future<Uint8List> exportCAR(String cid) async {
    return _node.exportCAR(cid);
  }

  /// Finds providers for a CID.
  Future<List<String>> findProviders(String cid) async {
    return _node
        .findProviders(cid)
        .then((peers) => peers.map((peer) => peer.toString()).toList());
  }

  /// Requests a block from the network using Bitswap.
  Future<void> requestBlock(String cid, String peerID) async {
    final peer = Peer.fromId(peerID);
    return _node.requestBlock(cid, peer);
  }

  /// Subscribes to a PubSub topic.
  Future<void> subscribe(String topic) async {
    return _node.subscribe(topic);
  }

  /// Publishes a message to a PubSub topic.
  Future<void> publish(String topic, String message) async {
    return _node.publish(topic, message);
  }

  /// Resolves a DNSLink to its corresponding CID.
  Future<String> resolveDNSLink(String domainName) async {
    return _node.resolveDNSLink(domainName);
  }
}
