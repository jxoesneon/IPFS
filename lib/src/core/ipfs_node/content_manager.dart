// src/core/ipfs_node/content_manager.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart' as fixnum;

import '../../proto/generated/core/pin.pb.dart';
import '../../protocols/bitswap/bitswap_handler.dart';
import '../../transport/http_gateway_client.dart';
import '../../utils/logger.dart';
import '../cid.dart';
import '../config/bitswap_config.dart';
import '../data_structures/block.dart';
import '../data_structures/blockstore.dart';
import '../data_structures/directory.dart';
import '../data_structures/link.dart';
import '../data_structures/merkle_dag_node.dart';
import '../data_structures/pin.dart';
import '../errors/node_errors.dart';
import '../interfaces/i_lifecycle.dart';
import '../security/denylist_service.dart';
import '../storage/datastore.dart';
import '../unixfs/unixfs_builder.dart';
import '../unixfs/unixfs_reader.dart';
import 'datastore_handler.dart';
import 'ipfs_node.dart';

/// Manages content-related operations for the IPFS node.
class ContentManager implements ILifecycle {
  /// Creates a [ContentManager] with injected dependencies.
  ContentManager({
    required DatastoreHandler datastoreHandler,
    required StreamController<String> newContentController,
    BlockStore? blockStore,
    BitswapHandler? bitswapHandler,
    DenylistService? denylistService,
    BitswapConfig? bitswapConfig,
  }) : _datastoreHandler = datastoreHandler,
       _newContentController = newContentController,
       _blockStore = blockStore,
       _bitswapHandler = bitswapHandler,
       _denylistService = denylistService,
       _bitswapConfig = bitswapConfig ?? const BitswapConfig(),
       _logger = Logger('ContentManager');

  final DatastoreHandler _datastoreHandler;
  final BlockStore? _blockStore;
  final BitswapHandler? _bitswapHandler;
  final DenylistService? _denylistService;
  final BitswapConfig _bitswapConfig;
  final Logger _logger;
  final HttpGatewayClient _httpGatewayClient = HttpGatewayClient();
  final StreamController<String> _newContentController;

  @override
  Future<void> start() async {
    _logger.debug('Starting ContentManager...');
  }

  @override
  Future<void> stop() async {
    _logger.debug('Stopping ContentManager...');
  }

  /// Adds a file to IPFS as a UnixFS DAG and returns the root CID.
  ///
  /// The data is chunked into 256 KiB blocks matching Kubo's `ipfs add`
  /// defaults (`chunker=size-262144`). Files of a single chunk are stored as a
  /// single UnixFS file node; larger files produce a balanced DAG whose root
  /// links to each chunk in order. With [rawLeaves] the chunks are stored as
  /// raw blocks under a DAG-PB root (requires CIDv1 output, like Kubo).
  ///
  /// All generated blocks are stored; the returned CID is the DAG-PB (or
  /// single-node) UnixFS root — for CIDv0 output this is the `Qm…` form a
  /// Kubo `ipfs add` produces.
  ///
  /// NOTE: this changes the CIDs produced for identical bytes compared to
  /// earlier versions of this package, which stored a single raw block.
  Future<String> addFile(
    Uint8List data, {
    int cidVersion = 0,
    bool rawLeaves = false,
  }) async {
    try {
      return await _buildAndStore(
        Stream<List<int>>.value(data),
        cidVersion: cidVersion,
        rawLeaves: rawLeaves,
      );
    } catch (e, stackTrace) {
      _logger.error('Error adding file', e, stackTrace);
      rethrow;
    }
  }

  /// Adds file content from a [dataStream] as a chunked UnixFS DAG.
  Future<String> addFileStream(
    Stream<List<int>> dataStream, {
    int cidVersion = 0,
    bool rawLeaves = false,
  }) async {
    try {
      return await _buildAndStore(
        dataStream,
        cidVersion: cidVersion,
        rawLeaves: rawLeaves,
      );
    } catch (e, stackTrace) {
      _logger.error('Error adding file from stream', e, stackTrace);
      rethrow;
    }
  }

