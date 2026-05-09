// ignore_for_file: avoid_print
import 'package:dart_ipfs/dart_ipfs.dart';

/// Template: Full P2P Node
///
/// A standard IPFS node with all major protocols enabled.
/// Best for participating in the global IPFS network or building P2P apps.
void main() async {
  // 1. Configure the full network stack
  final config = IPFSConfig(
    dataPath: './ipfs_data',
    offline: false,
    enableDHT: true, // Peer and content routing
    enablePubSub: true, // Real-time messaging
    network: NetworkConfig(
      bootstrapPeers: [
        // Standard libp2p bootstrap nodes
        '/dnsaddr/bootstrap.libp2p.io/p2p/QmNnooDu7bfjPFoTZYxMNLWUQJyrVwtbZg5gBMjTezGAJN',
        '/dnsaddr/bootstrap.libp2p.io/p2p/QmQCU2EcMqwsS96B7L3B5Q17CBB5X6UvY9QzZ3Sjy1n8B',
      ],
    ),
  );

  // 2. Create the node
  final node = await IPFSNode.create(config);

  // 3. Optional: Subscribe to a PubSub topic for real-time data
  await node.subscribe('network-updates');

  node.pubsubMessages.listen((message) {
    if (message.topic == 'network-updates') {
      print('Received P2P message: ${message.content}');
    }
  });

  // 4. Start the node
  await node.start();
  print('Full P2P Node started.');
  print('Peer ID: ${node.peerID}');

  // Example: Find providers for a known CID
  const targetCid = 'QmYwAPJzv5CZsnA6ULBXebJWvruP6P3wXhHjS2Mtc38E2z';
  print('Searching for providers of $targetCid...');

  final providers = await node.findProviders(targetCid);
  for (final peer in providers) {
    print('Found provider: $peer');
  }
}
