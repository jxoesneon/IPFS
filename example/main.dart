// ipfs/example/main.dart

import 'dart:convert';
import 'dart:typed_data';

import 'package:ipfs/IPFS.dart';

void main() async {
  // 1. Create an IPFS node
  // Initialize the node with optional configuration settings
  final node = await IPFS.create();

  // 2. Start the IPFS node
  // This begins the process of connecting to the IPFS network
  await node.start();
  print('IPFS node started with Peer ID: ${node.peerID}');

  // 3. Add a file
  // Convert a string to bytes and add it to IPFS, receiving a CID (Content Identifier)
  final cid =
      await node.addFile(Uint8List.fromList(utf8.encode('Hello IPFS!')));
  print('Added file with CID: $cid');

  // 4. Retrieve the file content
  // Use the CID to get back the data that was added earlier
  final data = await node.get(cid);
  print('File content: ${utf8.decode(data!)}');

  // 5. Pin the file
  // Ensure that the file is not removed during garbage collection
  await node.pin(cid);
  print('Pinned CID: $cid');

  // --- Bitswap interaction ---
  // Interactions for sharing and retrieving blocks within the IPFS network

  // 6. Find providers for the CID
  // Identify peers who have a copy of the content with the specified CID
  final providers = await node.findProviders(cid);
  print('Providers for CID $cid: $providers');

  // 7. Request the block from a provider (if any)
  // Attempt to retrieve a block from one of the known providers
  if (providers.isNotEmpty) {
    final providerPeerId =
        providers.first; // Select the first available provider
    try {
      await node.requestBlock(cid, providerPeerId);
      print('Requested block $cid from peer $providerPeerId');
    } catch (e) {
      print('Error requesting block: $e');
    }
  }

  // 8. Retrieve a file from the directory
  // Access a specific file from a given directory CID
  final directoryContent = {
    'myFolder/file1.txt': Uint8List.fromList(utf8.encode('Content of file1')),
    'myFolder/file2.txt': Uint8List.fromList(utf8.encode('Content of file2')),
  };
  final dirCid = await node.addDirectory(directoryContent);
  print('Added directory with CID: $dirCid');

  // Now, retrieve file2.txt using the dirCid
  final file2Data = await node.get(dirCid, path: 'myFolder/file2.txt');
  if (file2Data != null) {
    print('Retrieved file2.txt content: ${utf8.decode(file2Data)}');
  } else {
    print('Failed to retrieve file2.txt content.');
  }


  // 9. Resolve an IPNS name
  // Convert an IPNS name to its current CID mapping
  try {
    final resolvedCid = await node
        .resolveIPNS('your-ipns-name'); // Replace with an actual IPNS name
    print('Resolved IPNS name to CID: $resolvedCid');
  } catch (e) {
    print('Failed to resolve IPNS name: $e');
  }

  // 10. Publish an IPNS record (if you have implemented key management)
  // Update an IPNS name to point to a new CID
  try {
    await node.publishIPNS(cid, keyName: 'my-key');
    print('Published IPNS record for CID: $cid');
  } catch (e) {
    print('Failed to publish IPNS record: $e');
  }

  // 11. Subscribe to a PubSub topic
  // Join a PubSub topic to receive and send messages across the network
  try {
    await node.subscribe('some_topic');
    print('Subscribed to topic: some_topic');

    // Listen for incoming messages on the subscribed topic
    node.onNewContent.listen((cid) {
      print('Received new content notification: $cid');
    });
  } catch (e) {
    print('Failed to subscribe to topic: $e');
  }

  // 12. Get node stats
  // Retrieve statistics about the node's performance and usage
  final stats = await node.stats();
  print('Node stats: $stats');

  // 13. Stop the node
  // Gracefully shut down the IPFS node
  await node.stop();
}
