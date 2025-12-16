// ignore_for_file: avoid_print
// ipfs/example/main.dart

import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/dart_ipfs.dart';

void main() async {
  final config = IPFSConfig(
    debug: true,
    verboseLogging: true,
    // ... other config options ...
  );

  print('Creating IPFS node with debug logging enabled...');
  final ipfs = await IPFS.create(config: config);

  print('Starting IPFS node...');
  await ipfs.start();

  // 1. Add a file
  // Convert a string to bytes and add it to IPFS, receiving a CID (Content Identifier)
  final cid = await ipfs.addFile(
    Uint8List.fromList(utf8.encode('Hello IPFS!')),
  );
  print('Added file with CID: $cid');

  // 2. Retrieve the file content
  // Use the CID to get back the data that was added earlier
  final data = await ipfs.get(cid);
  print('File content: ${utf8.decode(data!)}');

  // 3. Pin the file
  // Ensure that the file is not removed during garbage collection
  await ipfs.pin(cid);
  print('Pinned CID: $cid');

  // --- Bitswap interaction ---
  // Interactions for sharing and retrieving blocks within the IPFS network

  // 4. Find providers for the CID
  // Identify peers who have a copy of the content with the specified CID
  final providers = await ipfs.findProviders(cid);
  print('Providers for CID $cid: $providers');

  // 5. Request the block from a provider (if any)
  // Attempt to retrieve a block from one of the known providers
  if (providers.isNotEmpty) {
    final providerPeerId =
        providers.first; // Select the first available provider
    try {
      await ipfs.requestBlock(cid, providerPeerId);
      print('Requested block $cid from peer $providerPeerId');
    } catch (e) {
      print('Error requesting block: $e');
    }
  }

  // 6. Retrieve a file from the directory
  // Access a specific file from a given directory CID
  final directoryContent = {
    'myFolder/file1.txt': Uint8List.fromList(utf8.encode('Content of file1')),
    'myFolder/file2.txt': Uint8List.fromList(utf8.encode('Content of file2')),
  };
  final dirCid = await ipfs.addDirectory(directoryContent);
  print('Added directory with CID: $dirCid');

  // Now, retrieve file2.txt using the dirCid
  final file2Data = await ipfs.get(dirCid, path: 'myFolder/file2.txt');
  if (file2Data != null) {
    print('Retrieved file2.txt content: ${utf8.decode(file2Data)}');
  } else {
    print('Failed to retrieve file2.txt content.');
  }

  // 7. Resolve an IPNS name
  // Convert an IPNS name to its current CID mapping
  try {
    final resolvedCid = await ipfs.resolveIPNS(
      'your-ipns-name',
    ); // Replace with an actual IPNS name
    print('Resolved IPNS name to CID: $resolvedCid');
  } catch (e) {
    print('Failed to resolve IPNS name: $e');
  }

  // 8. Publish an IPNS record (if you have implemented key management)
  // Update an IPNS name to point to a new CID
  try {
    await ipfs.publishIPNS(cid, keyName: 'my-key');
    print('Published IPNS record for CID: $cid');
  } catch (e) {
    print('Failed to publish IPNS record: $e');
  }

  // 9. Subscribe to a PubSub topic
  // Join a PubSub topic to receive and send messages across the network
  try {
    await ipfs.subscribe('some_topic');
    print('Subscribed to topic: some_topic');

    // Listen for incoming messages on the subscribed topic
    ipfs.onNewContent.listen((cid) {
      print('Received new content notification: $cid');
    });
  } catch (e) {
    print('Failed to subscribe to topic: $e');
  }

  // 10. Get node stats
  // Retrieve statistics about the node's performance and usage
  final stats = await ipfs.stats();
  print('Node stats: $stats');

  // 11. Stop the node
  // Gracefully shut down the IPFS node
  await ipfs.stop();
}
