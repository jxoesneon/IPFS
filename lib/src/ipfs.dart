// src/ipfs.dart
import 'dart:typed_data';

import 'core/cid.dart';
import 'core/config/ipfs_config.dart';
import 'core/data_structures/link.dart';
import 'core/data_structures/node_stats.dart';
import 'core/data_structures/peer.dart';
import 'core/ipfs_node/ipfs_node.dart';
import 'core/storage/datastore.dart';
import 'protocols/bitswap/bitswap_handler.dart';
import 'protocols/pubsub/pubsub_message.dart';
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

  /// Restarts the IPFS node.
  ///
  /// This performs a graceful [stop] followed by [start].
  Future<void> restart() => _node.restart();

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

  /// Gets the health status of all node subsystems.
  ///
  /// Returns a nested map of subsystem names to status maps.
  Future<Map<String, dynamic>> getHealthStatus() => _node.getHealthStatus();

  /// Stream of bandwidth metrics for this node.
  ///
  /// In offline mode this stream emits no events.
  Stream<Map<String, dynamic>> get bandwidthMetrics => _node.bandwidthMetrics;

  /// Total bytes received by the node since it started.
  int get bandwidthIn => _node.bandwidthIn;

  /// Total bytes sent by the node since it started.
  int get bandwidthOut => _node.bandwidthOut;

  /// Number of peers currently in the DHT routing table.
  int get dhtPeerCount => _node.dhtPeerCount;

  /// Stream of new content CIDs added to the node.
  Stream<String> get onNewContent => _node.onNewContent;

  /// Gets the peer ID of the IPFS node.
  ///
  /// Throws [StateError] when the node is offline and has no network
  /// identity.
  String get peerId => _node.peerId;

  /// Gets the peer ID of the IPFS node.
  ///
  /// Deprecated alias for [peerId].
  @Deprecated('Use peerId instead.')
  String get peerID => _node.peerId;

  /// Broadcast stream of peers discovered via mDNS on the local network.
  ///
  /// Empty when mDNS is disabled or the node runs offline.
  Stream<Peer> get discoveredPeers => _node.discoveredPeers;

  /// Currently connected swarm peer IDs.
  Future<List<String>> get connectedPeers => _node.connectedPeers;

  /// Multiaddresses this node is listening on.
  List<String> get addresses => _node.addresses;

  /// The public key of this node as a base64-encoded protobuf.
  Future<String> get publicKey => _node.publicKey;

  /// Connects to a peer using its [multiaddr].
  Future<void> connectToPeer(String multiaddr) =>
      _node.connectToPeer(multiaddr);

  /// Gracefully disconnects from the peer identified by [peerIdOrAddr].
  Future<void> disconnectFromPeer(String peerIdOrAddr) =>
      _node.disconnectFromPeer(peerIdOrAddr);

  /// Resolves a [peerId] to its known multiaddresses.
  List<String> resolvePeerId(String peerId) => _node.resolvePeerId(peerId);

  /// Adds a file to the IPFS network from its raw data.
  ///
  /// Returns the CID of the added file as a string.
  Future<String> addFile(Uint8List data) async {
    return _node.addFile(data);
  }

  /// Adds a file to the IPFS network from a stream of bytes.
  ///
  /// Returns the CID of the added file as a string.
  Future<String> addFileStream(Stream<List<int>> dataStream) =>
      _node.addFileStream(dataStream);

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

  /// Gets the raw content associated with the given [cid].
  ///
  /// This is an alias for [get].
  Future<Uint8List?> cat(String cid) => _node.cat(cid);

  /// Sets the mode used for retrieving content.
  ///
  /// [customUrl] is required when [mode] is [GatewayMode.custom].
  void setGatewayMode(GatewayMode mode, {String? customUrl}) =>
      _node.setGatewayMode(mode, customUrl: customUrl);

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

  /// CIDs currently pinned by this node.
  Future<List<String>> get pinnedCids => _node.pinnedCids;

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
  /// Returns the IPNS name (base36-encoded peer ID) that was published.
  Future<String> publishIPNS(String cid, {required String keyName}) async {
    return _node.publishIPNS(cid, keyName: keyName);
  }

  /// Generates a new Ed25519 key pair stored under [name] and returns its
  /// IPNS name (base36-encoded libp2p-key CID).
  ///
  /// [type] currently only accepts `'ed25519'`. Ed25519 keys have a fixed
  /// 256-bit size, so [size] must be `null` or `256`; any other value throws
  /// [ArgumentError] rather than being silently ignored. The node's keystore
  /// must be unlocked first. Once stored, [name] can be passed as `keyName`
  /// to [publishIPNS].
  Future<String> keyGen(String name, {String type = 'ed25519', int? size}) =>
      _node.keyGen(name, type: type, size: size);

  /// Lists the key names stored in the node's keystore.
  Future<List<String>> keyList() => _node.keyList();

  /// Imports a raw 32-byte Ed25519 private key seed under [name] and returns
  /// its IPNS name.
  Future<String> keyImport(String name, Uint8List privateKey) =>
      _node.keyImport(name, privateKey);

  /// Returns the raw 32-byte Ed25519 private key seed stored under [name].
  ///
  /// The returned bytes are unencrypted private key material and must be
  /// handled as sensitive.
  Future<Uint8List> keyExport(String name) => _node.keyExport(name);

  /// Removes the key stored under [name]. The default `'self'` key cannot be
  /// removed.
  Future<void> keyRm(String name) => _node.keyRm(name);

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

  /// Announces to the network that this node provides the given [cid].
  ///
  /// Throws when the DHT announcement fails; a completed future means the
  /// provider record was actually announced.
  Future<void> provide(String cid) async {
    final dht = _node.dhtHandler;
    if (dht == null) {
      throw Exception('DHT not available (offline)');
    }
    return dht.provide(CID.decode(cid));
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

  /// Unsubscribes from a PubSub topic.
  Future<void> unsubscribe(String topic) async {
    return _node.unsubscribe(topic);
  }

  /// Publishes a message to a PubSub topic.
  Future<void> publish(String topic, String message) async {
    return _node.publish(topic, message);
  }

  /// Stream of incoming [PubSubMessage]s for all subscribed topics.
  ///
  /// In offline mode this stream emits no events.
  Stream<PubSubMessage> get pubsubMessages => _node.pubsubMessages;

  /// Stream of incoming [PubSubMessage]s filtered to a single [topic].
  Stream<PubSubMessage> messagesFor(String topic) =>
      pubsubMessages.where((message) => message.topic == topic);

  /// Topics this node is currently subscribed to.
  List<String> pubsubLs() => _node.pubsubLs();

  /// Peers known to be subscribed to [topic].
  ///
  /// Falls back to the global gossipsub mesh when no per-topic
  /// subscription data has been observed.
  Future<List<String>> pubsubPeers(String topic) => _node.pubsubPeers(topic);

  /// Resolves a DNSLink to its corresponding CID.
  Future<String> resolveDNSLink(String domainName) async {
    return _node.resolveDNSLink(domainName);
  }
}