  /// Builds a UnixFS DAG from [stream], stores every block, and returns the
  /// root CID string.
  Future<String> _buildAndStore(
    Stream<List<int>> stream, {
    required int cidVersion,
    required bool rawLeaves,
  }) async {
    final builder = UnixFSBuilder(cidVersion: cidVersion, rawLeaves: rawLeaves);

    String? rootCid;
    await for (final block in builder.build(stream)) {
      await _datastoreHandler.putBlock(block);
      await _blockStore?.putBlock(block);
      rootCid = block.cid.encode();
    }

    if (rootCid == null) {
      throw StateError('UnixFS build produced no blocks');
    }

    _newContentController.add(rootCid);
    _logger.info('Added file with CID: $rootCid');
    return rootCid;
  }

  /// Adds a directory to IPFS and returns its root CID.
  Future<String> addDirectory(Map<String, dynamic> directoryContent) async {
    try {
      final directoryManager = IPFSDirectoryManager();

      for (final entry in directoryContent.entries) {
        final name = entry.key;
        final value = entry.value;

        if (value is Uint8List) {
          final cid = await addFile(value);
          directoryManager.addEntry(
            IPFSDirectoryEntry(
              name: name,
              hash: CID.decode(cid).toBytes(),
              size: fixnum.Int64(value.length),
              isDirectory: false,
            ),
          );
        } else if (value is Map<String, dynamic>) {
          final subDirCid = await addDirectory(value);
          directoryManager.addEntry(
            IPFSDirectoryEntry(
              name: name,
              hash: CID.decode(subDirCid).toBytes(),
              size: fixnum.Int64(0),
              isDirectory: true,
            ),
          );
        } else {
          _logger.warning(
            'Skipping unsupported directory entry type: ${value.runtimeType}',
          );
        }
      }

      final pbNode = directoryManager.build();
      final block = await Block.fromData(
        pbNode.writeToBuffer(),
        format: 'dag-pb',
      );

      await _datastoreHandler.putBlock(block);
      await _blockStore?.putBlock(block);
      _logger.info('Added directory with CID: ${block.cid}');
      return block.cid.toString();
    } catch (e, stackTrace) {
      _logger.error('Error adding directory', e, stackTrace);
      rethrow;
    }
  }

  /// Gets the content associated with [cid].
  Future<Uint8List?> get(
    String cid, {
    String path = '',
    GatewayMode gatewayMode = GatewayMode.internal,
    String customGatewayUrl = '',
  }) async {
    // Policy blocks must propagate; a swallowed StateError would be
    // indistinguishable from "content not found".
    final denylist = _denylistService;
    if (denylist != null && denylist.isBlockedByCidString(cid)) {
      final action = denylist.recordHit(cid, source: 'rpc');
      if (action == 'block') {
        throw StateError('Content blocked by operator policy');
      }
    }

    try {
      if (gatewayMode != GatewayMode.internal) {
        return await _getViaGateway(cid, gatewayMode, customGatewayUrl);
      }

      final block = await _fetchBlock(cid);
      if (block != null) {
        return await _extractBlockData(block, path);
      }

      return await _getViaHttpFallback(cid);
    } catch (e, stackTrace) {
      _logger.error('Error retrieving content for CID $cid', e, stackTrace);
      return null;
    }
  }

  Future<Uint8List?> _getViaGateway(
    String cid,
    GatewayMode mode,
    String customUrl,
  ) async {
    String url;
    switch (mode) {
      case GatewayMode.public:
        url = 'https://ipfs.io/ipfs';
        break;
      case GatewayMode.local:
        url = 'http://127.0.0.1:8080/ipfs';
        break;
      case GatewayMode.custom:
        url = customUrl;
        break;
      default:
        url = 'https://ipfs.io/ipfs';
    }
    _logger.debug('Retrieving via Gateway ($url): $cid');
    final bytes = await _httpGatewayClient.get(cid, baseUrl: url);
    if (bytes == null) return null;

    // Raw-codec CIDs address the returned bytes directly and can be
    // hash-verified. Other codecs return resolved UnixFS content whose
    // bytes do not hash to the root CID — the configured gateway is
    // trusted for those, matching Kubo's gateway trust model.
    if (CID.decode(cid).codec == 'raw' &&
        !await Block(cid: CID.decode(cid), data: bytes).validate()) {
      _logger.warning('Gateway $url returned invalid block for $cid');
      return null;
    }
    return bytes;
  }

