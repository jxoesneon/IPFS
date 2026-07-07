// ignore_for_file: avoid_print
import 'dart:typed_data';
import 'package:dart_ipfs/dart_ipfs.dart';

/// Template: Minimal Web Node
///
/// A bare-bones node designed for browser environments.
/// Uses IndexedDB for storage and relies on relay peers for networking.
void main() async {
  // Initialize the Web-specific node implementation
  final node = IPFSWebNode(
    bootstrapPeers: [
      // Recommended: Add your own secure WebSocket relays
      '/dns4/node0.delegate.ipfs.io/tcp/443/wss/p2p/QmAt9H7ZUnm9Gv4SDXG3d2FfSbfSAdSNoSUnxyCyc16782',
    ],
  );

  print('Starting IPFS Web Node...');
  await node.start();
  print('Node started. Peer ID: ${node.peerID}');

  // Example: Add a simple string to IPFS
  final data = Uint8List.fromList('Hello from the browser!'.codeUnits);
  final cid = await node.add(data);
  print('Content added. CID: $cid');

  // Example: Retrieve it back
  final retrieved = await node.get(cid.encode());
  if (retrieved != null) {
    print('Retrieved data: ${String.fromCharCodes(retrieved)}');
  }

  // Graceful shutdown (optional for long-running apps)
  // await node.stop();
}
