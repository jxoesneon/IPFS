// src/core/ipfs_node/datastore_handler.dart
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/storage/datastore.dart';
import 'package:dart_ipfs/src/utils/car_reader.dart';
import 'package:dart_ipfs/src/utils/car_writer.dart';
import 'package:dart_ipfs/src/utils/logger.dart';

import '../data_structures/block.dart';
import '../data_structures/car.dart';
import '../data_structures/merkle_dag_node.dart';

/// Handles datastore operations for an IPFS node.
class DatastoreHandler {
  /// Creates a datastore handler backed by [_datastore].
  DatastoreHandler(this._datastore);

  final Datastore _datastore;
  final Logger _logger = Logger('DatastoreHandler');

  /// Provides access to the underlying datastore.
  Datastore get datastore => _datastore;

  /// Initializes and starts the datastore.
  Future<void> start() async {
    try {
      await _datastore.init();
      _logger.debug('Datastore initialized.');
    } catch (e) {
      _logger.error('Error initializing datastore: $e');
    }
  }

  /// Closes the datastore.
  Future<void> stop() async {
    try {
      await _datastore.close();
      _logger.debug('Datastore closed.');
    } catch (e) {
      _logger.error('Error closing datastore: $e');
    }
  }

  /// Stores a block in the datastore.
  Future<void> putBlock(Block block) async {
    try {
      final key = Key('/blocks/${block.cid.encode()}');
      await _datastore.put(key, block.data);
      _logger.verbose('Stored block with CID: ${block.cid.encode()}');
    } catch (e) {
      _logger.error('Error storing block with CID ${block.cid.encode()}: $e');
    }
  }

  /// Retrieves a block from the datastore by its CID.
  Future<Block?> getBlock(String cid) async {
    try {
      final key = Key('/blocks/$cid');
      final data = await _datastore.get(key);
      if (data != null) {
        _logger.verbose('Retrieved block with CID: $cid');
        // Decode the CID to get its properties (like codec)
        final decodedCid = CID.decode(cid);
        // Map codec to format string if possible, or just use the decoded CID
        return Block(
          cid: decodedCid,
          data: data,
          format: decodedCid.codec == 'dag-pb' ? 'dag-pb' : 'raw',
        );
      } else {
        _logger.verbose('Block with CID $cid not found.');
        return null;
      }
    } catch (e) {
      _logger.error('Error retrieving block with CID $cid: $e');
      return null;
    }
  }

  /// Checks if a block exists in the datastore by its CID.
  Future<bool> hasBlock(String cid) async {
    try {
      final key = Key('/blocks/$cid');
      final exists = await _datastore.has(key);
      return exists;
    } catch (e) {
      _logger.error('Error checking existence of block with CID $cid: $e');
      return false;
    }
  }

  /// Loads pinned CIDs from the datastore.
  Future<Set<String>> loadPinnedCIDs() async {
    try {
      final pinnedCIDs = <String>{};
      final q = Query(prefix: '/pins/', keysOnly: true);

      await for (final entry in _datastore.query(q)) {
        // Key is /pins/<cid>
        final cid = entry.key.toString().substring('/pins/'.length);
        pinnedCIDs.add(cid);
      }

      _logger.debug('Loaded ${pinnedCIDs.length} pinned CIDs');
      return pinnedCIDs;
    } catch (e) {
      _logger.error('Error loading pinned CIDs: $e');
      return {};
    }
  }

  /// Persists pinned CIDs to the datastore.
  Future<void> persistPinnedCIDs(Set<String> pinnedCIDs) async {
    try {
      // For this method, the previous implementation cleared and re-added.
      // We should mirror that or implement add/remove pin methods?
      // Since strict replacement is requested:

      // 1. Delete all existing pins?
      // Query all pins and delete.
      final q = Query(prefix: '/pins/', keysOnly: true);
      await for (final entry in _datastore.query(q)) {
        await _datastore.delete(entry.key);
      }

      // 2. Add new pins
      for (final cid in pinnedCIDs) {
        final key = Key('/pins/$cid');
        await _datastore.put(key, Uint8List.fromList([1])); // Store dummy value
      }
      _logger.debug('Persisted pinned CIDs.');
    } catch (e) {
      _logger.error('Error persisting pinned CIDs: $e');
    }
  }

  /// Imports a CAR file into the datastore.
  Future<void> importCAR(Uint8List carFile) async {
    try {
      final car = await CarReader.readCar(carFile);

      for (var block in car.blocks) {
        await putBlock(block);
        _logger.verbose('Imported block with CID: ${block.cid.encode()}');

        // Optionally announce blocks to network
      }
    } catch (e) {
      _logger.error('Error importing CAR file: $e');
    }
  }

  /// Exports a CAR file from the datastore for a given CID.
  Future<Uint8List> exportCAR(String cid) async {
    try {
      final blocks = <Block>[];

      // Retrieve root block
      final rootBlock = await getBlock(cid);

      if (rootBlock == null) {
        throw ArgumentError('Root block not found for CID: $cid');
      }

      blocks.add(rootBlock);

      // Recursively retrieve linked blocks
      // We only need to parse for links if the codec is dag-pb or dag-cbor
      final decodedCid = rootBlock.cid;
      if (decodedCid.codec == 'dag-pb') {
        // dag-pb
        final rootNode = MerkleDAGNode.fromBytes(rootBlock.data);
        await _recursiveGetBlocks(rootNode, blocks);
      }
      // If it's raw (0x55), it has no links, so we just include the block itself.

      // Create a CAR object using the blocks list
      final car = CAR(
        blocks: blocks,
        header: CarHeader(version: 1, roots: [blocks.first.cid]),
      );

      // Pass the CAR object to writeCar
      final carData = await CarWriter.writeCar(car);

      _logger.verbose('Exported CAR file for root CID: $cid');

      return carData;
    } catch (e) {
      _logger.error('Error exporting CAR file for CID $cid: $e');
      return Uint8List(0);
    }
  }

  // Helper function to recursively retrieve blocks of linked nodes
  Future<void> _recursiveGetBlocks(MerkleDAGNode node, List<Block> blocks) async {
    // Verify all links
    for (var link in node.links) {
      final childBlock = await getBlock(link.cid.toString());
      if (childBlock != null && !blocks.contains(childBlock)) {
        blocks.add(childBlock);

        // Only recurse if the child is also a MerkleDAG node (dag-pb)
        if (childBlock.format == 'dag-pb') {
          await _recursiveGetBlocks(
            MerkleDAGNode.fromBytes(childBlock.data),
            blocks,
          ); // Recursive call
        }
      } else {
        // print('Failed to get block for link: ${link.cid.toString()} or already present');
      }
    }
  }

  /// Returns the current status of the datastore.
  Future<Map<String, dynamic>> getStatus() async {
    // Datastore interface doesn't expose size/count cleanly.
    // We'd have to query all to count.
    // Or we skip generic counts for now or implement stat in interface.
    // For MVP, we can return 0 or implement a count query.
    return {
      'status': 'active',
      'total_blocks': 0, // Not supported in generic interface
      'total_size': 0,
      'pinned_blocks': (await loadPinnedCIDs()).length,
    };
  }
}
