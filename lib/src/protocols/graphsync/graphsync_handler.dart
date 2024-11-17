// src/protocols/graphsync/graphsync_handler.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/protocols/graphsync/graphsync_types.dart';
import 'package:dart_ipfs/src/protocols/graphsync/graphsync_protocol.dart';
import 'package:dart_ipfs/src/transport/p2plib_router.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:dart_ipfs/src/protocols/bitswap/bitswap_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipld_handler.dart';

class GraphsyncHandler {
  final BitswapHandler _bitswap;
  final IPLDHandler _ipld;
  final P2plibRouter _router;
  final BlockStore _blockStore;
  final Logger _logger;
  final GraphsyncProtocol _protocol;

  GraphsyncHandler({
    required IPFSConfig config,
    required P2plibRouter router,
    required BitswapHandler bitswap,
    required IPLDHandler ipld,
    required BlockStore blockStore,
  })  : _router = router,
        _bitswap = bitswap,
        _ipld = ipld,
        _blockStore = blockStore,
        _logger = Logger('GraphsyncHandler',
            debug: config.debug, verbose: config.verboseLogging),
        _protocol = GraphsyncProtocol();

  Future<void> start() async {
    _router.registerProtocolHandler(
      GraphsyncProtocol.protocolID,
      _handleMessage,
    );
  }

  Future<void> _handleMessage(PeerID peer, Uint8List data) async {
    final message = GraphsyncMessage.fromBuffer(data);

    for (final request in message.requests) {
      if (request.cancel) {
        await _handleCancelRequest(request.id);
      } else if (request.pause) {
        await _handlePauseRequest(request.id);
      } else if (request.unpause) {
        await _handleUnpauseRequest(request.id);
      } else {
        await _handleNewRequest(peer, request);
      }
    }
  }
}
