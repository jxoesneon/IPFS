// src/core/ipfs_node/content_manager.dart
import 'dart:async';
import 'dart:typed_data';

import '../../proto/generated/core/blockstore.pb.dart';
import '../../proto/generated/core/pin.pb.dart';
import '../../protocols/bitswap/bitswap_handler.dart';
import '../../transport/http_gateway_client.dart';
import '../../utils/logger.dart';
import '../cid.dart';
import '../config/bitswap_config.dart';
import '../data_structures/block.dart';
import '../data_structures/blockstore.dart';
import '../data_structures/link.dart';
import '../data_structures/merkle_dag_node.dart';
import '../data_structures/pin.dart';
import '../errors/node_errors.dart';
import '../interfaces/i_block_store.dart';
import '../interfaces/i_lifecycle.dart';
import '../security/denylist_service.dart';
import '../storage/datastore.dart';
import '../unixfs/unixfs_builder.dart';
import '../unixfs/unixfs_directory.dart';
import '../unixfs/unixfs_errors.dart';
import '../unixfs/unixfs_hamt.dart';
import '../unixfs/unixfs_node.dart';
import '../unixfs/unixfs_reader.dart';
import '../unixfs/unixfs_resolver.dart';
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

    // UnixFSBuilder.build unconditionally yields a root block (even for an
    // empty stream), so the loop always assigns rootCid before it completes.
    late String rootCid;
    await for (final block in builder.build(stream)) {
      await _datastoreHandler.putBlock(block);
      await _blockStore?.putBlock(block);
      rootCid = block.cid.encode();
    }

    _newContentController.add(rootCid);
    _logger.info('Added file with CID: $rootCid');
    return rootCid;
  }

  /// Adds a directory to IPFS and returns its root CID.
  ///
  /// Directory nodes are built with Kubo-compatible semantics: entries are
  /// sorted by UTF-8 name order and each link's `Tsize` is the cumulative
  /// serialized size of the linked subtree, so the resulting root CID matches
  /// `ipfs add -r` for the same contents.
  ///
  /// When [shardThreshold] is greater than zero and a directory's entry count
  /// exceeds it, the directory is written as a HAMT-sharded node like
  /// Kubo's automatic sharding.
  Future<String> addDirectory(
    Map<String, dynamic> directoryContent, {
    int shardThreshold = 0,
  }) async {
    try {
      final store = _ContentBlockStore(this);
      final entries = <UnixFSDirectoryEntry>[];

      for (final entry in directoryContent.entries) {
        final name = entry.key;
        final value = entry.value;

        if (value is Uint8List) {
          final cid = await addFile(value);
          // tsize is recomputed by createDirectory from the stored subtree.
          entries.add(
            UnixFSDirectoryEntry(name: name, cid: CID.decode(cid), tsize: 0),
          );
        } else if (value is Map<String, dynamic>) {
          final subDirCid = await addDirectory(
            value,
            shardThreshold: shardThreshold,
          );
          entries.add(
            UnixFSDirectoryEntry(
              name: name,
              cid: CID.decode(subDirCid),
              tsize: 0,
            ),
          );
        } else {
          _logger.warning(
            'Skipping unsupported directory entry type: ${value.runtimeType}',
          );
        }
      }

      final node = await createDirectory(
        store,
        entries,
        shardThreshold: shardThreshold,
      );
      _logger.info('Added directory with CID: ${node.cid}');
      return node.cid.toString();
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
    // Policy blocks must propagate; a swallowed error would be
    // indistinguishable from "content not found".
    final denylist = _denylistService;
    if (denylist != null && denylist.isBlockedByCidString(cid)) {
      final action = denylist.recordHit(cid, source: 'rpc');
      if (action == 'block') {
        throw DenylistBlockedException(cid);
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
    } on DenylistBlockedException {
      // Policy blocks thrown by the denylist gate in [_fetchBlock] must
      // propagate — same contract as the root-CID check above.
      rethrow;
    } on StateError catch (e) {
      _logger.error('Error retrieving content for CID $cid', e);
      return null;
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
        url = _bitswapConfig.publicGatewayUrl;
        break;
      case GatewayMode.local:
        url = 'http://127.0.0.1:8080/ipfs';
        break;
      case GatewayMode.custom:
        url = customUrl;
        break;
      default:
        // Unreachable via get(): GatewayMode.internal is routed to the
        // blockstore before this helper is called. Defensive fallback.
        url = _bitswapConfig.publicGatewayUrl; // coverage:ignore-line
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
  ///
  /// Every fetch is denylist-gated so traversal (path resolution, file
  /// reassembly, TAR export, pinning) cannot serve a blocked child block —
  /// matching the gateway's per-block egress gate in `_getBlockByCid`.
  Future<Block?> _fetchBlock(String cid) async {
    final denylist = _denylistService;
    if (denylist != null && denylist.isBlockedByCidString(cid)) {
      final action = denylist.recordHit(cid, source: 'rpc');
      if (action == 'block') {
        throw DenylistBlockedException(cid);
      }
    }

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
    }

    // Resolve the path through the shared UnixFS resolver — it handles
    // HAMT-sharded directories, symlinks, cycles, and traversal budgets,
    // matching Kubo's resolution semantics for `cat <cid>/<path>`.
    try {
      final resolver = UnixFSPathResolver(store: _ContentBlockStore(this));
      final resolved = await resolver.resolveNode(block.cid, path);
      final resolvedBlock = Block(
        cid: resolved.cid,
        data: resolved.data,
        format: resolved.cid.codec ?? 'dag-pb',
      );
      return unixfsReadFile(resolvedBlock, (cid) => _fetchBlock(cid.encode()));
    } on PathResolutionError {
      return null;
    } on DAGCycleError {
      return null;
    } on SymlinkCycleError {
      return null;
    }
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

        // A HAMT-sharded root stores links under hash-prefixed names;
        // enumerate the logical entries like Kubo `ls` does.
        final unixfsNode = UnixFSNode.fromBlock(block);
        if (unixfsNode.isHAMTShard) {
          final entries = await hamtLeafEntries(
            _ContentBlockStore(this),
            unixfsNode,
          );
          return entries
              .map((e) => Link(name: e.name, cid: e.cid, size: e.tsize))
              .toList();
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

/// [IBlockStore] facade over [ContentManager]'s stores, used by the UnixFS
/// directory builder to compute cumulative Tsizes and persist nodes. Reads go
/// through the shared fetch path (datastore, block store, Bitswap); writes go
/// to the datastore and shared block store like every other stored block.
class _ContentBlockStore implements IBlockStore {
  _ContentBlockStore(this._content);

  final ContentManager _content;

  @override
  Future<GetBlockResponse> getBlock(String cid) async {
    final block = await _content._fetchBlock(cid);
    if (block == null) {
      return GetBlockResponse(found: false);
    }
    return GetBlockResponse(block: block.toProto(), found: true);
  }

  @override
  Future<AddBlockResponse> putBlock(Block block) async {
    await _content._datastoreHandler.putBlock(block);
    await _content._blockStore?.putBlock(block);
    return AddBlockResponse(success: true);
  }

  // coverage:ignore-start
  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  // coverage:ignore-end
}
