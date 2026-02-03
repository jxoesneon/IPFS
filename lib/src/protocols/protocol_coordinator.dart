// src/protocols/protocol_coordinator.dart
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cbor/enhanced_cbor_handler.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipld_handler.dart';
import 'package:dart_ipfs/src/core/ipld/selectors/ipld_selector.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:dart_ipfs/src/protocols/bitswap/bitswap_handler.dart';
import 'package:dart_ipfs/src/protocols/graphsync/graphsync_handler.dart';

/// Coordinates data retrieval across multiple protocols.
///
/// Orchestrates Bitswap, Graphsync, and IPLD handlers for
/// efficient content fetching with fallback strategies.
class ProtocolCoordinator {
  /// Creates a coordinator for the given protocol handlers.
  ProtocolCoordinator(this._bitswap, this._graphsync, this._ipld);
  final BitswapHandler _bitswap;
  final GraphsyncHandler _graphsync;
  final IPLDHandler _ipld;

  /// Initializes all protocol handlers.
  Future<void> initialize() async {
    await _ipld.start();
    await _bitswap.start();
    await _graphsync.start();
  }

  /// Retrieves data by CID using available protocols.
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
          // Encode IPLDNode to bytes based on its kind
          final Uint8List encodedData;
          if (resolvedData.kind == Kind.BYTES) {
            // Direct bytes value
            encodedData = Uint8List.fromList(
              resolvedData.bytesValue as List<int>,
            );
          } else {
            // Encode other kinds as dag-cbor
            encodedData = await EnhancedCBORHandler.encodeCbor(
              resolvedData as IPLDNode,
            );
          }
          return Block.fromData(encodedData, format: 'dag-cbor');
        }
      } catch (_) {
        // If IPLD resolution also fails, return null
      }
      return null;
    }
  }

  /// Returns the status of all protocol handlers.
  Future<Map<String, dynamic>> getStatus() async {
    return {
      'bitswap': await _bitswap.getStatus(),
      'graphsync': await _graphsync.getStatus(),
      'ipld': await _ipld.getStatus(),
    };
  }

  /// Stops all protocol handlers.
  Future<void> stop() async {
    await _graphsync.stop();
    await _bitswap.stop();
    await _ipld.stop();
  }
}

