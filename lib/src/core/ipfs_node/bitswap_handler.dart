import 'dart:io';
import 'dart:async';
import 'package:p2plib/p2plib.dart' as p2p;
import 'package:dart_ipfs/src/transport/p2plib_router.dart';
import 'package:dart_ipfs/src/protocols/bitswap/ledger.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/protocols/bitswap/wantlist.dart';
import 'package:dart_ipfs/src/proto/generated/core/cid.pb.dart';
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
  int _bandwidthSent = 0;
  int _bandwidthReceived = 0;

  BitswapHandler(config, this._blockStore) : _router = P2plibRouter(config) {
    _setupHandlers();
  }

  /// Starts the Bitswap handler
  Future<void> start() async {
    if (_running) return;
    _running = true;

    await _router.start();
    _router.addMessageHandler(_protocolId, _handlePacket);
    // Register protocol identifier
    _router.registerProtocol(_protocolId);
    print('Bitswap handler started with protocol: $_protocolId');
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

    await _router.stop();
    print('Bitswap handler stopped');
  }

  /// Handles incoming Bitswap messages
  void _handleMessage(message.Message message) {
    if (!_running) return;

    final fromPeer = message.from;
    if (fromPeer == null) {
      print('Received message without peer ID');
      return;
    }

    // Update peer ledger
    final ledger = _ledgerManager.getLedger(fromPeer);

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
      _handleWantlist(wantlist, fromPeer);
    }

    if (message.hasBlocks()) {
      final blocks = message.getBlocks();
      _handleBlocks(blocks);
      // Update received bytes in ledger
      ledger.addReceivedBytes(blocks
          .map((Block? b) => b?.data.length ?? 0)
          .fold<int>(0, (sum, size) => (sum + size).toInt()));
      _updateBandwidthStats();
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

      // Convert string CID to proto
      final proto = IPFSCIDProto()
        ..version = IPFSCIDVersion.IPFS_CID_VERSION_1
        ..codec = cidStr;

      final response = await _blockStore.getBlock(proto.toString());
      if (response.found) {
        final msg = message.Message()
          ..addBlock(Block.fromProto(response.block))
          ..from = _router.peerID;

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

      _blockStore.addBlock(block.toProto());

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
      }
    }

    final wantlist = Wantlist();
    for (final cid in cids) {
      wantlist.add(cid, priority: priority);
      _wantlist.add(cid, priority: priority);
    }

    final msg = message.Message();
    for (var entry in wantlist.entries.entries) {
      msg.addWantlistEntry(entry.key, // this is the cid string
          priority: entry.value, // this is the priority
          wantType: message.WantType.block,
          sendDontHave: true);
    }
    msg.from = _router.peerID;

    await _broadcastWantRequest(msg);

    // Wait for all blocks with timeout
    final futures = completers.values
        .map((completer) => completer.future.timeout(timeout,
            onTimeout: () => throw TimeoutException('Block request timed out')))
        .toList();

    try {
      return await Future.wait(futures);
    } catch (e) {
      // Clean up pending requests that failed
      for (final cid in completers.keys) {
        _pendingBlocks.remove(cid);
      }
      rethrow;
    }
  }

  /// Broadcasts want request to connected peers
  Future<void> _broadcastWantRequest(message.Message message) async {
    final connectedPeers = _router.routes.values.map((e) => e.peer).toList();

    if (connectedPeers.isEmpty) {
      throw StateError('No connected peers to broadcast want request to');
    }

    final messageBytes = message.toBytes();
    final futures = <Future<void>>[];

    for (final peer in connectedPeers) {
      futures.add(Future(() {
        _router.routerL0.sendDatagram(
          addresses: [peer.address.ip],
          datagram: messageBytes,
        );
        print('Want request sent to peer: ${peer.id}');
      }).catchError((error) {
        print('Error sending want request to peer ${peer.id}: $error');
      }));
    }

    await Future.wait(futures);
  }

  /// Helper method to get peer address
  InternetAddress _getPeerAddress(String peerId) {
    final peer = _router.routes.values.map((e) => e.peer).firstWhere(
        (p) => p.id == peerId,
        orElse: () => throw StateError('Peer not found: $peerId'));
    return InternetAddress(peer.address.ip);
  }

  void _handlePacket(p2p.Packet packet) {
    _handleMessage(message.Message.fromBytes(packet.datagram));
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
    // Register the Bitswap protocol handler
    _router.addMessageHandler(_protocolId, _handlePacket);

    // Register the protocol with the router
    _router.registerProtocol(_protocolId);

    print('Bitswap protocol handlers initialized');
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
}
