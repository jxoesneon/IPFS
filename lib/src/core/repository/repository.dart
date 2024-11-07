import 'package:dart_ipfs/src/core/data_structures/node.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/merkle_dag_node.dart';
import 'package:dart_ipfs/src/proto/generated/bitswap/bitswap.pb.dart' as proto;
import 'package:dart_ipfs/src/storage/datastore.dart';
import 'package:fixnum/fixnum.dart' as fixnum;

/// Repository handles the storage and retrieval of IPFS data structures
class Repository {
  final Datastore _datastore;

  Repository(this._datastore);

  /// Adds a file to the repository and returns its node link
  Future<NodeLink> addFile(String path, Block block) async {
    try {
      // Store the block in the datastore
      await _datastore.put(block.cid.toString(), block);

      // Create a node link for the block
      return NodeLink(
        name: path.split('/').last,
        size: fixnum.Int64(block.data.length),
        cid: block.cid,
      );
    } catch (e) {
      print('Error adding file to repository: $e');
      rethrow;
    }
  }

  /// Processes a protobuf block and stores it in the repository
  Future<void> processProtoBlock(proto.Block protoBlock) async {
    try {
      // Convert protobuf block to our Block type
      final block = Block.fromBitswapProto(protoBlock);

      // Store the block
      await _datastore.put(block.cid.toString(), block);
    } catch (e) {
      print('Error processing protobuf block: $e');
      rethrow;
    }
  }

  /// Retrieves a block from the repository by its CID
  Future<Block?> getBlock(String cid) async {
    try {
      return await _datastore.get(cid);
    } catch (e) {
      print('Error retrieving block from repository: $e');
      return null;
    }
  }

  /// Checks if a block exists in the repository
  Future<bool> hasBlock(String cid) async {
    try {
      return await _datastore.has(cid);
    } catch (e) {
      print('Error checking block existence in repository: $e');
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
      await _datastore.delete(cid);
      return true;
    } catch (e) {
      print('Error removing block from repository: $e');
      return false;
    }
  }

  /// Creates a MerkleDAG node from a block
  Future<MerkleDAGNode?> createNode(Block block) async {
    try {
      return MerkleDAGNode.fromBytes(block.data);
    } catch (e) {
      print('Error creating node from block: $e');
      return null;
    }
  }
}
