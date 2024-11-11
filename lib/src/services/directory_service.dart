import 'dart:async';
import 'dart:typed_data';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/config.dart';
import 'package:dart_ipfs/src/core/data_structures/directory.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/proto/generated/dht/directory.pb.dart';
import 'package:fixnum/fixnum.dart';
import 'package:dart_ipfs/src/utils/crypto.dart';
import 'package:dart_ipfs/src/proto/generated/core/node_type.pbenum.dart';
import 'package:dart_ipfs/src/utils/encoding.dart';

/// Service for managing IPFS directory operations
class IPFSDirectoryService {
  final IPFSDirectoryManager _directoryManager;
  final CryptoUtils _cryptoUtils = CryptoUtils();

  IPFSDirectoryService(String rootPath)
      : _directoryManager = IPFSDirectoryManager(rootPath);

  /// Creates a new directory at the specified path
  Future<IPFSNode> createDirectory(String path) async {
    // Create a new directory node
    final node = IPFSNode(IPFSConfig());
    node.nodeType = NodeTypeProto.NODE_TYPE_DIRECTORY;

    // Generate and set the CID
    node.cid = await _generateCID(path);
    node.links = [];

    // Add to directory manager
    _directoryManager.addEntry(IPFSDirectoryEntry(
      name: path.split('/').last,
      hash: EncodingUtils.cidToBytes(node.cid),
      size: Int64(0),
      isDirectory: true,
    ));

    return node;
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

  /// Generates a CID for a directory path
  Future<CID> _generateCID(String path) async {
    final bytes = Uint8List.fromList(path.codeUnits);
    final hash = await _cryptoUtils.hashData(bytes);
    return CID.fromBytes(hash, 'dag-pb');
  }

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
