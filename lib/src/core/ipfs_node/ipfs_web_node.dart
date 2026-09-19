// Web-only IPFS functionality that avoids p2plib dependencies.
//
// This provides a subset of IPFS functionality for web browsers
// without requiring the full P2P networking stack.

import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/security/security_manager_web.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_builder.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_reader.dart';
import 'package:dart_ipfs/src/platform/platform.dart';
import 'package:dart_ipfs/src/protocols/bitswap/bitswap_handler.dart';
import 'package:dart_ipfs/src/protocols/dht/delegate_dht_handler.dart';
import 'package:dart_ipfs/src/protocols/dht/interface_dht_handler.dart';
import 'package:dart_ipfs/src/protocols/ipns/ipns_handler.dart';
import 'package:dart_ipfs/src/protocols/pubsub/pubsub_client.dart';
import 'package:dart_ipfs/src/transport/libp2p_router.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';

import 'web_block_store.dart';

/// A minimal IPFS node for web browsers.
///
/// This provides offline IPFS functionality without P2P networking:
/// - Add content and get CID
/// - Retrieve content by CID
/// - Local storage via IndexedDB
///
/// For full P2P functionality, run on native platforms (iOS, Android, desktop)
/// or use a WebRTC/WebSocket relay supported by the router.
class IPFSWebNode {
  /// Creates a new web IPFS node.
  IPFSWebNode({
    IPFSConfig? config,
    this.bootstrapPeers = const [],
    RouterInterface? router,
    BitswapHandler? bitswap,
  }) {
    _platform = getPlatform();
    _config = config ?? IPFSConfig(offline: true);

    // Initialize networking components
    _router = router ?? Libp2pRouter(_config, seed: _config.libp2pIdentitySeed);
    _injectedBitswap = bitswap;
    _blockStore = WebBlockStore(_platform);

    // Other components initialized in start()
  }

  late final IpfsPlatform _platform;
  late final IPFSConfig _config;
  late final RouterInterface _router;
  late final WebBlockStore _blockStore;
  late BitswapHandler _bitswap;
  BitswapHandler? _injectedBitswap;
  late PubSubClient _pubsub;
  late SecurityManagerWeb _securityManager;
  late IPNSHandler _ipns;

  /// List of bootstrap peers (WebSocket URLs) to connect to on startup.
  final List<String> bootstrapPeers;
  bool _started = false;

  /// The node's peer ID.
  String get peerID => _router.peerID; // Use router's ID

  /// Whether the node is running.
  bool get isRunning => _started;

  /// Access to Bitswap handler.
  BitswapHandler get bitswap => _bitswap;

  /// Access to PubSub client.
  PubSubClient get pubsub => _pubsub;

  /// Access to security manager.
  SecurityManagerWeb get securityManager => _securityManager;

  /// The node's listen multiaddresses, empty when not started.
  List<String> get addresses =>
      _started ? _router.listeningAddresses : const [];

  /// Connects to a peer given a full multiaddr (`/ip4/.../p2p/<peerId>`).
  Future<void> connectToPeer(String multiaddr) => _router.connect(multiaddr);

  /// Starts the web node.
  Future<void> start() async {
    if (_started) return;

    // Generate/Load ID via router (router usually generates one if generic)
    await _router.initialize();

    // Initialize components that depend on Router/PeerID
    _bitswap =
        _injectedBitswap ?? BitswapHandler(_config, _blockStore, _router);
    _pubsub = PubSubClient(_router, _router.peerID);

    // Security & IPNS
    _securityManager = SecurityManagerWeb(
      _config.security,
      MetricsCollector(_config),
    );

    final delegateUrl =
        _config.network.delegatedRoutingEndpoint ?? 'https://delegated-ipfs.io';
    IDHTHandler dht = DelegateDHTHandler(delegateUrl);

    _ipns = IPNSHandler(_config, _securityManager, dht, _pubsub);

    if (!_config.offline) {
      await _router.start();
      await _bitswap.start();
      await _pubsub.start();
    }
    await _ipns.start();

    // Connect to bootstrap peers
    if (!_config.offline) {
      for (final peer in bootstrapPeers) {
        try {
          await _router.connect(peer);
        } catch (e) {
          // Log error but continue
          // print('Failed to connect to bootstrap peer $peer: $e');
        }
      }
    }

    _started = true;
  }

  /// Stops the web node.
  Future<void> stop() async {
    if (!_started) return;

    await _ipns.stop();
    await _pubsub.stop();
    await _bitswap.stop();
    await _router.stop();

    _started = false;
  }

