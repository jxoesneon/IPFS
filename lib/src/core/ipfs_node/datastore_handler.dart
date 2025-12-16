// src/core/ipfs_node/datastore_handler.dart
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'dart:typed_data';
import '../data_structures/car.dart';
import '../data_structures/block.dart';
import 'package:dart_ipfs/src/storage/datastore.dart';
import '../data_structures/merkle_dag_node.dart'; // Import MerkleDAGNode
import 'package:dart_ipfs/src/utils/car_reader.dart'; // Assuming you have a CarReader utility
import 'package:dart_ipfs/src/utils/car_writer.dart'; // Assuming you have a CarWriter utility
// lib/src/core/ipfs_node/datastore_handler.dart

/// Handles datastore operations for an IPFS node.
class DatastoreHandler {
  final Datastore _datastore;

  // Add public getter for datastore
  Datastore get datastore => _datastore;

  DatastoreHandler(IPFSConfig config)
    : _datastore = Datastore(config.datastorePath);

  /// Initializes and starts the datastore.
  Future<void> start() async {
    try {
      await _datastore.init();
      // print('Datastore initialized.');
    } catch (e) {
      // print('Error initializing datastore: $e');
    }
  }

  /// Closes the datastore.
  Future<void> stop() async {
    try {
      await _datastore.close();
      // print('Datastore closed.');
    } catch (e) {
      // print('Error closing datastore: $e');
    }
  }

  /// Stores a block in the datastore.
  Future<void> putBlock(Block block) async {
    try {
      await _datastore.put(block.cid.encode(), block);
      // print('Stored block with CID: ${block.cid.encode()}');
    } catch (e) {
      // print('Error storing block with CID ${block.cid.encode()}: $e');
    }
  }

  /// Retrieves a block from the datastore by its CID.
  Future<Block?> getBlock(String cid) async {
    try {
      final block = await _datastore.get(cid);
      if (block != null) {
        // print('Retrieved block with CID: $cid');
        return block;
      } else {
        // print('Block with CID $cid not found.');
        return null;
      }
    } catch (e) {
      // print('Error retrieving block with CID $cid: $e');
      return null;
    }
  }

  /// Checks if a block exists in the datastore by its CID.
  Future<bool> hasBlock(String cid) async {
    try {
      final exists = await _datastore.has(cid);
      // print('Block with CID $cid exists: $exists');
      return exists;
    } catch (e) {
      // print('Error checking existence of block with CID $cid: $e');
      return false;
    }
  }

  /// Loads pinned CIDs from the datastore.
  Future<Set<String>> loadPinnedCIDs() async {
    try {
      final pinnedCIDs = await _datastore.loadPinnedCIDs();
      // print('Loaded pinned CIDs: ${pinnedCIDs.length}');
      return pinnedCIDs;
    } catch (e) {
      // print('Error loading pinned CIDs: $e');
      return {};
    }
  }

  /// Persists pinned CIDs to the datastore.
  Future<void> persistPinnedCIDs(Set<String> pinnedCIDs) async {
    try {
      await _datastore.persistPinnedCIDs(pinnedCIDs);
      // print('Persisted pinned CIDs.');
    } catch (e) {
      // print('Error persisting pinned CIDs: $e');
    }
  }

  /// Imports a CAR file into the datastore.
  Future<void> importCAR(Uint8List carFile) async {
    try {
      final car = await CarReader.readCar(carFile);

      for (var block in car.blocks) {
        await putBlock(block);
        // print('Imported block with CID: ${block.cid.encode()}');

        // Optionally announce blocks to network
        // For example, using Bitswap or another protocol
        // bitswap.provide(block.cid.encode());

        // You can also handle additional logic here, such as updating metrics
        // or notifying other components of the new data
      }
    } catch (e) {
      // print('Error importing CAR file: $e');
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
      // We need to parse the block to get links
      final rootNode = MerkleDAGNode.fromBytes(rootBlock.data);
      await _recursiveGetBlocks(rootNode, blocks);

      // Create a CAR object using the blocks list
      final car = CAR(
        blocks: blocks,
        header: CarHeader(version: 1, roots: [blocks.first.cid]),
      );

      // Pass the CAR object to writeCar
      final carData = await CarWriter.writeCar(car);

      // print('Exported CAR file for root CID: $cid');

      return carData;
    } catch (e) {
      // print('Error exporting CAR file for CID $cid: $e');
      return Uint8List(0);
    }
  }

  // Helper function to recursively retrieve blocks of linked nodes
  Future<void> _recursiveGetBlocks(
    MerkleDAGNode node,
    List<Block> blocks,
  ) async {
    if (node.isDirectory) {
      for (var link in node.links) {
        final childBlock = await getBlock(link.cid.toString());
        if (childBlock != null && !blocks.contains(childBlock)) {
          blocks.add(childBlock);
          await _recursiveGetBlocks(
            MerkleDAGNode.fromBytes(childBlock.data),
            blocks,
          ); // Recursive call
        }
      }
    }
  }

  Future<Map<String, dynamic>> getStatus() async {
    return {
      'total_blocks': datastore.numBlocks,
      'total_size': datastore.size,
      'pinned_blocks': (await datastore.loadPinnedCIDs()).length,
    };
  }
}
