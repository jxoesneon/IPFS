// src/protocols/protocol_coordinator.dart
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/ipld/selectors/ipld_selector.dart';
import 'package:dart_ipfs/src/protocols/bitswap/bitswap_handler.dart';
import 'package:dart_ipfs/src/protocols/graphsync/graphsync_handler.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipld_handler.dart';

/// Coordinates data retrieval across multiple protocols.
///
/// Orchestrates Bitswap, Graphsync, and IPLD handlers for
/// efficient content fetching with fallback strategies.
class ProtocolCoordinator {
  final BitswapHandler _bitswap;
  final GraphsyncHandler _graphsync;
  final IPLDHandler _ipld;

  /// Creates a coordinator for the given protocol handlers.
  ProtocolCoordinator(this._bitswap, this._graphsync, this._ipld);

  Future<void> initialize() async {
    await _ipld.start();
    await _bitswap.start();
    await _graphsync.start();
  }

  Future<Block?> retrieveData(
    String cid, {
    bool useGraphsync = true,
    IPLDSelector? selector,
  }) async {
    try {
      if (useGraphsync && selector != null) {
        final graphsyncBlock = await _graphsync.requestGraph(cid, selector);
        return graphsyncBlock != null
            ? Block.fromData(
                Uint8List.fromList(graphsyncBlock.data),
                format: 'dag-cbor',
              )
            : null;
      } else {
        return _bitswap.wantBlock(cid);
      }
    } catch (e) {
      // If protocol-specific retrieval fails, try IPLD resolution as fallback
      try {
        final resolvedData = await _ipld.get(CID.decode(cid));
        if (resolvedData != null) {
          return Block.fromData(resolvedData, format: 'dag-cbor');
        }
      } catch (_) {
        // If IPLD resolution also fails, return null
      }
      return null;
    }
  }

  Future<Map<String, dynamic>> getStatus() async {
    return {
      'bitswap': await _bitswap.getStatus(),
      'graphsync': await _graphsync.getStatus(),
      'ipld': await _ipld.getStatus(),
    };
  }

  Future<void> stop() async {
    await _graphsync.stop();
    await _bitswap.stop();
    await _ipld.stop();
  }
}
