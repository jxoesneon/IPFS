import 'dart:async';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/interfaces/i_block_store.dart';
import 'package:dart_ipfs/src/core/interfaces/i_lifecycle.dart';
import 'package:dart_ipfs/src/core/security/denylist_service.dart';
import 'package:dart_ipfs/src/protocols/bitswap/ledger.dart';
import 'package:dart_ipfs/src/protocols/bitswap/message.dart' as message;
import 'package:dart_ipfs/src/protocols/bitswap/wantlist.dart';
import 'package:dart_ipfs/src/transport/http_gateway_client.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:dart_ipfs/src/utils/generic_lru_cache.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:meta/meta.dart';

/// Handles Bitswap protocol operations for an IPFS node following the Bitswap 1.2.0 specification
class BitswapHandler implements ILifecycle {
  /// Creates a new [BitswapHandler] with the given [config], [_blockStore], and [_router].
  ///
  /// An optional [httpGatewayClient] can be injected for testing or to share a
  /// single HTTP client across the node. If the config enables HTTP fallback
  /// and no client is provided, a new [HttpGatewayClient] is created.
  BitswapHandler(
    IPFSConfig config,
    this._blockStore,
    this._router, {
    HttpGatewayClient? httpGatewayClient,
    DenylistService? denylistService,
  })  : _maxConcurrentRequests = config.maxConcurrentBitswapRequests,
        _bitswapConfig = config.bitswap,
        _httpGatewayClient = config.bitswap.enableHttpFallback
            ? (httpGatewayClient ?? HttpGatewayClient())
            : null,
        _internalHttpClient =
            config.bitswap.enableHttpFallback && httpGatewayClient == null,
        _denylistService = denylistService,
        _logger = Logger(
          'BitswapHandler',
          debug: config.debug,
          verbose: config.verboseLogging,
        ) {
    _logger.info('Initializing BitswapHandler');
    _setupHandlers();
  }
  final IBlockStore _blockStore;
  final RouterInterface _router;
  final BitswapConfig _bitswapConfig;
  final HttpGatewayClient? _httpGatewayClient;
  final bool _internalHttpClient;
  final DenylistService? _denylistService;
  final Wantlist _wantlist = Wantlist();
  final LedgerManager _ledgerManager = LedgerManager();
  final Map<String, Completer<Block>> _pendingBlocks = {};
  final Map<String, Set<String>> _providersForBlock = {};
  final List<String> _requestQueue = [];
  int _activeRequests = 0;
  final int _maxConcurrentRequests;
  static const String _protocolId = '/ipfs/bitswap/1.2.0';
  bool _running = false;
  final Logger _logger;
  int _bandwidthSent = 0;
  int _bandwidthReceived = 0;
  final Set<String> _sessions = {};
  final Set<String> _connectedPeers = {};
  int _blocksReceived = 0;
  final int _blocksSent = 0;

  /// Cache for block presence checks to avoid repeated blockstore lookups.
  /// Entries expire after 30 seconds to handle block additions/removals.
  final TimedLRUCache<String, bool> _blockPresenceCache = TimedLRUCache(
    capacity: 1000,
    ttl: const Duration(seconds: 30),
  );

  /// Starts the Bitswap handler
  @override
  Future<void> start() async {
    if (_running) {
      _logger.warning('BitswapHandler already running');
      return;
    }

    try {
      _running = true;
      _logger.debug('Starting BitswapHandler...');

      await _router.initialize();
      _logger.verbose('Router initialized');

      await _router.start();
      _logger.verbose('Router started');

      _router.registerProtocolHandler(_protocolId, _handlePacket);
      _logger.debug('Added message handler for protocol: $_protocolId');

      _router.registerProtocol(_protocolId);
      _logger.info('BitswapHandler started successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to start BitswapHandler', e, stackTrace);
      _running = false;
      rethrow;
    }
  }

  /// Stops the Bitswap handler
  @override
  Future<void> stop() async {
    if (!_running) return;
    _running = false;

    _logger.debug('Stopping BitswapHandler...');

    // Clean up pending requests
    for (final completer in _pendingBlocks.values) {
      completer.completeError('BitswapHandler stopped');
    }
    _pendingBlocks.clear();
    _sessions.clear();
    _connectedPeers.clear();

    try {
      await _router.stop();
      _logger.info('BitswapHandler stopped successfully');
    } catch (e, st) {
      _logger.error('Error stopping BitswapHandler router', e, st);
    }

    if (_internalHttpClient) {
      _httpGatewayClient?.close();
      _logger.debug('HTTP gateway client closed');
    }
  }

