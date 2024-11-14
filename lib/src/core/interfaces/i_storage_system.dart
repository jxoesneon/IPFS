// src/core/interfaces/i_storage_system.dart
import 'package:dart_ipfs/src/core/interfaces/i_core_system.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';

abstract class IStorageSystem extends ICoreSystem {
  Future<AddBlockResponse> putBlock(Block block);
  Future<GetBlockResponse> getBlock(String cid);
  Future<RemoveBlockResponse> removeBlock(String cid);
  Future<bool> hasBlock(String cid);
}
