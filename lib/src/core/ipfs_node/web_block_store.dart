import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/interfaces/i_block_store.dart';
import 'package:dart_ipfs/src/core/responses/block_response_factory.dart';
import 'package:dart_ipfs/src/platform/platform.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';

/// Web-compatible implementation of IBlockStore using IpfsPlatform storage.
class WebBlockStore implements IBlockStore {
  /// Creates a [WebBlockStore] wrapping the given [IpfsPlatform] storage.
  WebBlockStore(this._platform);
  final IpfsPlatform _platform;

  @override
  Future<void> start() async {
    // No explicit start needed for IpfsPlatform
  }

  @override
  Future<void> stop() async {
    // No explicit stop needed
  }

  @override
  Future<GetBlockResponse> getBlock(String cid) async {
    try {
      final data = await _platform.readBytes('blocks/$cid');
      if (data == null) {
        return BlockResponseFactory.notFound();
      }

      // Reconstruct Block object
      final block = Block(cid: CID.decode(cid), data: data);
      return BlockResponseFactory.successGet(block.toProto());
    } catch (e) {
      return BlockResponseFactory.notFound();
    }
  }

  @override
  Future<AddBlockResponse> putBlock(Block block) async {
    try {
      final cidStr = block.cid.encode();
      await _platform.writeBytes('blocks/$cidStr', block.data);
      return BlockResponseFactory.successAdd('Block added');
    } catch (e) {
      return BlockResponseFactory.failureAdd(e.toString());
    }
  }

  @override
  Future<RemoveBlockResponse> removeBlock(String cid) async {
    try {
      await _platform.delete('blocks/$cid');
      return BlockResponseFactory.successRemove('Block removed');
    } catch (e) {
      return BlockResponseFactory.failureRemove(e.toString());
    }
  }

  @override
  Future<bool> hasBlock(String cid) async {
    // Inefficient check (reads whole block), but generic platform verification
    // requires a generic 'exists' method which isn't guaranteed on all implementations of readBytes
    // unless we trust readBytes(path) == null means missing.
    final data = await _platform.readBytes('blocks/$cid');
    return data != null;
  }

  @override
  Future<List<Block>> getAllBlocks() async {
    try {
      final keys = await _platform.listDirectory('blocks');
      final blocks = <Block>[];
      for (final key in keys) {
        // Platform returns relative path 'blocks/cid' or just 'cid'?
        // Implementations vary. Assuming standard behavior (like idb_shim adapter) returns keys.
        // We'll strip directory if present.
        var cidStr = key;
        if (cidStr.startsWith('blocks/')) {
          cidStr = cidStr.substring(7);
        }

        // Skip non-CID files if any
        if (cidStr.isEmpty) continue;

        final data = await _platform.readBytes(key);
        if (data != null) {
          try {
            blocks.add(Block(cid: CID.decode(cidStr), data: data));
          } catch (_) {
            // Ignore invalid CIDs
          }
        }
      }
      return blocks;
    } catch (e) {
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>> getStatus() async {
    try {
      final blocks = await getAllBlocks();
      final size = blocks.fold<int>(0, (sum, b) => sum + b.size);
      return {
        'total_blocks': blocks.length,
        'total_size': size,
        'pinned_blocks': 0, // Pinning not integrated in this simple store yet
      };
    } catch (_) {
      return {'total_blocks': 0, 'total_size': 0};
    }
  }
}