  /// Handles incoming Bitswap messages
  Future<void> _handleMessage(message.Message message) async {
    if (!_running) return;

    final fromPeer = message.from;

    if (message.hasWantlist()) {
      final messageWantlist = message.getWantlist();
      final wantlist = Wantlist();

      for (final entry in messageWantlist.entries.values) {
        wantlist.add(
          entry.cid,
          priority: entry.priority,
          wantType: entry.wantType,
          sendDontHave: entry.sendDontHave,
        );
      }

      // We need 'fromPeer' to reply. If it's missing, we can't reply.
      if (fromPeer != null) {
        await _handleWantlist(wantlist, fromPeer);
      }
    }

    if (message.hasBlocks()) {
      await _handleBlocks(message.getBlocks());

      if (fromPeer != null) {
        final ledger = _ledgerManager.getLedger(fromPeer);
        // Update received bytes in ledger
        ledger.addReceivedBytes(
          message
              .getBlocks()
              .map((b) => b.data.length)
              .fold<int>(0, (sum, size) => sum + size),
        );
        _updateBandwidthStats();
      }
    }

    // Handle Bitswap 1.2+ Block Presences (HAVE/DONT_HAVE)
    if (message.hasBlockPresences()) {
      _handleBlockPresences(message.getBlockPresences(), fromPeer);
    }
  }

  /// Handles incoming wantlist entries according to Bitswap spec
  Future<void> _handleWantlist(Wantlist wantlist, String fromPeer) async {
    // SEC-ZDAY-001: Limit entries to prevent DoS (CPU exhaustion on sort/iterate)
    if (wantlist.entries.length > 5000) {
      _logger.warning(
        'Rejected excessive wantlist from $fromPeer (${wantlist.entries.length} entries)',
      );
      return;
    }

    // Sort entries by priority before processing
    final sortedEntries = wantlist.entries.entries.toList()
      ..sort(
        (a, b) => b.value.priority.compareTo(a.value.priority),
      ); // Higher priority first

    final outgoingMessage = message.Message();
    outgoingMessage.from = _router.peerID.toString();
    bool hasContent = false;

    for (final entry in sortedEntries) {
      final cidStr = entry.key;
      final wantEntry = entry.value;

      // Add to our local wantlist with the received priority
      _wantlist.add(cidStr, priority: wantEntry.priority);

      // Bitswap 1.2: Check if peer wants just 'HAVE' or full block
      if (wantEntry.wantType == message.WantType.have) {
        // Use cache for presence checks (HAVE mode)
        final found = await _blockPresenceCache.getOrCompute(cidStr, () async {
          final response = await _blockStore.getBlock(cidStr);
          return response.found;
        });

        if (found) {
          outgoingMessage.addBlockPresence(
            cidStr,
            message.BlockPresenceType.have,
          );
          hasContent = true;
        } else if (wantEntry.sendDontHave) {
          outgoingMessage.addBlockPresence(
            cidStr,
            message.BlockPresenceType.dontHave,
          );
          hasContent = true;
        }
      } else {
        // Standard 'Block' request - need full response for block data
        final response = await _blockStore.getBlock(cidStr);
        _blockPresenceCache.put(cidStr, response.found); // Update cache

        if (response.found) {
          outgoingMessage.addBlock(Block.fromProto(response.block));
          hasContent = true;
        } else if (wantEntry.sendDontHave) {
          outgoingMessage.addBlockPresence(
            cidStr,
            message.BlockPresenceType.dontHave,
          );
          hasContent = true;
        }
      }
    }

    if (hasContent) {
      try {
        final messageBytes = outgoingMessage.toBytes();
        await _router.sendMessage(
          fromPeer,
          messageBytes,
          protocolId: _protocolId,
        );

        // Update ledger stats
        final ledger = _ledgerManager.getLedger(fromPeer);
        for (final block in outgoingMessage.getBlocks()) {
          ledger.addSentBytes(block.data.length);
        }
        _updateBandwidthStats();
      } catch (error, st) {
        _logger.error('Error sending response to peer $fromPeer', error, st);
      }
    }
  }

