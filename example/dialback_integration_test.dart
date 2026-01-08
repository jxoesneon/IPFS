// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:dart_ipfs/dart_ipfs.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/transport/p2plib_router.dart';

void main() async {
  print('=== Dialback Integration Test ===');

  final serverConfig = IPFSConfig(
    offline: false,
    debug: true,
    network: NetworkConfig(listenAddresses: ['/ip4/127.0.0.1/udp/4007']),
  );

  final clientConfig = IPFSConfig(
    offline: false,
    debug: true,
    network: NetworkConfig(listenAddresses: ['/ip4/127.0.0.1/udp/4008']),
  );

  final server = await IPFSNode.create(serverConfig);
  final client = await IPFSNode.create(clientConfig);

  await server.start();
  await client.start();

  print('Server: ${server.peerID}');
  print('Client: ${client.peerID}');

  const protocolId = '/test/dialback';

  // Register protocol handler on the server's router
  final serverRouter = server.container.get<NetworkHandler>().p2pRouter;
  serverRouter.registerProtocolHandler(protocolId, (NetworkPacket packet) {
    final body = utf8.decode(packet.datagram);
    print('Server: Received message from ${packet.srcPeerId}: $body');
  });

  try {
    final serverAddr = '/ip4/127.0.0.1/udp/4007/p2p/${server.peerID}';
    print('Client: Connecting to $serverAddr...');
    await client.connectToPeer(serverAddr);

    print('Client: Sending request...');
    final response = await client.container.get<NetworkHandler>().sendRequest(
      server.peerID,
      protocolId,
      utf8.encode('Hello'),
    );

    print('Client: Received: ${utf8.decode(response)}');

    if (response.isNotEmpty) {
      print('✅ SUCCESS: Dialback test passed!');
    } else {
      print('❌ FAILURE: Empty response');
    }
  } catch (e) {
    print('❌ FAILURE: Error: $e');
  } finally {
    await server.stop();
    await client.stop();
    print('Test complete.');
  }
}
