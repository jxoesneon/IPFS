// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:dart_ipfs/dart_ipfs.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/transport/p2plib_router.dart';

void main() async {
  print('=== Server Node (v1.8.0) ===');

  final config = IPFSConfig(
    offline: false,
    debug: true,
    network: NetworkConfig(listenAddresses: ['/ip4/0.0.0.0/udp/4005']),
  );

  final node = await IPFSNode.create(config);
  await node.start();
  print('Server Peer ID: ${node.peerID}');

  const protocolId = '/test/dialback';

  // Register protocol handler on the server's router
  final router = node.container.get<NetworkHandler>().p2pRouter;
  router.registerProtocolHandler(protocolId, (NetworkPacket packet) {
    final body = utf8.decode(packet.datagram);
    print('Server: Received request from ${packet.srcPeerId}: $body');
  });

  print('Server: Listening on /ip4/127.0.0.1/udp/4005');
  print(
    'Server: Use this multiaddr for client: /ip4/127.0.0.1/udp/4005/p2p/${node.peerID}',
  );

  print('Server: Running... (Press Ctrl+C to stop)');
  while (true) {
    await Future<void>.delayed(const Duration(seconds: 5));
  }
}