  /// Handles incoming block presences (HAVE/DONT_HAVE)
  void _handleBlockPresences(
    List<message.BlockPresence> presences,
    String? fromPeer,
  ) {
    if (fromPeer == null) return;

    for (final presence in presences) {
      final cid = presence.cid;
      if (presence.type == message.BlockPresenceType.have) {
        _logger.verbose('Peer $fromPeer HAVE $cid');
        // Track this peer as a provider for the block
        _providersForBlock.putIfAbsent(cid, () => {}).add(fromPeer);
      } else {
        _logger.verbose('Peer $fromPeer DONT_HAVE $cid');
        // Remove this peer from providers for the block
        _providersForBlock[cid]?.remove(fromPeer);
      }
    }
  }

  /// Exposes internal block handling for testing.
  @visibleForTesting
  Future<void> handleBlocks(List<Block> blocks) => _handleBlocks(blocks);

  /// Handles incoming blocks according to Bitswap spec
  Future<void> _handleBlocks(List<Block> blocks) async {
    for (final block in blocks) {
      // Validate block hash before storing (SEC-002 security fix)
      final isValid = await block.validate();
      if (!isValid) {
        _logger.warning(
          'Rejected invalid block: ${block.cid.encode()} - hash mismatch',
        );
        continue;
      }

      await _blockStore.putBlock(block);
      _blocksReceived++;

      final cidStr = block.cid.encode();
      // Complete pending request if exists
      final completer = _pendingBlocks.remove(cidStr);
      completer?.complete(block);

      // Remove from wantlist
      if (_wantlist.contains(cidStr)) {
        _wantlist.remove(cidStr);
      }
    }
  }

