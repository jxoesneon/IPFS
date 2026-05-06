// src/protocols/protocol_coordinator.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cbor/enhanced_cbor_handler.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipld_handler.dart';
import 'package:dart_ipfs/src/core/ipld/selectors/ipld_selector.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:dart_ipfs/src/protocols/bitswap/bitswap_handler.dart';
import 'package:dart_ipfs/src/protocols/graphsync/graphsync_handler.dart';
import 'package:dart_ipfs/src/utils/logger.dart';

/// Coordinates data retrieval across multiple protocols.
///
/// Orchestrates Bitswap, Graphsync, and IPLD handlers for
/// efficient content fetching with fallback strategies.
class ProtocolCoordinator {
  /// Creates a coordinator for the given protocol handlers.
  ProtocolCoordinator(this._bitswap, this._graphsync, this._ipld)
    : _logger = Logger('ProtocolCoordinator');

  final BitswapHandler _bitswap;
  final GraphsyncHandler _graphsync;
  final IPLDHandler _ipld;
  final Logger _logger;

  /// Initializes all protocol handlers.
  Future<void> initialize() async {
    _logger.debug('Initializing protocol handlers...');
    try {
      await _ipld.start();
      await _bitswap.start();
      await _graphsync.start();
      _logger.info('Protocol handlers initialized successfully');
    } catch (e, st) {
      _logger.error('Failed to initialize protocol handlers', e, st);
      rethrow;
    }
  }

  /// Retrieves data by CID using available protocols.
  ///
  /// Parameters:
  /// - [cid]: The Content Identifier to retrieve.
  /// - [useGraphsync]: Whether to attempt retrieval via Graphsync if a selector is provided.
  /// - [selector]: Optional IPLD selector for complex data retrieval.
  /// - [timeout]: Maximum time to wait for retrieval (defaults to 30 seconds).
  ///
  /// Returns the retrieved [Block], or `null` if not found or an error occurred.
  Future<Block?> retrieveData(
    String cid, {
    bool useGraphsync = true,
    IPLDSelector? selector,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    _logger.debug('Retrieving data for CID: $cid');
    try {
      return await _retrieveInternal(
        cid,
        useGraphsync,
        selector,
      ).timeout(timeout);
    } on TimeoutException {
      _logger.warning('Retrieval timed out for CID: $cid');
      return null;
    } catch (e, st) {
      _logger.error('Error retrieving data for CID: $cid', e, st);
      return _fallbackIpldRetrieval(cid);
    }
  }

  Future<Block?> _retrieveInternal(
    String cid,
    bool useGraphsync,
    IPLDSelector? selector,
  ) async {
    if (useGraphsync && selector != null) {
      _logger.debug('Attempting Graphsync retrieval for CID: $cid');
      final graphsyncBlock = await _graphsync.requestGraph(cid, selector);
      if (graphsyncBlock != null) {
        _logger.debug('Successfully retrieved CID $cid via Graphsync');
        return Block.fromData(
          Uint8List.fromList(graphsyncBlock.data),
          format: 'dag-cbor',
        );
      }
    }

    _logger.debug('Attempting Bitswap retrieval for CID: $cid');
    return _bitswap.wantBlock(cid);
  }

  Future<Block?> _fallbackIpldRetrieval(String cid) async {
    _logger.debug('Attempting fallback IPLD resolution for CID: $cid');
    try {
      final resolvedData = await _ipld.get(CID.decode(cid));
      if (resolvedData != null) {
        final Uint8List encodedData;
        if (resolvedData.kind == Kind.BYTES) {
          encodedData = Uint8List.fromList(
            resolvedData.bytesValue as List<int>,
          );
        } else {
          encodedData = await EnhancedCBORHandler.encodeCbor(
            resolvedData as IPLDNode,
          );
        }
        _logger.debug('Successfully resolved CID $cid via fallback IPLD');
        return Block.fromData(encodedData, format: 'dag-cbor');
      }
    } catch (e) {
      _logger.debug('Fallback IPLD resolution failed for CID: $cid');
    }
    return null;
  }

  /// Returns the status of all protocol handlers.
  Future<Map<String, dynamic>> getStatus() async {
    try {
      return {
        'bitswap': await _bitswap.getStatus(),
        'graphsync': await _graphsync.getStatus(),
        'ipld': await _ipld.getStatus(),
      };
    } catch (e, st) {
      _logger.error('Failed to get protocol status', e, st);
      return {'error': e.toString()};
    }
  }

  /// Stops all protocol handlers.
  Future<void> stop() async {
    _logger.debug('Stopping protocol handlers...');
    try {
      await _graphsync.stop();
      await _bitswap.stop();
      await _ipld.stop();
      _logger.info('Protocol handlers stopped successfully');
    } catch (e, st) {
      _logger.error('Failed to stop protocol handlers', e, st);
    }
  }
}