  /// Opt-in HTTP gateway fallback.
  ///
  /// Disabled unless [BitswapConfig.enableHttpFallback] is set. Fetches
  /// raw blocks only from the configured gateways, honoring
  /// [BitswapConfig.allowPrivateGateways], and hash-verifies every
  /// fetched block against the requested CID before it is cached or
  /// returned — a malicious gateway cannot inject arbitrary content.
  Future<Uint8List?> _getViaHttpFallback(String cid) async {
    if (!_bitswapConfig.enableHttpFallback) return null;

    _logger.debug(
      'P2P retrieval failed, attempting HTTP gateway fallback for $cid',
    );
    for (final gateway in _bitswapConfig.httpFallbackGateways) {
      final uri = Uri.tryParse(gateway);
      if (uri == null ||
          (uri.scheme != 'http' && uri.scheme != 'https') ||
          (!_bitswapConfig.allowPrivateGateways &&
              HttpGatewayClient.isPrivateOrLoopbackHost(uri.host))) {
        _logger.warning('Skipping invalid HTTP gateway URL: $gateway');
        continue;
      }

      final bytes = await _httpGatewayClient.fetchRawBlock(
        gateway,
        cid,
        timeout: _bitswapConfig.httpTimeout,
        maxBlockSize: _bitswapConfig.maxHttpBlockSize,
      );
      if (bytes == null) continue;

      final block = Block(cid: CID.decode(cid), data: bytes);
      if (!await block.validate()) {
        _logger.warning(
          'HTTP fallback returned invalid block for $cid from $gateway',
        );
        continue;
      }
      await _datastoreHandler.putBlock(block);
      return block.data;
    }
    return null;
  }

  /// Fetches a block by CID string from the local datastore, the shared
  /// block store, or the Bitswap network, in that order.
  ///
  /// Blocks retrieved over Bitswap are cached into the datastore so repeated
  /// traversal of a DAG does not re-fetch them.
  Future<Block?> _fetchBlock(String cid) async {
    var block = await _datastoreHandler.getBlock(cid);
    if (block != null) {
      return block;
    }

    final blockResult = await _blockStore?.getBlock(cid);
    if (blockResult != null && blockResult.found) {
      return blockResult.block.toBlock();
    }

    final bitswap = _bitswapHandler;
    if (bitswap != null) {
      _logger.debug('Attempting to retrieve block $cid via Bitswap');
      final networkBlock = await bitswap.wantBlock(cid);
      if (networkBlock != null) {
        await _datastoreHandler.putBlock(networkBlock);
        return networkBlock;
      }
    }

    return null;
  }

  /// Extracts the user-visible payload from [block].
  ///
  /// With an empty [path] this reassembles UnixFS file nodes by traversing
  /// `pbNode.links` in order (Kubo `cat` semantics); raw blocks return their
  /// payload directly and non-file nodes return their serialized bytes. With
  /// a non-empty [path] the path is resolved through named directory links.
  Future<Uint8List?> _extractBlockData(Block block, String path) async {
    if (path.isEmpty) {
      return unixfsReadFile(block, (cid) => _fetchBlock(cid.encode()));
    } else {
      final node = MerkleDAGNode.fromBytes(block.data);
      if (node.isDirectory) {
        return await _resolvePathInDirectory(node, path);
      }
    }
    return null;
  }