  /// Requests blocks from the network with proper Bitswap session handling
  Future<List<Block>> want(
    List<String> cids, {
    int priority = 1,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (!_running) {
      throw StateError('BitswapHandler is not running');
    }

    if (_router.connectedPeers.isEmpty) {
      throw StateError('No connected peers available for Bitswap request');
    }

    final completers = <String, Completer<Block>>{};
    for (final cid in cids) {
      if (!_pendingBlocks.containsKey(cid)) {
        final completer = Completer<Block>();
        _pendingBlocks[cid] = completer;
        completers[cid] = completer;
        _wantlist.add(cid, priority: priority);
        _requestQueue.add(cid);
      } else {
        completers[cid] = _pendingBlocks[cid]!;
      }
    }

    unawaited(_processQueue());

    try {
      final futures = completers.values
          .map(
            (completer) => completer.future.timeout(
              timeout,
              onTimeout: () =>
                  throw TimeoutException('Block request timed out'),
            ),
          )
          .toList();

      final blocks = await Future.wait(futures);
      return blocks;
    } catch (e) {
      // Clean up pending requests that failed
      for (final cid in completers.keys) {
        if (_pendingBlocks[cid]?.isCompleted == false) {
          _pendingBlocks.remove(cid);
          _wantlist.remove(cid);
        }
      }
      rethrow;
    }
  }

  Future<void> _processQueue() async {
    if (_activeRequests >= _maxConcurrentRequests || _requestQueue.isEmpty) {
      return;
    }

    while (
        _activeRequests < _maxConcurrentRequests && _requestQueue.isNotEmpty) {
      final cid = _requestQueue.removeAt(0);
      _activeRequests++;

      unawaited(
        _sendWantRequest(cid).then((_) {
          // We don't decrement _activeRequests here because Bitswap is async.
          // The request is 'active' until the block is received or times out.
          // For simplicity in this implementation, we'll just throttle the initial sending.
        }).catchError((Object e) {
          _logger.error('Failed to send want request for $cid: $Object e');
        }).whenComplete(() {
          _activeRequests--;
          unawaited(_processQueue());
        }),
      );
    }
  }

  Future<void> _sendWantRequest(String cid) async {
    final msg = message.Message();
    msg.addWantlistEntry(
      cid,
      priority: 1, // Default priority for queue processing
      wantType: message.WantType.block,
      sendDontHave: true,
    );
    await _broadcastWantRequest(msg);
  }

  /// Broadcasts want request to connected peers
  Future<void> _broadcastWantRequest(message.Message message) async {
    final connectedPeers = _router.connectedPeers;

    if (connectedPeers.isEmpty) {
      _logger.warning('No connected peers to broadcast want request to');
      throw StateError('No connected peers available for Bitswap request');
    }

    final messageBytes = message.toBytes();
    final futures = <Future<void>>[];

    // Determine target peers
    Set<String> targets = {};

    // For Bitswap 1.2 smart routing: check if we know providers for any requested CIDs
    for (final entry in message.getWantlist().entries.values) {
      final providers = _providersForBlock[entry.cid];
      if (providers != null && providers.isNotEmpty) {
        // Intersect known providers with currently connected peers
        for (final provider in providers) {
          if (connectedPeers.contains(provider)) {
            targets.add(provider);
          }
        }
      }
    }

    // If no specific providers found or connected, broadcast to all
    bool isBroadcast = false;
    if (targets.isEmpty) {
      targets = connectedPeers;
      isBroadcast = true;
    }

    _logger.debug(
      isBroadcast
          ? 'Broadcasting want request to ${targets.length} peers'
          : 'Sending targeted want request to ${targets.length} providers',
    );

    for (final peerId in targets) {
      futures.add(
        (() async {
          try {
            await _router.sendMessage(
              peerId,
              messageBytes,
              protocolId: _protocolId,
            );
            _logger.verbose('Want request sent to peer: $peerId');
          } catch (error, st) {
            _logger.error(
              'Error sending want request to peer $peerId',
              error,
              st,
            );
          }
        })(),
      );
    }

    await Future.wait(futures);
  }

  Future<void> _handlePacket(NetworkPacket packet) async {
    try {
      final msg = await message.Message.fromBytes(packet.datagram);
      // Annotate message with sender
      msg.from = packet.srcPeerId;

      await _handleMessage(msg);
    } catch (e, st) {
      _logger.error(
        'Failed to handle Bitswap packet from ${packet.srcPeerId}: $e',
      );
      _logger.error('$st');
    }
  }

  /// Handles an incoming want request for a CID.
  Future<void> handleWantRequest(String cidStr) async {
    try {
      final customMessage = message.Message();
      customMessage.addWantlistEntry(
        cidStr,
        priority: 1,
        wantType: message.WantType.block,
        sendDontHave: true,
      );

      await _broadcastWantRequest(customMessage);
    } catch (e, st) {
      _logger.error('Error handling want request for $cidStr', e, st);
      rethrow;
    }
  }

  void _setupHandlers() {
    _logger.debug('Setting up Bitswap protocol handlers');
    _router.registerProtocol(_protocolId);
    _logger.debug('Registered protocol: $_protocolId');

    _router.registerProtocolHandler(_protocolId, _handlePacket);
    _logger.debug('Added message handler for protocol: $_protocolId');

    _logger.info('Bitswap protocol handlers initialized');
  }

  /// Requests a single block by CID, checking the local blockstore, P2P
  /// Bitswap, and finally configured HTTP gateways.
  Future<Block?> wantBlock(String cid) async =>
      getBlock(cid, useHttpFallback: true);

  /// Fetches a single block by CID, checking the local blockstore, P2P Bitswap,
  /// and finally configured HTTP gateways.
  ///
  /// If [useHttpFallback] is `false`, the HTTP gateway fallback is skipped even
  /// if it is enabled in the configuration.
  Future<Block?> getBlock(String cidStr, {bool useHttpFallback = true}) async {
    if (!_running) {
      throw StateError('BitswapHandler is not running');
    }

    return _getBlock(cidStr, useHttpFallback: useHttpFallback);
  }

  Future<Block?> _getBlock(String cidStr,
      {required bool useHttpFallback}) async {
    final denylist = _denylistService;
    if (denylist != null &&
        denylist.configuredEnabled &&
        denylist.isBlockedByCidString(cidStr)) {
      final action = denylist.recordHit(cidStr, source: 'rpc');
      if (action == 'block') {
        _logger.warning('Denylist: rejected Bitswap retrieval for $cidStr');
        return null;
      }
    }

    // 1. Try local blockstore.
    final localResponse = await _blockStore.getBlock(cidStr);
    if (localResponse.found && localResponse.hasBlock()) {
      try {
        return Block.fromProto(localResponse.block);
      } catch (e, st) {
        _logger.warning(
          'Failed to deserialize cached block for $cidStr',
          e,
          st,
        );
      }
    }

    // 2. Try P2P Bitswap.
    try {
      final blocks = await want([cidStr]).timeout(_bitswapConfig.p2pTimeout);
      if (blocks.isNotEmpty) {
        return blocks.first;
      }
    } catch (e) {
      _logger.debug('P2P Bitswap failed for $cidStr: $e');
    }

    // 3. Try HTTP gateway fallback.
    if (!useHttpFallback ||
        !_bitswapConfig.enableHttpFallback ||
        _httpGatewayClient == null) {
      return null;
    }

    for (final gateway in _bitswapConfig.httpFallbackGateways) {
      if (!_isValidGatewayUrl(gateway)) {
        _logger.warning('Skipping invalid HTTP gateway URL: $gateway');
        continue;
      }

      try {
        final bytes = await _httpGatewayClient.fetchRawBlock(
          gateway,
          cidStr,
          timeout: _bitswapConfig.httpTimeout,
          maxBlockSize: _bitswapConfig.maxHttpBlockSize,
        );
        if (bytes == null) {
          continue;
        }

        final block = Block(cid: CID.decode(cidStr), data: bytes);
        final valid =
            _bitswapConfig.verifyHttpBlocks ? await block.validate() : true;
        if (!valid) {
          _logger.warning(
            'HTTP fallback returned invalid block for $cidStr from $gateway',
          );
          continue;
        }

        final putResponse = await _blockStore.putBlock(block);
        if (!putResponse.success) {
          _logger.warning(
            'Failed to cache verified HTTP block for $cidStr: ${putResponse.message}',
          );
        }
        return block;
      } catch (e) {
        _logger.warning(
          'HTTP fallback failed for $cidStr from $gateway: $e',
        );
      }
    }

    return null;
  }

  bool _isValidGatewayUrl(String url) {
    Uri uri;
    try {
      uri = Uri.parse(url);
    } catch (_) {
      return false;
    }

    if (uri.scheme != 'http' && uri.scheme != 'https') {
      _logger.warning('Invalid gateway URL scheme: $url');
      return false;
    }

    if (uri.scheme == 'http') {
      _logger.warning('Using insecure HTTP gateway: $url');
    }

    if (!_bitswapConfig.allowPrivateGateways &&
        _isPrivateOrLoopbackHost(uri.host)) {
      _logger.warning('Rejecting private/loopback gateway URL: $url');
      return false;
    }

    return true;
  }

  bool _isPrivateOrLoopbackHost(String host) {
    if (host.isEmpty) return true;
    if (host == 'localhost' || host == '127.0.0.1' || host == '::1') {
      return true;
    }
    if (host.startsWith('127.')) return true;
    if (host.startsWith('10.') ||
        host.startsWith('192.168.') ||
        host.startsWith('169.254.')) {
      return true;
    }
    if (host.startsWith('172.')) {
      final parts = host.split('.');
      if (parts.length > 1) {
        final second = int.tryParse(parts[1]);
        if (second != null && second >= 16 && second <= 31) {
          return true;
        }
      }
    }
    // IPv6 unique local addresses (fc00::/7) and loopback (::1).
    if (host.startsWith('fc') || host.startsWith('fd')) return true;
    return false;
  }

  /// Total bytes sent.
  int get bandwidthSent => _bandwidthSent;

  /// Total bytes received.
  int get bandwidthReceived => _bandwidthReceived;

  void _updateBandwidthStats() {
    final stats = _ledgerManager.getBandwidthStats();
    _bandwidthSent = stats['sent'] ?? 0;
    _bandwidthReceived = stats['received'] ?? 0;
  }

  /// Returns the current status of the Bitswap handler.
  Future<Map<String, dynamic>> getStatus() async {
    return {
      'active_sessions': _sessions.length,
      'wanted_blocks': _wantlist.entries.length,
      'peers': _connectedPeers.length,
      'blocks_received': _blocksReceived,
      'blocks_sent': _blocksSent,
    };
  }
}
