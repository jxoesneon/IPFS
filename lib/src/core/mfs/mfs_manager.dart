import 'dart:async';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/directory.dart';
import 'package:dart_ipfs/src/core/interfaces/i_block_store.dart';
import 'package:dart_ipfs/src/core/storage/datastore.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_builder.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart';
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart';
import 'package:fixnum/fixnum.dart';

/// Manages the Mutable File System (MFS) for an IPFS node.
class MFSManager {
  /// Creates a new [MFSManager] with the given [blockStore] and [datastore].
  MFSManager(this._blockStore, this._datastore);
  final IBlockStore _blockStore;
  final Datastore _datastore;
  static const String _rootKey = '/mfs/root';
  CID? _rootCid;

  /// Returns the current root CID of the MFS.
  CID get rootCid => _rootCid!;

  /// Initializes the MFS by loading the root CID from the datastore
  /// or creating an empty root directory if it doesn't exist.
  Future<void> init() async {
    final rootCidBytes = await _datastore.get(Key(_rootKey));
    if (rootCidBytes != null) {
      _rootCid = CID.fromBytes(rootCidBytes);
    } else {
      final dirManager = IPFSDirectoryManager();
      final node = dirManager.build();
      final data = node.writeToBuffer();
      _rootCid = await CID.fromContent(data, codec: 'dag-pb');
      await _blockStore.putBlock(
        Block(cid: _rootCid!, data: data, format: 'dag-pb'),
      );
      await _datastore.put(Key(_rootKey), _rootCid!.toBytes());
    }
  }

  /// Creates a directory at the given [path].
  Future<void> mkdir(String path, {bool recursive = false}) async {
    final parts = _splitPath(path);
    if (parts.isEmpty) return;

    await _modifyPath(
      parts,
      (currentCid) async {
        if (currentCid != null) {
          // Directory already exists
          return currentCid;
        }
        final dirManager = IPFSDirectoryManager();
        final node = dirManager.build();
        final data = node.writeToBuffer();
        final cid = await CID.fromContent(data, codec: 'dag-pb');
        await _blockStore.putBlock(
          Block(cid: cid, data: data, format: 'dag-pb'),
        );
        return cid;
      },
      recursive: recursive,
      isDirectory: true,
    );
  }

  /// Copies a file or directory from [src] to [dest].
  Future<void> cp(String src, String dest) async {
    final srcParts = _splitPath(src);
    final srcCid = await _resolvePath(_rootCid!, srcParts);
    if (srcCid == null) {
      throw Exception('Source path not found: $src');
    }

    final destParts = _splitPath(dest);
    await _modifyPath(destParts, (currentCid) async {
      return srcCid;
    });
  }

  /// Removes a file or directory at the given [path].
  Future<void> rm(String path, {bool recursive = false}) async {
    final parts = _splitPath(path);
    if (parts.isEmpty) throw Exception('Cannot remove root');

    final parentParts = parts.sublist(0, parts.length - 1);
    final nameToRemove = parts.last;

    await _modifyPath(parentParts, (parentCid) async {
      if (parentCid == null) throw Exception('Parent path not found');
      final parentBlock = await _blockStore.getBlock(parentCid.encode());
      if (!parentBlock.found) throw Exception('Parent block not found');

      final parentNode = PBNode.fromBuffer(parentBlock.block.data);
      final newLinks = parentNode.links
          .where((l) => l.name != nameToRemove)
          .toList();

      if (!recursive && parentNode.links.length != newLinks.length) {
        // Check if it was a directory
        final removedLink = parentNode.links.firstWhere(
          (l) => l.name == nameToRemove,
        );
        final removedBlock = await _blockStore.getBlock(
          CID.fromBytes(Uint8List.fromList(removedLink.hash)).encode(),
        );
        if (removedBlock.found) {
          final removedNode = PBNode.fromBuffer(removedBlock.block.data);
          final unixData = Data.fromBuffer(removedNode.data);
          if (unixData.type == Data_DataType.Directory && !recursive) {
            throw Exception('Directory not empty');
          }
        }
      }

      parentNode.links.clear();
      parentNode.links.addAll(newLinks);

      final newData = parentNode.writeToBuffer();
      final newCid = await CID.fromContent(newData, codec: 'dag-pb');
      await _blockStore.putBlock(
        Block(cid: newCid, data: newData, format: 'dag-pb'),
      );
      return newCid;
    });
  }

  /// Lists the contents of the directory at the given [path].
  Future<List<PBLink>> ls(String path) async {
    final parts = _splitPath(path);
    final cid = await _resolvePath(_rootCid!, parts);
    if (cid == null) throw Exception('Path not found: $path');

    final block = await _blockStore.getBlock(cid.encode());
    if (!block.found) throw Exception('Block not found for CID: $cid');

    final node = PBNode.fromBuffer(block.block.data);
    return node.links;
  }

  /// Gets information about a file or directory at the given [path].
  Future<Map<String, dynamic>> stat(String path) async {
    final parts = _splitPath(path);
    final cid = await _resolvePath(_rootCid!, parts);
    if (cid == null) throw Exception('Path not found: $path');

    final block = await _blockStore.getBlock(cid.encode());
    if (!block.found) throw Exception('Block not found for CID: $cid');

    final node = PBNode.fromBuffer(block.block.data);
    final unixData = Data.fromBuffer(node.data);

    return {
      'cid': cid.encode(),
      'type': unixData.type.toString(),
      'size': unixData.filesize.toInt(),
      'cumulativeSize':
          block.block.data.length +
          node.links.fold<int>(0, (sum, l) => sum + l.size.toInt()),
      'blocks': node.links.length,
    };
  }

