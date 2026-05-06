// src/core/ipfs_node/datastore_handler.dart
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/errors/node_errors.dart';
import 'package:dart_ipfs/src/core/interfaces/i_lifecycle.dart';
import 'package:dart_ipfs/src/core/storage/datastore.dart';
import 'package:dart_ipfs/src/utils/car_reader.dart';
import 'package:dart_ipfs/src/utils/car_writer.dart';
import 'package:dart_ipfs/src/utils/logger.dart';

import '../data_structures/block.dart';
import '../data_structures/car.dart';
import '../data_structures/merkle_dag_node.dart';

/// Handles datastore operations for an IPFS node.
///
/// This handler manages block storage, pin persistence, and CAR file
/// import/export operations, wrapping the underlying [Datastore].
class DatastoreHandler implements ILifecycle {
  /// Creates a datastore handler backed by [_datastore].
  DatastoreHandler(this._datastore) : _logger = Logger('DatastoreHandler');

  final Datastore _datastore;
  final Logger _logger;

  /// Provides access to the underlying datastore.
  Datastore get datastore => _datastore;

  /// Initializes and starts the datastore.
  ///
  /// Throws [ComponentError] if initialization fails.
  @override
  Future<void> start() async {
    try {
      await _datastore.init();
      _logger.debug('Datastore initialized.');
    } catch (e, stackTrace) {
      _logger.error('Error initializing datastore', e, stackTrace);
      throw ComponentError('Datastore', 'Failed to initialize', details: e);
    }
  }

  /// Closes the datastore and releases all resources.
  @override
  Future<void> stop() async {
    try {
      await _datastore.close();
      _logger.debug('Datastore closed.');
    } catch (e, stackTrace) {
      _logger.error('Error closing datastore', e, stackTrace);
      // Do not rethrow closure errors to avoid masking other issues during shutdown.
    }
  }

  /// Stores a [block] in the datastore.
  Future<void> putBlock(Block block) async {
    try {
      final key = Key('/blocks/${block.cid.encode()}');
      await _datastore.put(key, block.data);
      _logger.verbose('Stored block with CID: ${block.cid}');
    } catch (e, stackTrace) {
      _logger.error('Error storing block with CID ${block.cid}', e, stackTrace);
    }
  }

  /// Retrieves a block from the datastore by its [cid].
  ///
  /// Returns `null` if the block is not found.
  Future<Block?> getBlock(String cid) async {
    try {
      final key = Key('/blocks/$cid');
      final data = await _datastore.get(key);
      if (data != null) {
        _logger.verbose('Retrieved block with CID: $cid');
        final decodedCid = CID.decode(cid);
        return Block(
          cid: decodedCid,
          data: data,
          format: decodedCid.codec == 'dag-pb' ? 'dag-pb' : 'raw',
        );
      } else {
        _logger.verbose('Block with CID $cid not found.');
        return null;
      }
    } catch (e, stackTrace) {
      _logger.error('Error retrieving block with CID $cid', e, stackTrace);
      return null;
    }
  }

  /// Checks if a block exists in the datastore by its [cid].
  Future<bool> hasBlock(String cid) async {
    try {
      final key = Key('/blocks/$cid');
      return await _datastore.has(key);
    } catch (e, stackTrace) {
      _logger.error(
        'Error checking existence of block with CID $cid',
        e,
        stackTrace,
      );
      return false;
    }
  }

  /// Loads the set of pinned CIDs from the datastore.
  Future<Set<String>> loadPinnedCIDs() async {
    try {
      final pinnedCIDs = <String>{};
      final q = Query(prefix: '/pins/', keysOnly: true);

      await for (final entry in _datastore.query(q)) {
        // Key format: /pins/<cid>
        final cid = entry.key.toString().substring('/pins/'.length);
        pinnedCIDs.add(cid);
      }

      _logger.debug('Loaded ${pinnedCIDs.length} pinned CIDs');
      return pinnedCIDs;
    } catch (e, stackTrace) {
      _logger.error('Error loading pinned CIDs', e, stackTrace);
      return {};
    }
  }

  /// Persists the given set of [pinnedCIDs] to the datastore.
  ///
  /// This operation is currently destructive and replaces all existing pins.
  Future<void> persistPinnedCIDs(Set<String> pinnedCIDs) async {
    try {
      // 1. Delete all existing pins
      final q = Query(prefix: '/pins/', keysOnly: true);
      await for (final entry in _datastore.query(q)) {
        await _datastore.delete(entry.key);
      }

      // 2. Add new pins
      for (final cid in pinnedCIDs) {
        final key = Key('/pins/$cid');
        await _datastore.put(
          key,
          Uint8List.fromList([1]),
        ); // Store placeholder value
      }
      _logger.debug('Persisted ${pinnedCIDs.length} pinned CIDs.');
    } catch (e, stackTrace) {
      _logger.error('Error persisting pinned CIDs', e, stackTrace);
    }
  }

  /// Imports a CAR (Content Addressable Archive) [carFile] into the datastore.
  Future<void> importCAR(Uint8List carFile) async {
    try {
      final car = await CarReader.readCar(carFile);
      int count = 0;

      for (var block in car.blocks) {
        await putBlock(block);
        count++;
        _logger.verbose('Imported block with CID: ${block.cid}');
      }
      _logger.info('Imported $count blocks from CAR file');
    } catch (e, stackTrace) {
      _logger.error('Error importing CAR file', e, stackTrace);
      throw ComponentError(
        'Datastore',
        'Failed to import CAR file',
        details: e,
      );
    }
  }

  /// Exports the DAG rooted at [cid] as a CAR formatted [Uint8List].
  Future<Uint8List> exportCAR(String cid) async {
    try {
      final blocks = <Block>[];
      final rootBlock = await getBlock(cid);

      if (rootBlock == null) {
        throw ArgumentError('Root block not found for CID: $cid');
      }

      blocks.add(rootBlock);

      final decodedCid = rootBlock.cid;
      if (decodedCid.codec == 'dag-pb') {
        final rootNode = MerkleDAGNode.fromBytes(rootBlock.data);
        await _recursiveGetBlocks(rootNode, blocks);
      }

      final car = CAR(
        blocks: blocks,
        header: CarHeader(version: 1, roots: [blocks.first.cid]),
      );

      final carData = await CarWriter.writeCar(car);
      _logger.info(
        'Exported CAR file for root CID: $cid (${blocks.length} blocks)',
      );
      return carData;
    } catch (e, stackTrace) {
      _logger.error('Error exporting CAR file for CID $cid', e, stackTrace);
      return Uint8List(0);
    }
  }

  Future<void> _recursiveGetBlocks(
    MerkleDAGNode node,
    List<Block> blocks,
  ) async {
    for (var link in node.links) {
      final childBlock = await getBlock(link.cid.toString());
      if (childBlock != null &&
          !blocks.any((b) => b.cid.toString() == childBlock.cid.toString())) {
        blocks.add(childBlock);

        if (childBlock.format == 'dag-pb') {
          await _recursiveGetBlocks(
            MerkleDAGNode.fromBytes(childBlock.data),
            blocks,
          );
        }
      }
    }
  }

  /// Returns the current status of the datastore.
  Future<Map<String, dynamic>> getStatus() async {
    try {
      final pinnedCount = (await loadPinnedCIDs()).length;
      return {'status': 'active', 'pinned_blocks': pinnedCount};
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }
}
