// lib/src/core/data_structures/directory.dart
import 'package:fixnum/fixnum.dart';
import '../../proto/generated/dht/directory.pb.dart';

/// Represents a single entry within an IPFS directory
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

  DirectoryEntryProto toProto() {
    return DirectoryEntryProto()
      ..name = name
      ..hash = hash
      ..size = size
      ..isDirectory = isDirectory;
  }
}

/// Manages IPFS directory operations and metadata
class IPFSDirectoryManager {
  DirectoryProto _directory = DirectoryProto();

  IPFSDirectoryManager(String path) {
    _directory
      ..path = path
      ..totalSize = Int64(0)
      ..numberOfFiles = 0
      ..numberOfDirectories = 0;
  }

  void addEntry(IPFSDirectoryEntry entry) {
    _directory.entries.add(entry.toProto());
    // ... rest of the method
  }
}
