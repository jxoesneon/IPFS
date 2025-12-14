// src/protocols/bitswap/bitswap_handler.dart
import 'dart:io';
import 'dart:async';
import 'package:p2plib/p2plib.dart' as p2p;
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/utils/base58.dart';
import 'package:dart_ipfs/src/transport/p2plib_router.dart';
import 'package:dart_ipfs/src/protocols/bitswap/ledger.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/protocols/bitswap/wantlist.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/protocols/bitswap/message.dart' as message;

/// Handles Bitswap protocol operations for an IPFS node following the Bitswap 1.2.0 specification
class BitswapHandler {
  final BlockStore _blockStore;
  final P2plibRouter _router;
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
  int _blocksSent = 0;

  BitswapHandler(IPFSConfig config, this._blockStore, this._router)
      : _logger = Logger('BitswapHandler',
            debug: config.debug, verbose: config.verboseLogging) {
    _logger.info('Initializing BitswapHandler');
    _setupHandlers();
  }

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

      _router.addMessageHandler(_protocolId, _handlePacket);
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
    print('Bitswap handler stopped');
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
      final wantlist = Wantlist()
        ..entries.addAll(
          Map.fromEntries(
            messageWantlist.entries.entries.map(
              (e) => MapEntry(e.key, e.value.priority),
            ),
          ),
        );
      // We need 'fromPeer' to reply. If it's missing, we can't reply.
      if (fromPeer != null) {
        await _handleWantlist(wantlist, fromPeer);
      }
    }

    if (message.hasBlocks()) {
      // Blocks don't strictly require 'fromPeer' to be useful (we verified content hash).
      _handleBlocks(message.getBlocks());

      if (fromPeer != null) {
        final ledger = _ledgerManager.getLedger(fromPeer);
        // Update received bytes in ledger
        ledger.addReceivedBytes(message
            .getBlocks()
            .map((b) => b.data.length)
            .fold<int>(0, (sum, size) => sum + size));
        _updateBandwidthStats();
      }
    }
  }

  /// Handles incoming wantlist entries according to Bitswap spec
  Future<void> _handleWantlist(Wantlist wantlist, String fromPeer) async {
    // Sort entries by priority before processing
    final sortedEntries = wantlist.entries.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)); // Higher priority first

    for (final entry in sortedEntries) {
      final cidStr = entry.key;
      final priority = entry.value;

      // Add to our local wantlist with the received priority
      _wantlist.add(cidStr, priority: priority);

      // Check if we have the block
      final response = await _blockStore.getBlock(cidStr);
      if (response.found) {
        final msg = message.Message()
          ..addBlock(Block.fromProto(response.block))
          ..from = _router.peerID.toString();

        final messageBytes = msg.toBytes();

        try {
          // Send block to requesting peer
          _router.routerL0.sendDatagram(
            addresses: [
              p2p.FullAddress(port: 4001, address: _getPeerAddress(fromPeer))
            ],
            datagram: messageBytes,
          );
          // Update sent bytes in ledger
          final ledger = _ledgerManager.getLedger(fromPeer);
          ledger.addSentBytes(response.block.data.length);
          _updateBandwidthStats();
        } catch (error) {
          print('Error sending block to peer $fromPeer: $error');
        }
      }
    }
  }

  /// Handles incoming blocks according to Bitswap spec
  void _handleBlocks(List<Block> blocks) {
    for (final block in blocks) {
      // Validate block before storing
      if (!block.validate()) {
        print('Received invalid block: ${block.cid}');
        continue;
      }

      _blockStore.putBlock(block);

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
  Future<List<Block>> want(List<String> cids,
      {int priority = 1,
      Duration timeout = const Duration(seconds: 30)}) async {
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
      msg.addWantlistEntry(cid,
          priority: priority,
          wantType: message.WantType.block,
          sendDontHave: true);
    }

    await _broadcastWantRequest(msg);

    try {
      final futures = completers.values
          .map((completer) => completer.future.timeout(timeout,
              onTimeout: () =>
                  throw TimeoutException('Block request timed out')))
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
    final connectedPeers = _router.routerL0.routes.values
        .map((route) => p2p.PeerId(value: route.peerId.value))
        .toList();

    if (connectedPeers.isEmpty) {
      throw StateError('No connected peers to broadcast want request to');
    }

    final messageBytes = message.toBytes();
    final futures = <Future<void>>[];

    for (final peer in connectedPeers) {
      futures.add(Future(() {
        _router.routerL0.sendDatagram(
          addresses: [
            p2p.FullAddress(
                address: _getPeerAddress(Base58().encode(peer.value)),
                port: 4001)
          ],
          datagram: messageBytes,
        );
        print('Want request sent to peer: ${peer.toString()}');
      }).catchError((error) {
        print('Error sending want request to peer ${peer.toString()}: $error');
      }));
    }

    await Future.wait(futures);
  }

  /// Helper method to get peer address
  InternetAddress _getPeerAddress(String peerIdStr) {
    try {
      final peerId = p2p.PeerId(value: Base58().base58Decode(peerIdStr));
      final routes = _router.routerL0.routes;

      // Optimized lookup
      if (routes.containsKey(peerId)) {
        final addresses = _router.routerL0.resolvePeerId(peerId);
        if (addresses.isNotEmpty) {
          return addresses.first.address;
        }
        throw StateError('No addresses found for peer: $peerIdStr');
      }

      throw StateError('Peer not found: $peerIdStr');
    } catch (e) {
      throw StateError('Could not resolve address for $peerIdStr: $e');
    }
  }

  Future<void> _handlePacket(p2p.Packet packet) async {
    final msg = await message.Message.fromBytes(packet.datagram);
    // Annotate message with sender
    msg.from = Base58().encode(packet.srcPeerId.value);

    await _handleMessage(msg);
  }

  Future<void> handleWantRequest(String cidStr) async {
    try {
      final customMessage = message.Message();
      customMessage.addWantlistEntry(cidStr,
          priority: 1, wantType: message.WantType.block, sendDontHave: true);

      await _broadcastWantRequest(customMessage);
    } catch (e) {
      print('Error handling want request: $e');
      rethrow;
    }
  }

  void _setupHandlers() {
    _logger.debug('Setting up Bitswap protocol handlers');
    _router.registerProtocol(_protocolId);
    _logger.debug('Registered protocol: $_protocolId');

    _router.addMessageHandler(_protocolId, _handlePacket);
    _logger.debug('Added message handler for protocol: $_protocolId');

    _logger.info('Bitswap protocol handlers initialized');
  }

  Future<Block?> wantBlock(String cid) async {
    if (!_running) {
      throw StateError('BitswapHandler is not running');
    }

    try {
      final blocks = await want([cid]);
      return blocks.isNotEmpty ? blocks.first : null;
    } catch (e) {
      print('Error requesting block $cid: $e');
      return null;
    }
  }

  int get bandwidthSent => _bandwidthSent;
  int get bandwidthReceived => _bandwidthReceived;

  void _updateBandwidthStats() {
    final stats = _ledgerManager.getBandwidthStats();
    _bandwidthSent = stats['sent'] ?? 0;
    _bandwidthReceived = stats['received'] ?? 0;
  }

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