  /// Adds data and returns its CID.
  ///
  /// The bytes are chunked into a UnixFS DAG with the same layout
  /// `IPFSNode.addFile` produces on native platforms (Kubo `ipfs add`
  /// defaults: 256 KiB chunks, raw leaves off): a payload that fits in
  /// one chunk is stored as a single UnixFS file node whose CID is the
  /// root, larger payloads produce a DAG-PB root linking each chunk in
  /// order, and empty input yields the well-known empty-file block.
  /// Identical bytes therefore produce identical CIDs on web and native
  /// nodes.
  ///
  /// NOTE: CIDs differ from earlier releases of this method, which stored
  /// a single raw CIDv1 block.
  Future<CID> add(
    Uint8List data, {
    int cidVersion = 0,
    bool rawLeaves = false,
  }) => addStream(
    Stream<List<int>>.value(data),
    cidVersion: cidVersion,
    rawLeaves: rawLeaves,
  );

  /// Adds data from a stream and returns the root CID.
  ///
  /// This is memory efficient for large files as it chunks and processes
  /// the stream incrementally, building a UnixFS DAG identical to the one
  /// `IPFSNode.addFileStream` produces on native platforms.
  Future<CID> addStream(
    Stream<List<int>> stream, {
    int cidVersion = 0,
    bool rawLeaves = false,
  }) async {
    final builder = UnixFSBuilder(cidVersion: cidVersion, rawLeaves: rawLeaves);
    CID? rootCid;

    await for (final block in builder.build(stream)) {
      await _blockStore.putBlock(block);
      rootCid = block.cid;
    }

    if (rootCid == null) {
      throw StateError('UnixFS build produced no blocks');
    }

    return rootCid;
  }

  /// Adds a file to IPFS using chunked streaming.
  ///
  /// [file] must be a `Stream<List<int>>` of the file's bytes — on the
  /// web this is typically `file.stream()` from a `dart:html`/
  /// `package:web` `File` (or a `FileReader` result); on native,
  /// `file.openRead()`. The stream is consumed via [addStream], so the
  /// returned CID matches `IPFSNode.addFile` for identical bytes.
  ///
  /// Throws [UnsupportedError] for any other input type: this class
  /// cannot import `dart:html`, so browser `File` objects cannot be read
  /// here — obtain a byte stream first and pass that (or call [addStream]
  /// directly). Declared `dynamic` precisely so this library compiles
  /// without the web-only `File` type.
  Future<CID> addFile(dynamic file) {
    if (file is Stream<List<int>>) {
      return addStream(file);
    }
    throw UnsupportedError(
      'IPFSWebNode.addFile requires a Stream<List<int>> of file bytes: '
      'browser File objects cannot be read without dart:html, which this '
      'library does not import — pass file.stream() (web) or '
      'file.openRead() (native), or call addStream() directly',
    );
  }

  /// Gets data by CID string.
  Future<Uint8List?> get(String cidString) async {
    // 1. Try local storage via BlockStore
    final response = await _blockStore.getBlock(cidString);
    if (response.found && response.hasBlock()) {
      return _extractContent(response.block.toBlock());
    }

    // 2. Fallback to Bitswap
    if (_router.connectedPeers.isNotEmpty) {
      try {
        final block = await _bitswap.wantBlock(cidString);
        if (block != null) {
          // Block is automatically added to store by BitswapHandler when received
          return _extractContent(block);
        }
      } catch (e) {
        // Networking failed or timed out
      }
    }

    return null;
  }

  /// Extracts user-visible content from a stored [block].
  ///
  /// Raw blocks return their payload directly. DAG-PB blocks produced by
  /// [addStream] are UnixFS file nodes whose content is reassembled from the
  /// leaf blocks; non-file nodes (directories, non-UnixFS data) return their
  /// serialized node bytes.
  Future<Uint8List?> _extractContent(Block block) {
    return unixfsReadFile(block, _fetchBlock);
  }

  /// [UnixFSBlockFetcher] backed by the local [WebBlockStore].
  Future<Block?> _fetchBlock(CID cid) async {
    final response = await _blockStore.getBlock(cid.encode());
    if (!response.found) {
      return null;
    }
    return response.block.toBlock();
  }

  /// Gets data by CID object.
  Future<Uint8List?> cat(CID cid) async {
    return get(cid.encode());
  }

  /// Pins a CID (marks it as persistent).
  Future<void> pin(CID cid) async {
    await _platform.writeBytes('pins/${cid.encode()}', Uint8List(0));
  }

  /// Unpins a CID.
  Future<void> unpin(CID cid) async {
    await _platform.delete('pins/${cid.encode()}');
  }

  /// Lists all pinned CIDs.
  Future<List<String>> listPins() async {
    final entries = await _platform.listDirectory('pins');
    return [for (final path in entries) path.split('/').last];
  }

  /// Publishes an IPNS record.
  Future<void> publishIPNS(String cid, {required String keyName}) async {
    if (!_started) throw StateError('Node not started');
    await _ipns.publish(cid, keyName: keyName);
  }

  /// Resolves an IPNS name.
  Future<String?> resolveIPNS(String name) async {
    if (!_started) throw StateError('Node not started');
    return _ipns.resolve(name);
  }
}
