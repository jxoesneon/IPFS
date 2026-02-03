import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart';
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart';
import 'package:fixnum/fixnum.dart';

// lib/src/core/data_structures/directory.dart

/// Represents a single entry within an IPFS directory for construction purposes.
///
/// **UnixFS v1.5:** Supports optional `mode` (Unix permissions) and `mtime`
/// (modification time) for file system preservation.
class IPFSDirectoryEntry {
  /// Creates a new [IPFSDirectoryEntry].
  IPFSDirectoryEntry({
    required this.name,
    required this.hash,
    required this.size,
    required this.isDirectory,
    this.mode,
    this.mtime,
  });

  /// The name of this entry (file or subdirectory name).
  final String name;

  /// The CID hash bytes of the linked content.
  final List<int> hash;

  /// The cumulative size of the linked content in bytes.
  final Int64 size;

  /// Whether this entry is a directory (true) or file (false).
  final bool isDirectory;

  /// Unix file mode/permissions (e.g., 0o755 for directories, 0o644 for files).
  /// Optional - when null, no mode is stored.
  final int? mode;

  /// Modification time of the file/directory.
  /// Optional - when null, no mtime is stored.
  final DateTime? mtime;

  /// Converts this entry to a PBLink for inclusion in a MerkleDAG node.
  ///
  /// Note: mode and mtime are stored in the UnixFS Data of the linked node,
  /// not in the PBLink itself.
  PBLink toLink() {
    return PBLink()
      ..name = name
      ..hash = hash
      ..size = size; // Tsize: cumulative size
  }
}

/// Manages IPFS directory creation using standard UnixFS Data and DAG nodes
class IPFSDirectoryManager {
  /// Creates a new [IPFSDirectoryManager] with optional [mode] and [mtime].
  IPFSDirectoryManager({int? mode, DateTime? mtime})
    : _unixFsData = Data()..type = Data_DataType.Directory {
    if (mode != null) {
      _unixFsData.mode = mode;
    }
    if (mtime != null) {
      _unixFsData.mtime = Int64(mtime.millisecondsSinceEpoch ~/ 1000);
    }
  }
  final Data _unixFsData;
  final List<IPFSDirectoryEntry> _entries = [];

  /// Adds an entry to the directory.
  /// Note: Entries should ideally be added in sorted order by name for canonicalization,
  /// but basic IPFS implementations often sort them at serialization time.
  void addEntry(IPFSDirectoryEntry entry) {
    _entries.add(entry);
  }

  /// Sets the modification time of the directory.
  void setModificationTime(DateTime mtime) {
    _unixFsData.mtime = Int64(mtime.millisecondsSinceEpoch ~/ 1000);
  }

  /// Sets the mode (permissions) of the directory.
  void setMode(int mode) {
    _unixFsData.mode = mode;
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

