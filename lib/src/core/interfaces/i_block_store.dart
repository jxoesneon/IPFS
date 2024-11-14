// src/core/interfaces/i_block_store.dart
import 'package:dart_ipfs/src/core/interfaces/i_storage_system.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';

abstract class IBlockStore extends IStorageSystem {
  Future<void> start();
  Future<void> stop();
  @override
  Future<GetBlockResponse> getBlock(String cid);
  @override
  Future<AddBlockResponse> putBlock(Block block);
  @override
  Future<RemoveBlockResponse> removeBlock(String cid);
  Future<List<Block>> getAllBlocks();
  Future<Map<String, dynamic>> getStatus();
}
