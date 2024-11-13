import 'dart:async';
import 'dart:typed_data';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/data_structures/merkle_dag_node.dart';

/// Handles IPLD (InterPlanetary Linked Data) operations for an IPFS node.
class IPLDHandler {
  final BlockStore _blockStore;
  final IPFSConfig _config;
  late final Logger _logger;
  
  // Supported IPLD codecs
  static const Map<String, int> CODECS = {
    'raw': 0x55,
    'dag-pb': 0x70,
    'dag-cbor': 0x71,
    'dag-json': 0x0129,
  };

  IPLDHandler(this._blockStore, this._config) {
    _logger = Logger('IPLDHandler');
    _logger.debug('Creating new IPLDHandler instance');
  }

  /// Starts the IPLD handler
  Future<void> start() async {
    _logger.debug('Starting IPLDHandler...');
    try {
      // Initialize codec support
      _logger.verbose('Initializing IPLD codecs');
      // Additional initialization if needed
      _logger.debug('IPLDHandler started successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to start IPLDHandler', e, stackTrace);
      rethrow;
    }
  }

  /// Stops the IPLD handler
  Future<void> stop() async {
    _logger.debug('Stopping IPLDHandler...');
    try {
      // Cleanup if needed
      _logger.debug('IPLDHandler stopped successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to stop IPLDHandler', e, stackTrace);
      rethrow;
    }
  }

  /// Puts a node into the blockstore with the specified codec
  Future<CID> put(Uint8List data, {String codec = 'dag-cbor'}) async {
    _logger.debug('Putting data with codec: $codec');
    try {
      if (!CODECS.containsKey(codec)) {
        throw ArgumentError('Unsupported codec: $codec');
      }

      _logger.verbose('Creating block from data');
      final block = await Block.fromData(data);
      
      _logger.verbose('Creating CID with codec: $codec');
      final cid = CID.fromBytes(block.data, codec);
      
      _logger.verbose('Adding block to blockstore');
      await _blockStore.addBlock(block.toProto());
      
      _logger.debug('Successfully stored data with CID: ${cid.encode()}');
      return cid;
    } catch (e, stackTrace) {
      _logger.error('Failed to put data', e, stackTrace);
      rethrow;
    }
  }

  /// Gets a node from the blockstore and decodes it according to its codec
  Future<Uint8List?> get(CID cid) async {
    _logger.debug('Getting data for CID: ${cid.encode()}');
    try {
      _logger.verbose('Retrieving block from blockstore');
      final response = await _blockStore.getBlock(cid.encode());
      
      if (!response.found) {
        _logger.warning('Block not found for CID: ${cid.encode()}');
        return null;
      }

      final block = Block.fromProto(response.block);
      _logger.debug('Successfully retrieved data for CID: ${cid.encode()}');
      return block.data;
    } catch (e, stackTrace) {
      _logger.error('Failed to get data', e, stackTrace);
      rethrow;
    }
  }

  /// Resolves an IPLD path
  Future<Uint8List?> resolve(String path) async {
    _logger.debug('Resolving IPLD path: $path');
    try {
      final parts = path.split('/');
      final rootCid = CID.decode(parts[0]);
      
      if (parts.length == 1) {
        return await get(rootCid);
      }

      _logger.verbose('Traversing IPLD path');
      var current = await get(rootCid);
      
      for (var i = 1; i < parts.length && current != null; i++) {
        final node = MerkleDAGNode.fromBytes(current!);
        final link = node.links.firstWhere(
          (l) => l.name == parts[i],
          orElse: () => throw Exception('Path segment not found: ${parts[i]}'),
        );
        current = await get(link.cid);
      }

      _logger.debug('Successfully resolved IPLD path');
      return current;
    } catch (e, stackTrace) {
      _logger.error('Failed to resolve path', e, stackTrace);
      rethrow;
    }
  }

  /// Gets the status of the IPLD handler
  Future<Map<String, dynamic>> getStatus() async {
    return {
      'supported_codecs': CODECS.keys.toList(),
      'enabled': _config.enableIPLD,
    };
  }
}
