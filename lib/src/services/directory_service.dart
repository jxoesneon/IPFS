// src/services/directory_service.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/directory.dart';
import 'package:dart_ipfs/src/core/ipfs_node/datastore_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/proto/generated/core/cid.pb.dart';
import 'package:dart_ipfs/src/proto/generated/dht/directory.pb.dart';
import 'package:fixnum/fixnum.dart';
import 'package:dart_ipfs/src/utils/crypto.dart';
import 'package:dart_ipfs/src/utils/encoding.dart';
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';

/// Service for managing IPFS directory operations
class IPFSDirectoryService {
  final IPFSDirectoryManager _directoryManager;
  final CryptoUtils _cryptoUtils = CryptoUtils();

  IPFSDirectoryService(String rootPath)
      : _directoryManager = IPFSDirectoryManager(rootPath);

  /// Creates a new directory at the specified path
  Future<IPFSNode> createDirectory(String path) async {
    // Create UnixFS directory node with proper type and metadata
    final unixFsData = Data()
      ..type = Data_DataType.Directory
      ..mode = 0x1ed // 0755 in octal
      ..mtime = Int64(DateTime.now().millisecondsSinceEpoch ~/ 1000)
      ..mtimeNsecs = 0
      ..filesize = Int64(0);

    // Clear existing blocksizes and add new ones if needed
    unixFsData.blocksizes.clear();

    // Create DAG-PB node with UnixFS data
    final node = PBNode();
    node.data = unixFsData.writeToBuffer();
    node.links.clear(); // Clear any existing links

    // Generate CIDv1 with dag-pb codec
    final nodeBytes = node.writeToBuffer();
    final multihash = await _cryptoUtils.sha256(nodeBytes);
    final cid = CID(
      version: IPFSCIDVersion.IPFS_CID_VERSION_1,
      multihash: multihash,
      codec: 'dag-pb',
      multibasePrefix: 'base58btc',
    );

    // Create IPFS node and store the data
    final ipfsNode = await IPFSNode.create(IPFSConfig());
    final block = await Block.fromData(nodeBytes, format: 'dag-pb');
    await ipfsNode.container.get<DatastoreHandler>().putBlock(block);

    // Add to directory manager with proper UnixFS metadata
    _directoryManager.addEntry(IPFSDirectoryEntry(
      name: path.split('/').last,
      hash: EncodingUtils.cidToBytes(cid),
      size: Int64(0),
      isDirectory: true,
    ));

    return ipfsNode;
  }

  /// Adds a file entry to the current directory
  Future<void> addFileEntry(String name, Uint8List hash, int size) async {
    _directoryManager.addEntry(IPFSDirectoryEntry(
      name: name,
      hash: hash,
      size: Int64(size),
      isDirectory: false,
    ));
  }

  /// Removes an entry from the current directory
  Future<bool> removeEntry(String name) async {
    try {
      final request = RemoveDirectoryEntryRequest()..name = name;
      final response = await _removeDirectoryEntry(request);
      return response.success;
    } catch (e) {
      print('Error removing directory entry: $e');
      return false;
    }
  }

  /// Lists all entries in the current directory
  Future<List<DirectoryEntryProto>> listEntries() async {
    try {
      final request = ListDirectoryRequest()
        ..path = _directoryManager.directory.path;
      final response = await _listDirectory(request);
      return response.entries;
    } catch (e) {
      print('Error listing directory entries: $e');
      return [];
    }
  }

  /// Gets a specific entry from the directory
  Future<DirectoryEntryProto?> getEntry(String name) async {
    try {
      final request = GetDirectoryEntryRequest()..name = name;
      final response = await _getDirectoryEntry(request);
      return response.hasEntry() ? response.entry : null;
    } catch (e) {
      print('Error getting directory entry: $e');
      return null;
    }
  }

  /// Gets the current directory's metadata
  DirectoryProto get directory => _directoryManager.directory;

  /// Internal method to handle directory entry removal
  Future<RemoveDirectoryEntryResponse> _removeDirectoryEntry(
      RemoveDirectoryEntryRequest request) async {
    final entries = _directoryManager.directory.entries;
    final index = entries.indexWhere((entry) => entry.name == request.name);

    if (index != -1) {
      entries.removeAt(index);
      return RemoveDirectoryEntryResponse()..success = true;
    }

    return RemoveDirectoryEntryResponse()..success = false;
  }

  /// Internal method to handle directory listing
  Future<ListDirectoryResponse> _listDirectory(
      ListDirectoryRequest request) async {
    return ListDirectoryResponse()
      ..entries.addAll(_directoryManager.directory.entries);
  }

  /// Internal method to handle getting a directory entry
  Future<GetDirectoryEntryResponse> _getDirectoryEntry(
      GetDirectoryEntryRequest request) async {
    final entry = _directoryManager.directory.entries.firstWhere(
        (e) => e.name == request.name,
        orElse: () => DirectoryEntryProto());

    return GetDirectoryEntryResponse()..entry = entry;
  }
}
