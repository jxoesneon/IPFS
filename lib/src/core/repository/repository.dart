import 'dart:typed_data';
import 'package:dart_ipfs/src/core/data_structures/node.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/merkle_dag_node.dart';
import 'package:dart_ipfs/src/proto/generated/bitswap/bitswap.pb.dart' as proto;
import 'package:dart_ipfs/src/core/storage/datastore.dart';
import 'package:fixnum/fixnum.dart' as fixnum;

/// Repository handles the storage and retrieval of IPFS data structures
class Repository {
  final Datastore _datastore;

  Repository(this._datastore);

  /// Adds a file to the repository and returns its node link
  Future<NodeLink> addFile(String path, Block block) async {
    try {
      // Store the block data in the datastore using Key
      final key = Key('/blocks/${block.cid.toString()}');
      await _datastore.put(key, block.data);

      // Create a node link for the block
      return NodeLink(
        name: path.split('/').last,
        size: fixnum.Int64(block.data.length),
        cid: block.cid,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Processes a protobuf block and stores it in the repository
  Future<void> processProtoBlock(proto.Message_Block protoBlock) async {
    try {
      // Convert protobuf block to our Block type
      final block = await Block.fromBitswapProto(protoBlock);

      // Store the block data
      final key = Key('/blocks/${block.cid.toString()}');
      await _datastore.put(key, block.data);
    } catch (e) {
      rethrow;
    }
  }

  /// Retrieves a block from the repository by its CID
  Future<Block?> getBlock(String cid) async {
    try {
      final key = Key('/blocks/$cid');
      final data = await _datastore.get(key);
      if (data == null) return null;

      // Reconstruct Block from data - use raw format since we're just retrieving
      return Block.fromData(Uint8List.fromList(data), format: 'raw');
    } catch (e) {
      return null;
    }
  }

  /// Checks if a block exists in the repository
  Future<bool> hasBlock(String cid) async {
    try {
      final key = Key('/blocks/$cid');
      return await _datastore.has(key);
    } catch (e) {
      return false;
    }
  }

  /// Removes a block from the repository
  Future<bool> removeBlock(String cid) async {
    try {
      // First check if the block exists
      if (!await hasBlock(cid)) {
        return false;
      }

      // Remove the block from the datastore
      final key = Key('/blocks/$cid');
      await _datastore.delete(key);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Creates a MerkleDAG node from a block
  Future<MerkleDAGNode?> createNode(Block block) async {
    try {
      return MerkleDAGNode.fromBytes(block.data);
    } catch (e) {
      return null;
    }
  }
}
