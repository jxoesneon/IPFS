// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/dart_ipfs.dart';

Future<void> main() async {
  // 1. Initialize the IPFS Node
  // In a real app, you might configure specific peers or storage paths.
  final node = await IPFSNode.create(IPFSConfig(offline: true));

  print('Starting IPFS Node...');
  await node.start();
  print('Node started with Peer ID: ${node.peerID}');

  try {
    // 2. Add Content
    final text = 'Hello IPFS from Dart!';
    final data = Uint8List.fromList(utf8.encode(text));

    print('Adding content: "$text"');
    final cid = await node.addFile(data); // Returns String
    print('Content added with CID: $cid');

    // 3. Retrieve Content
    print('Retrieving content...');
    final retrievedData = await node.get(cid);

    if (retrievedData != null) {
      final retrievedText = utf8.decode(retrievedData);
      print('Retrieved content: "$retrievedText"');
    } else {
      print('Failed to retrieve content');
    }

    // 4. Pinning (Persistence)
    print('Pinning CID...');
    await node.pin(cid);
    print('CID pinned successfully');

    final pins = await node.pinnedCids;
    print('Current pins: $pins');
  } catch (e) {
    print('Error: $e');
  } finally {
    // 5. Stop the Node
    await node.stop();
    print('Node stopped');
  }
}
