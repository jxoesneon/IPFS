// src/core/ipfs_node/web_block_store.dart
import 'dart:typed_data';

import '../../platform/platform.dart';
import '../../proto/generated/core/blockstore.pb.dart';
import '../../proto/generated/core/dag.pb.dart' as dag_pb;
import '../cid.dart';
import '../data_structures/block.dart';
import '../interfaces/i_block_store.dart';
import '../responses/block_response_factory.dart';

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
    final data = await _platform.readBytes('blocks/$cid');
    return data != null;
  }

  @override
  Future<List<Block>> getAllBlocks() async {
    try {
      final keys = await _platform.listDirectory('blocks');
      final blocks = <Block>[];
      for (final key in keys) {
        var cidStr = key;
        if (cidStr.startsWith('blocks/')) {
          cidStr = cidStr.substring(7);
        }

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
      final pinned = await _pinnedCids();
      return {
        'total_blocks': blocks.length,
        'total_size': size,
        'pinned_blocks': pinned.length,
      };
    } catch (_) {
      return {'total_blocks': 0, 'total_size': 0};
    }
  }

  /// Returns the set of pinned CID strings recorded under the `pins/`
  /// prefix (written by `IPFSWebNode.pin`).
  Future<Set<String>> _pinnedCids() async {
    try {
      final entries = await _platform.listDirectory('pins');
      return {
        for (final path in entries)
          if (path.split('/').last.isNotEmpty) path.split('/').last,
      };
    } catch (_) {
      return const {};
    }
  }

  @override
  Future<int> gc() async {
    // Pin-aware mark-and-sweep: retain every pinned CID plus the DAG
    // reachable from it via dag-pb links, then delete everything else.
    final pinned = await _pinnedCids();

    final keep = <String>{};
    final queue = pinned.toList();
    while (queue.isNotEmpty) {
      final cidStr = queue.removeLast();
      if (!keep.add(cidStr)) continue;

      final data = await _platform.readBytes('blocks/$cidStr');
      if (data == null) continue;

      // Traverse dag-pb links so pinned roots retain their children.
      try {
        final pbNode = dag_pb.PBNode.fromBuffer(data);
        for (final link in pbNode.links) {
          final child = CID.fromBytes(Uint8List.fromList(link.hash));
          queue.add(child.encode());
        }
      } catch (_) {
        // Not a dag-pb node (e.g. a raw block) — no links to follow.
      }
    }

    var removed = 0;
    for (final key in await _platform.listDirectory('blocks')) {
      final cidStr = key.startsWith('blocks/') ? key.substring(7) : key;
      if (cidStr.isEmpty || keep.contains(cidStr)) continue;
      await _platform.delete(key);
      removed++;
    }
    return removed;
  }
}