  Future<Uint8List?> _resolvePathInDirectory(
    MerkleDAGNode dirNode,
    String path,
  ) async {
    final pathParts = path.split('/').where((part) => part.isNotEmpty).toList();
    if (pathParts.isEmpty) return null;

    for (final link in dirNode.links) {
      if (link.name == pathParts[0]) {
        final childBlock = await _fetchBlock(link.cid.encode());
        if (childBlock == null) return null;

        if (pathParts.length == 1) {
          // Reassemble chunked UnixFS file targets like `cat` does.
          return unixfsReadFile(childBlock, (cid) => _fetchBlock(cid.encode()));
        } else {
          final childNode = MerkleDAGNode.fromBytes(childBlock.data);
          return await _resolvePathInDirectory(
            childNode,
            pathParts.sublist(1).join('/'),
          );
        }
      }
    }
    return null;
  }

  /// Lists the links within a directory identified by [cid].
  Future<List<Link>> ls(String cid) async {
    try {
      Block? block = await _datastoreHandler.getBlock(cid);

      if (block == null && _bitswapHandler != null) {
        block = await _bitswapHandler.wantBlock(cid);
      }

      if (block == null) {
        final blockResult = await _blockStore?.getBlock(cid);
        if (blockResult != null && blockResult.found) {
          block = blockResult.block.toBlock();
        }
      }

      if (block == null) {
        _logger.warning('Directory not found: $cid');
        return [];
      }

      try {
        final node = MerkleDAGNode.fromBytes(block.data);
        if (!node.isDirectory) {
          _logger.warning('CID does not point to a directory: $cid');
          return [];
        }

        return node.links;
      } catch (e) {
        _logger.warning('Failed to parse MerkleDAGNode for CID $cid: $e');
        return [];
      }
    } catch (e, stackTrace) {
      _logger.error('Error listing directory $cid', e, stackTrace);
      rethrow;
    }
  }

  /// Recursively pins a [cid] to prevent garbage collection.
  Future<void> pin(String cid) async {
    try {
      if (_blockStore == null) {
        throw ComponentError('BlockStore', 'Required for pinning');
      }

      final pin = Pin(
        cid: CID.decode(cid),
        type: PinTypeProto.PIN_TYPE_RECURSIVE,
        blockStore: _blockStore,
      );

      final success = await pin.pin();
      if (!success) {
        throw Exception('Failed to pin CID: $cid');
      }

      await _datastoreHandler.persistPinnedCIDs({cid});
      _logger.info('Pinned CID: $cid');
    } catch (e, stackTrace) {
      _logger.error('Error pinning CID $cid', e, stackTrace);
      rethrow;
    }
  }

  /// Unpins a [cid] from the node.
  Future<bool> unpin(String cid) async {
    try {
      if (_blockStore == null) {
        throw ComponentError('BlockStore', 'Required for unpinning');
      }

      final pin = Pin(
        cid: CID.decode(cid),
        type: PinTypeProto.PIN_TYPE_RECURSIVE,
        blockStore: _blockStore,
      );

      final success = await pin.unpin();
      if (success) {
        final pinKey = Key('/pins/$cid');
        await _datastoreHandler.datastore.delete(pinKey);
      }
      _logger.info('Unpinned CID: $cid (Success: $success)');
      return success;
    } catch (e, stackTrace) {
      _logger.error('Error unpinning CID $cid', e, stackTrace);
      return false;
    }
  }

  /// Imports blocks from a [carFile] into the local datastore.
  Future<void> importCAR(Uint8List carFile) async {
    try {
      await _datastoreHandler.importCAR(carFile);
      _logger.info('Imported CAR file successfully');
    } catch (e, stackTrace) {
      _logger.error('Error importing CAR file', e, stackTrace);
      rethrow;
    }
  }

  /// Exports the DAG rooted at [cid] as a [Uint8List] in CAR format.
  Future<Uint8List> exportCAR(String cid) async {
    try {
      final carData = await _datastoreHandler.exportCAR(cid);
      _logger.info('Exported CAR for CID: $cid');
      return carData;
    } catch (e, stackTrace) {
      _logger.error('Error exporting CAR file for CID $cid', e, stackTrace);
      rethrow;
    }
  }
}
