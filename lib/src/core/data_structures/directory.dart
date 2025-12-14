import 'package:fixnum/fixnum.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart';
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart';

// lib/src/core/data_structures/directory.dart

/// Represents a single entry within an IPFS directory for construction purposes
class IPFSDirectoryEntry {
  final String name;
  final List<int> hash;
  final Int64 size;
  final bool isDirectory;

  IPFSDirectoryEntry({
    required this.name,
    required this.hash,
    required this.size,
    required this.isDirectory,
  });

  /// Converts this entry to a PBLink for inclusion in a MerkleDAG node
  PBLink toLink() {
    return PBLink()
      ..name = name
      ..hash = hash
      ..size = size; // Tsize: cumulative size
  }
}

/// Manages IPFS directory creation using standard UnixFS Data and DAG nodes
class IPFSDirectoryManager {
  final Data _unixFsData;
  final List<IPFSDirectoryEntry> _entries = [];

  IPFSDirectoryManager() 
      : _unixFsData = Data()..type = Data_DataType.Directory;

  /// Adds an entry to the directory.
  /// Note: Entries should ideally be added in sorted order by name for canonicalization,
  /// but basic IPFS implementations often sort them at serialization time.
  void addEntry(IPFSDirectoryEntry entry) {
    _entries.add(entry);
  }

  /// Builds the MerkleDAG node (PBNode) representing this directory.
  PBNode build() {
    // 1. Prepare UnixFS Data
    // For a basic directory, data is minimal (Type=Directory).
    // Filesize/Blocksizes usually apply to files or hamt shards.
    
    // 2. Create PBNode
    final node = PBNode();
    
    // 3. Set Data (serialized UnixFS Data)
    node.data = _unixFsData.writeToBuffer();
    
    // 4. Add Links
    // IPFS requires links to be sorted by name for deterministic DAG generation.
    _entries.sort((a, b) => a.name.compareTo(b.name));
    
    for (final entry in _entries) {
      node.links.add(entry.toLink());
    }
    
    return node;
  }
}
