import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dart_ipfs/dart_ipfs.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/config/network_config.dart';

void main() async {
  print('--- Web P2P Chat Example ---');

  // 1. Initialize a browser-native IPFS node
  final config = IPFSConfig(
    network: NetworkConfig(
      enableWebTransport: true,
      enableWebRtc: true,
      // Use public bootstrap peers that might support WebRTC signaling
      bootstrapPeers: [
        '/dnsaddr/bootstrap.libp2p.io/p2p/QmNnooDu7bfjPFoTZYxMNLWUQJyrVwtbZg5gBMjTezGAJN',
      ],
    ),
  );

  final node = IPFSWebNode(config: config);

  print('Starting IPFS Web Node...');
  await node.start();
  print('Node started with ID: ${node.peerId}');

  // 2. Register a custom chat protocol
  const protocolId = '/ipfs-chat/1.0.0';

  node.router.registerProtocolHandler(protocolId, (packet) {
    final message = utf8.decode(packet.datagram);
    print('\n[Received from ${packet.srcPeerId.substring(0, 8)}]: $message');
  });

  print('\nListening for chat messages on $protocolId');
  print('Available Peers: ${node.router.listConnectedPeers().length}');

  // 3. Simple CLI loop (simulated)
  Timer.periodic(Duration(seconds: 5), (timer) {
    final peers = node.router.listConnectedPeers();
    if (peers.isNotEmpty) {
      print('\nConnected to ${peers.length} peers.');
      for (var peer in peers) {
        print(' - ${peer.substring(0, 16)}...');
      }
    } else {
      print('Waiting for peers...');
    }
  });

  // To send a message (usage):
  // await node.router.sendMessage(remotePeerId, utf8.encode('Hello!'), protocolId: protocolId);
}
