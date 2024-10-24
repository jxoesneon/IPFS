import 'package:fixnum/fixnum.dart';
import 'package:protobuf/protobuf.dart';
import '/../src/proto/dht/directory.pb.dart'; // Import the generated protobuf file for directory
import 'dart:typed_data';

class DirectoryHandler {
  Directory _directory;

  DirectoryHandler(String path) {
    // Initialize an empty directory with the given path
    _directory = Directory()
      ..path = path
      ..totalSize = Int64(0)
      ..numberOfFiles = 0
      ..numberOfDirectories = 0;
  }

  // Add a new directory entry (file or subdirectory)
  bool addEntry(DirectoryEntry entry) {
    // Check if the entry already exists
    var existingEntry = _directory.entries
        .firstWhere((e) => e.name == entry.name, orElse: () => null);

    if (existingEntry != null) {
      return false; // Entry already exists
    }

    // Add the entry to the directory
    _directory.entries.add(entry);

    // Update the directory statistics
    _directory.totalSize += entry.size;
    if (entry.isDirectory) {
      _directory.numberOfDirectories += 1;
    } else {
      _directory.numberOfFiles += 1;
    }

    return true;
  }

  // Remove a directory entry (file or subdirectory) by name
  bool removeEntry(String name) {
    var entryIndex = _directory.entries.indexWhere((e) => e.name == name);

    if (entryIndex == -1) {
      return false; // Entry not found
    }

    var entry = _directory.entries[entryIndex];

    // Update the directory statistics
    _directory.totalSize -= entry.size;
    if (entry.isDirectory) {
      _directory.numberOfDirectories -= 1;
    } else {
      _directory.numberOfFiles -= 1;
    }

    // Remove the entry from the directory
    _directory.entries.removeAt(entryIndex);

    return true;
  }

  // List all directory entries
  List<DirectoryEntry> listEntries() {
    return _directory.entries;
  }

  // Get a directory entry by name
  DirectoryEntry getEntry(String name) {
    return _directory.entries
        .firstWhere((e) => e.name == name, orElse: () => null);
  }

  // Get the total size of the directory
  Int64 getTotalSize() {
    return _directory.totalSize;
  }

  // Get the number of files in the directory
  int getNumberOfFiles() {
    return _directory.numberOfFiles;
  }

  // Get the number of subdirectories in the directory
  int getNumberOfDirectories() {
    return _directory.numberOfDirectories;
  }

  // Serialize the directory into bytes (for storage or transfer)
  Uint8List serialize() {
    return _directory.writeToBuffer();
  }

  // Deserialize bytes into a directory
  void deserialize(Uint8List data) {
    _directory = Directory.fromBuffer(data);
  }
}
