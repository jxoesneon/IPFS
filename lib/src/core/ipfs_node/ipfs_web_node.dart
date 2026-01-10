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
import 'package:dart_ipfs/src/platform/platform.dart';
import 'package:dart_ipfs/src/protocols/bitswap/bitswap_handler.dart';
import 'package:dart_ipfs/src/protocols/dht/delegate_dht_handler.dart';
import 'package:dart_ipfs/src/protocols/dht/interface_dht_handler.dart';
import 'package:dart_ipfs/src/protocols/dht/mock_dht_handler.dart'; // Web doesn't support DHT yet, use mock or stub
import 'package:dart_ipfs/src/protocols/ipns/ipns_handler.dart';
import 'package:dart_ipfs/src/protocols/pubsub/pubsub_client.dart';
import 'package:dart_ipfs/src/transport/p2plib_router.dart';

import 'web_block_store.dart';

/// A minimal IPFS node for web browsers.
///
/// This provides offline IPFS functionality without P2P networking:
/// - Add content and get CID
/// - Retrieve content by CID
/// - Local storage via IndexedDB
///
/// For full P2P functionality, run on native platforms (iOS, Android, desktop).
class IPFSWebNode {
  /// Creates a new web IPFS node.
  IPFSWebNode({IPFSConfig? config, this.bootstrapPeers = const []}) {
    _platform = getPlatform();
    _config = config ?? IPFSConfig();

    // Initialize networking components
    _router = P2plibRouter(_config);
    _blockStore = WebBlockStore(_platform);

    // Other components initialized in start()
  }

  late final IpfsPlatform _platform;
  late final IPFSConfig _config;
  late final P2plibRouter _router;
  late final WebBlockStore _blockStore;
  late BitswapHandler _bitswap;
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

  /// Starts the web node.
  Future<void> start() async {
    if (_started) return;

    // Generate/Load ID via router (router usually generates one if generic)
    await _router.initialize();

    // Initialize components that depend on Router/PeerID
    _bitswap = BitswapHandler(_config, _blockStore, _router);
    _pubsub = PubSubClient(_router, _router.peerID);

    // Security & IPNS
    _securityManager = SecurityManagerWeb(
      _config.security,
      MetricsCollector(_config),
    );

    final delegateUrl = _config.network.delegatedRoutingEndpoint;
    final IDHTHandler dht;

    if (delegateUrl != null && delegateUrl.isNotEmpty) {
      dht = DelegateDHTHandler(delegateUrl);
    } else {
      dht = MockDHTHandler();
    }

    _ipns = IPNSHandler(_config, _securityManager, dht, _pubsub);

    await _router.start();
    await _bitswap.start();
    await _pubsub.start();

    // Connect to bootstrap peers
    for (final peer in bootstrapPeers) {
      try {
        await _router.connect(peer);
      } catch (e) {
        // Log error but continue
        // print('Failed to connect to bootstrap peer $peer: $e');
      }
    }

    _started = true;
  }

  /// Stops the web node.
  Future<void> stop() async {
    if (!_started) return;

    await _pubsub.stop();
    await _bitswap.stop();
    await _router.stop();

    _started = false;
  }

  /// Adds data and returns its CID.
  Future<CID> add(Uint8List data) async {
    // Create a CID using the fromContent factory
    final cid = await CID.fromContent(
      data,
      codec: 'raw',
      hashType: 'sha2-256',
      version: 1,
    );

    // Store via BlockStore (which handles platform storage)
    // We create a Block object
    final block = Block(cid: cid, data: data);
    await _blockStore.putBlock(block);

    // Also cache in memory for speed (optional, BlockStore relies on platform)
    // _store is redundant if WebBlockStore uses platform directly.
    // We remove _store usage to rely on WebBlockStore + Platform.

    return cid;
  }

  /// Adds data from a stream and returns the root CID.
  ///
  /// This is memory efficient for large files as it chunks and processes
  /// the stream incrementally, building a UnixFS DAG.
  Future<CID> addStream(Stream<List<int>> stream) async {
    final builder = UnixFSBuilder();
    CID? rootCid;

    await for (final block in builder.build(stream)) {
      await _blockStore.putBlock(block);
      rootCid = block.cid;
    }

    if (rootCid == null) {
      throw StateError('Stream was empty');
    }

    return rootCid;
  }

  /// Adds a file to IPFS using chunked streaming.
  ///
  /// [file] should be a `dart:html` File object or similar (dynamic to avoid import issues).
  /// This method is designed for web usage.
  Future<CID> addFile(dynamic file) async {
    if (_platform.isWeb) {
      if (file is Stream<List<int>>) {
        return addStream(file);
      }
      throw UnimplementedError(
        'addFile expecting Stream<List<int>>. Use addStream(file.stream()) instead.',
      );
    }
    throw UnimplementedError('addFile only supported on Web');
  }

  /// Gets data by CID string.
  Future<Uint8List?> get(String cidString) async {
    // 1. Try local storage via BlockStore
    final response = await _blockStore.getBlock(cidString);
    if (response.found && response.hasBlock()) {
      return Block.fromProto(response.block).data;
    }

    // 2. Fallback to Bitswap
    if (_router.connectedPeers.isNotEmpty) {
      try {
        final block = await _bitswap.wantBlock(cidString);
        if (block != null) {
          // Block is automatically added to store by BitswapHandler when received
          return block.data;
        }
      } catch (e) {
        // Networking failed or timed out
      }
    }

    return null;
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
    return _platform.listDirectory('pins');
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