  /// Writes [data] to a file at the given [path].
  Future<void> write(
    String path,
    Stream<List<int>> data, {
    bool create = true,
  }) async {
    final parts = _splitPath(path);

    // Build the file UnixFS DAG
    final builder = UnixFSBuilder();
    Block? rootBlock;
    await for (final block in builder.build(data)) {
      await _blockStore.putBlock(block);
      rootBlock = block;
    }

    if (rootBlock == null) throw Exception('Failed to build UnixFS DAG');

    await _modifyPath(parts, (currentCid) async {
      if (currentCid == null && !create) {
        throw Exception('File does not exist and create is false');
      }
      return rootBlock!.cid;
    }, isDirectory: false);
  }

  /// Reads data from a file at the given [path].
  Future<Stream<List<int>>> read(String path) async {
    final parts = _splitPath(path);
    final cid = await _resolvePath(_rootCid!, parts);
    if (cid == null) throw Exception('Path not found: $path');

    final controller = StreamController<List<int>>();

    unawaited(_readRecursive(cid, controller)
        .then((_) => controller.close())
        .catchError((Object e) => controller.addError(e)));

    return controller.stream;
  }

  Future<void> _readRecursive(
    CID cid,
    StreamController<List<int>> controller,
  ) async {
    final block = await _blockStore.getBlock(cid.encode());
    if (!block.found) throw Exception('Block not found');

    final node = PBNode.fromBuffer(block.block.data);
    final unixData = Data.fromBuffer(node.data);

    if (unixData.type == Data_DataType.File ||
        unixData.type == Data_DataType.Raw) {
      if (unixData.hasData()) {
        controller.add(unixData.data);
      }
      for (final link in node.links) {
        await _readRecursive(
          CID.fromBytes(Uint8List.fromList(link.hash)),
          controller,
        );
      }
    } else {
      throw Exception('Not a file');
    }
  }

  List<String> _splitPath(String path) {
    return path.split('/').where((p) => p.isNotEmpty).toList();
  }

  Future<CID?> _resolvePath(CID current, List<String> parts) async {
    if (parts.isEmpty) return current;

    final block = await _blockStore.getBlock(current.encode());
    if (!block.found) return null;

    final node = PBNode.fromBuffer(block.block.data);
    for (final link in node.links) {
      if (link.name == parts[0]) {
        return _resolvePath(
          CID.fromBytes(Uint8List.fromList(link.hash)),
          parts.sublist(1),
        );
      }
    }
    return null;
  }

  /// Modifies a path and updates all parents up to root.
  Future<void> _modifyPath(
    List<String> parts,
    Future<CID?> Function(CID? currentCid) transform, {
    bool recursive = false,
    bool isDirectory = false,
  }) async {
    _rootCid = await _modifyRecursive(
      _rootCid!,
      parts,
      transform,
      recursive,
      isDirectory,
    );
    await _datastore.put(Key(_rootKey), _rootCid!.toBytes());
  }

  Future<CID> _modifyRecursive(
    CID currentCid,
    List<String> parts,
    Future<CID?> Function(CID? currentCid) transform,
    bool recursive,
    bool isDirectory,
  ) async {
    if (parts.isEmpty) {
      final newCid = await transform(currentCid);
      return newCid ?? currentCid;
    }

    final block = await _blockStore.getBlock(currentCid.encode());
    if (!block.found) throw Exception('Block not found');
    final node = PBNode.fromBuffer(block.block.data);

    final name = parts[0];
    PBLink? foundLink;
    for (final link in node.links) {
      if (link.name == name) {
        foundLink = link;
        break;
      }
    }

    CID nextCid;
    if (foundLink == null) {
      if (parts.length > 1 && !recursive) {
        throw Exception('Path not found: $name');
      }

      if (parts.length == 1) {
        final newChildCid = await transform(null);
        if (newChildCid == null) return currentCid;
        nextCid = newChildCid;
      } else {
        // Create intermediate directory
        final dirManager = IPFSDirectoryManager();
        final emptyDirNode = dirManager.build();
        final emptyDirData = emptyDirNode.writeToBuffer();
        final emptyDirCid = await CID.fromContent(
          emptyDirData,
          codec: 'dag-pb',
        );
        await _blockStore.putBlock(
          Block(cid: emptyDirCid, data: emptyDirData, format: 'dag-pb'),
        );

        nextCid = await _modifyRecursive(
          emptyDirCid,
          parts.sublist(1),
          transform,
          recursive,
          isDirectory,
        );
      }
    } else {
      nextCid = await _modifyRecursive(
        CID.fromBytes(Uint8List.fromList(foundLink.hash)),
        parts.sublist(1),
        transform,
        recursive,
        isDirectory,
      );
    }

    // Update current node with new link to nextCid
    final nextBlock = await _blockStore.getBlock(nextCid.encode());
    final nextNode = PBNode.fromBuffer(nextBlock.block.data);

    final newLink = PBLink()
      ..name = name
      ..hash = nextCid.toBytes()
      ..size = Int64(
        nextBlock.block.data.length +
            nextNode.links.fold<int>(0, (sum, l) => sum + l.size.toInt()),
      );

    final newLinks = node.links.where((l) => l.name != name).toList();
    newLinks.add(newLink);
    newLinks.sort((a, b) => a.name.compareTo(b.name));

    node.links.clear();
    node.links.addAll(newLinks);

    final newData = node.writeToBuffer();
    final updatedCid = await CID.fromContent(newData, codec: 'dag-pb');
    await _blockStore.putBlock(
      Block(cid: updatedCid, data: newData, format: 'dag-pb'),
    );

    return updatedCid;
  }
}
