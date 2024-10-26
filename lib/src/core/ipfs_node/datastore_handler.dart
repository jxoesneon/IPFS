// lib/src/core/ipfs_node/datastore_handler.dart

import 'dart:typed_data';

import '/../src/storage/datastore.dart';
import '/../src/core/data_structures/block.dart';
import '/../src/utils/car_reader.dart'; // Assuming you have a CarReader utility
import '/../src/utils/car_writer.dart'; // Assuming you have a CarWriter utility

/// Handles datastore operations for an IPFS node.
class DatastoreHandler {
  final Datastore _datastore;

  DatastoreHandler(config) : _datastore = Datastore(config.datastorePath);

  /// Initializes and starts the datastore.
  Future<void> start() async {
    await _datastore.init();
    print('Datastore initialized.');
  }

  /// Closes the datastore.
  Future<void> stop() async {
    await _datastore.close();
    print('Datastore closed.');
  }

  /// Stores a block in the datastore.
  Future<void> putBlock(Block block) async {
    try {
      await _datastore.put(block.cid, block);
      print('Stored block with CID: ${block.cid}');
    } catch (e) {
      print('Error storing block with CID ${block.cid}: $e');
    }
  }

  /// Retrieves a block from the datastore by its CID.
  Future<Block?> getBlock(String cid) async {
    try {
      final block = await _datastore.get(cid);
      if (block != null) {
        print('Retrieved block with CID: $cid');
      } else {
        print('Block with CID $cid not found.');
      }
      return block;
    } catch (e) {
      print('Error retrieving block with CID $cid: $e');
      return null;
    }
  }

  /// Checks if a block exists in the datastore by its CID.
  Future<bool> hasBlock(String cid) async {
    try {
      final exists = await _datastore.has(cid);
      print('Block with CID $cid exists: $exists');
      return exists;
    } catch (e) {
      print('Error checking existence of block with CID $cid: $e');
      return false;
    }
  }

  /// Loads pinned CIDs from the datastore.
  Future<Set<String>> loadPinnedCIDs() async {
    try {
      final pinnedCIDs = await _datastore.loadPinnedCIDs();
      print('Loaded pinned CIDs: ${pinnedCIDs.length}');
      return pinnedCIDs;
    } catch (e) {
      print('Error loading pinned CIDs: $e');
      return {};
    }
  }

  /// Persists pinned CIDs to the datastore.
  Future<void> persistPinnedCIDs(Set<String> pinnedCIDs) async {
    try {
      await _datastore.persistPinnedCIDs(pinnedCIDs);
      print('Persisted pinned CIDs.');
    } catch (e) {
      print('Error persisting pinned CIDs: $e');
    }
  }

  /// Imports a CAR file into the datastore.
  Future<void> importCAR(Uint8List carFile) async {
    try {
      final car = await CarReader.readCar(carFile);
      
      for (var block in car.blocks) {
        await putBlock(block);
        print('Imported block with CID: ${block.cid}');
      }
      
      // Optionally announce blocks to network
    } catch (e) {
      print('Error importing CAR file: $e');
    }
  }

  /// Exports a CAR file from the datastore for a given CID.
  Future<Uint8List> exportCAR(String cid) async {
    try {
      final blocks = <Block>[];
      
      // Retrieve root block
      final rootBlock = await getBlock(cid);
      
      if (rootBlock == null) throw ArgumentError('Root block not found for CID: $cid');
      
      blocks.add(rootBlock);
      
      // Recursively retrieve linked blocks
      await _recursiveGetBlocks(rootBlock, blocks);
      
      final carData = await CarWriter.writeCar(blocks);
      
      print('Exported CAR file for root CID: $cid');
      
      return carData;
      
    } catch (e) {
      print('Error exporting CAR file for CID $cid: $e');
      
      return Uint8List(0); // Return empty data on error
    }
  }

  // Helper function to recursively retrieve blocks of linked nodes
  Future<void> _recursiveGetBlocks(Block block, List<Block> blocks) async {
    final node = Node.fromBytes(block.data); // Assuming Node has fromBytes method
    
    if (node.nodeType == NodeType.directory) { // Check if node is directory
     
     for (var link in node.links) { 
       final childBlock = await getBlock(link.cid); 
       
       if (childBlock != null && !blocks.contains(childBlock)) { 
         blocks.add(childBlock); 
         await _recursiveGetBlocks(childBlock, blocks); // Recursive call 
       } 
     } 
   }
}
