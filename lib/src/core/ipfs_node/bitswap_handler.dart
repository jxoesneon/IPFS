// lib/src/core/ipfs_node/bitswap_handler.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:convert/convert.dart'; // For encoding utilities
import 'package:crypto/crypto.dart'; // For hashing utilities
import '/../src/proto/dht/cid.pb.dart';

import '../data_structures/block.dart';
import '../data_structures/cid.dart';
import '../data_structures/link.dart';
import '../data_structures/node.dart';
import '/../src/protocols/bitswap/bitswap.dart';
import '/../src/protocols/bitswap/ledger.dart';
import '/../src/transport/p2plib_router.dart';
import '/../src/storage/datastore.dart';
import '/../src/core/data_structures/node_type.dart';

/// Handles Bitswap protocol operations for an IPFS node.
class BitswapHandler {
  late final Bitswap _bitswap;
  final BitLedger _ledger;
  final P2plibRouter _router;
  final Datastore _datastore;

  BitswapHandler(config)
      : _ledger = BitLedger(config),
        _datastore = Datastore(config.datastorePath),
        _router = P2plibRouter(config) {
    // Initialize _bitswap in the constructor body
    _bitswap = Bitswap(
      _router.routerL0, // Access the RouterL0 instance through the getter
      _ledger,
      _datastore,
      config.nodeId, // Provide the _nodeId value
      config, // Pass the config object
    );
  }

  /// Starts the Bitswap protocol.
  Future<void> start() async {
    try {
      await _bitswap.start();
      print('Bitswap protocol started.');
    } catch (e) {
      print('Error starting Bitswap protocol: $e');
    }
  }

  /// Stops the Bitswap protocol.
  Future<void> stop() async {
    try {
      await _bitswap.stop();
      print('Bitswap protocol stopped.');
    } catch (e) {
      print('Error stopping Bitswap protocol: $e');
    }
  }

  /// Requests a block from the network using Bitswap.
  Future<Block?> requestBlock(String cid) async {
    try {
      final block = await _bitswap.wantBlock(cid);
      if (block != null) {
        print('Successfully requested block with CID: $cid');
      } else {
        print('Block with CID $cid not found in network.');
      }
      return block;
    } catch (e) {
      print('Error requesting block with CID $cid: $e');
      return null;
    }
  }

  /// Provides a block to the network using Bitswap.
  void provideBlock(Block block) {
    try {
      _bitswap.provide(block.cid.encode()); // Use cid.encode()
      print('Provided block with CID: ${block.cid}');
    } catch (e) {
      print('Error providing block with CID ${block.cid}: $e');
    }
  }

  /// Checks if a block is available locally or needs to be fetched from the network.
  Future<Block?> getBlock(String cid) async {
    try {
      // Check if the block is available locally
      final localBlock = await _datastore.get(cid);
      if (localBlock != null) {
        print('Retrieved local block with CID: $cid');
        return localBlock;
      }

      // If not available locally, request it from the network
      return await requestBlock(cid);
    } catch (e) {
      print('Error getting block with CID $cid: $e');
      return null;
    }
  }

  /// Calculates the CID for given data using multihash.
  Future<String> calculateCID(Uint8List data) async {
    final hash = sha256.convert(data); // Using SHA-256 for hashing
    final digest = hash.bytes;
    return hex.encode(digest); // Convert hash to hexadecimal string as CID
  }

  /// Adds a file to IPFS and returns its CID.
  Future<String> addFile(Uint8List data) async {
    // Create an IPFS Node object to represent the file
    final fileNode = Node(
      data: data,
      links: [],
      size: data.length,
      timestamp: DateTime.now().millisecondsSinceEpoch, // Set current timestamp
      metadata: {}, // Initialize with an empty map or provide actual metadata
      cid: CID.fromContent(
        'raw', // or a more specific codec if you know it
        version: CIDVersion.CID_VERSION_1,
        hashType: 'sha2-256',
        content: data,
      ),
      type: NodeType.REGULAR,
    );

    // Create a Block with the file data
    final block = Block(fileNode.toBytes(), fileNode.cid);

    // Calculate the CID of the block
    final cid = await calculateCID(block.data);

    // Store the block in the datastore
    await _datastore.put(cid, block);

    // Announce availability of the block to the network
    provideBlock(block);

    return cid;
  }

  Future<String> addDirectory(Map<String, dynamic> directoryContent) async {
    final links = <Link>[];

    for (var entry in directoryContent.entries) {
      final name = entry.key;
      final content = entry.value;

      if (content is Uint8List) {
        // File content
        final fileCid = await addFile(content) as Uint8List;
        links.add(Link(name: name, cid: fileCid, size: content.length));
      } else if (content is Map<String, dynamic>) {
        // Subdirectory content
        final subdirCid = await addDirectory(content) as Uint8List;
        int dirSize = await calculateDirectorySize(content);
        links.add(Link(name: name, cid: subdirCid, size: dirSize));
      } else {
        throw ArgumentError('Invalid directory content type for entry $name');
      }
    }

    // Create an IPFS Node object to represent the directory
    final directoryNode = Node(
      timestamp: DateTime.now().millisecondsSinceEpoch,
      metadata: {},
      cid: CID.fromContent(
        'raw', // or a more specific codec if you know it
        version: CIDVersion.CID_VERSION_1,
        hashType: 'sha2-256',
        content: Uint8List(0), // provide with content for cid calculation
      ),
      size: await calculateDirectorySize(directoryContent),
      type: NodeType.REGULAR,
      data: Uint8List(0), // Directories don't have direct data
      links: links,
    );

    // Convert directoryNode to bytes using toBytes method and then encode it using utf8
    final directoryNodeBytes = utf8.encode(directoryNode.toBytes() as String);

    // Create a Block with the directory node data
    final block = Block(directoryNodeBytes, directoryNode.cid);

    // Calculate the CID of the block
    final cid = await calculateCID(directoryNodeBytes);

    // Store the block in the datastore
    await _datastore.put(cid, block);

    // Announce availability of the block to the network
    provideBlock(block);

    return cid;
  }

  /// Helper function to calculate total size of a directory recursively.
  Future<int> calculateDirectorySize(
      Map<String, dynamic> directoryContent) async {
    var totalSize = 0;

    for (var entry in directoryContent.entries) {
      if (entry.value is Uint8List) {
        totalSize += (entry.value as Uint8List).length;
      } else if (entry.value is Map<String, dynamic>) {
        totalSize += await calculateDirectorySize(entry.value);
      }
    }

    return totalSize;
  }
}
