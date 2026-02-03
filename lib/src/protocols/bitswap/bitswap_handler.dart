import 'dart:async';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/interfaces/i_block_store.dart';
import 'package:dart_ipfs/src/protocols/bitswap/ledger.dart';
import 'package:dart_ipfs/src/protocols/bitswap/message.dart' as message;
import 'package:dart_ipfs/src/protocols/bitswap/wantlist.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:dart_ipfs/src/utils/generic_lru_cache.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:meta/meta.dart';

/// Handles Bitswap protocol operations for an IPFS node following the Bitswap 1.2.0 specification
class BitswapHandler {
  /// Creates a new [BitswapHandler] with the given [config], [_blockStore], and [_router].
  BitswapHandler(IPFSConfig config, this._blockStore, this._router)
    : _logger = Logger(
        'BitswapHandler',
        debug: config.debug,
        verbose: config.verboseLogging,
      ) {
    _logger.info('Initializing BitswapHandler');
    _setupHandlers();
  }
  final IBlockStore _blockStore;
  final RouterInterface _router;
  final Wantlist _wantlist = Wantlist();
  final LedgerManager _ledgerManager = LedgerManager();
  final Map<String, Completer<Block>> _pendingBlocks = {};
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
  Future<void> stop() async {
    if (!_running) return;
    _running = false;

    // Clean up pending requests
    for (final completer in _pendingBlocks.values) {
      completer.completeError('BitswapHandler stopped');
    }
    _pendingBlocks.clear();
    _sessions.clear();
    _connectedPeers.clear();

    await _router.stop();
    // print('Bitswap handler stopped');
  }

  /// Handles incoming Bitswap messages
  Future<void> _handleMessage(message.Message message) async {
    if (!_running) return;

    final fromPeer = message
        .from; // Note: 'from' field is transient and set by packet handler if passed?
    // Actually packet handler didn't set it in my previous `message.dart`.
    // I should check `_handlePacket`.

    // Update peer ledger if peer known
    if (fromPeer != null) {
      // final ledger = _ledgerManager.getLedger(fromPeer); // Removed unused variable
    }
    // Optimization: If fromPeer is null, we can't update ledger but can still process blocks.

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
      // Blocks don't strictly require 'fromPeer' to be useful (we verified content hash).
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
        await _router.sendMessage(fromPeer, messageBytes);

        // Update ledger stats
        final ledger = _ledgerManager.getLedger(fromPeer);
        for (final block in outgoingMessage.getBlocks()) {
          ledger.addSentBytes(block.data.length);
        }
        _updateBandwidthStats();
      } catch (error) {
        // print('Error sending response to peer $fromPeer: $error');
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
        // Peer has the block.
        // If we want it, we could prioritize asking them?
        // For now, logging.
        _logger.verbose('Peer $fromPeer HAVE $cid');
      } else {
        // Peer DOES NOT have the block.
        // We should avoid asking them again soon.
        _logger.verbose('Peer $fromPeer DONT_HAVE $cid');
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

    final completers = <String, Completer<Block>>{};
    for (final cid in cids) {
      if (!_pendingBlocks.containsKey(cid)) {
        final completer = Completer<Block>();
        _pendingBlocks[cid] = completer;
        completers[cid] = completer;
        _wantlist.add(cid, priority: priority);
      }
    }

    final msg = message.Message();
    // No messageId or Type in Bitswap 1.2+

    for (final cid in cids) {
      msg.addWantlistEntry(
        cid,
        priority: priority,
        wantType: message.WantType.block,
        sendDontHave: true, // Enable Bitswap 1.2 optimization
      );
    }

    try {
      await _broadcastWantRequest(msg);

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
        _pendingBlocks.remove(cid);
        _wantlist.remove(cid);
      }
      rethrow;
    }
  }

  /// Broadcasts want request to connected peers
  Future<void> _broadcastWantRequest(message.Message message) async {
    final connectedPeers = _router.connectedPeers;

    if (connectedPeers.isEmpty) {
      throw StateError('No connected peers to broadcast want request to');
    }

    final messageBytes = message.toBytes();
    final futures = <Future<void>>[];

    for (final peerId in connectedPeers) {
      futures.add(
        Future(() {
          _router.sendMessage(peerId, messageBytes);
          // print('Want request sent to peer: ${peer.toString()}');
        }).catchError((error) {
          // print(
          //   'Error sending want request to peer ${peer.toString()}: $error',
          // );
        }),
      );
    }

    await Future.wait(futures);
  }

  // Removed _getPeerAddress as it's no longer needed with new Router API

  Future<void> _handlePacket(NetworkPacket packet) async {
    final msg = await message.Message.fromBytes(packet.datagram);
    // Annotate message with sender
    msg.from = packet.srcPeerId;

    await _handleMessage(msg);
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
    } catch (e) {
      // print('Error handling want request: $e');
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

  /// Requests a single block by CID.
  Future<Block?> wantBlock(String cid) async {
    if (!_running) {
      throw StateError('BitswapHandler is not running');
    }

    try {
      final blocks = await want([cid]);
      return blocks.isNotEmpty ? blocks.first : null;
    } catch (e) {
      // print('Error requesting block $cid: $e');
      return null;
    }
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
