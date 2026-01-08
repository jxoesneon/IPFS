// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:dart_ipfs/dart_ipfs.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart client_node.dart <server_multiaddr>');
    exit(1);
  }

  final serverMultiaddr = args[0];
  print('=== Client Node (v1.8.0) ===');

  final config = IPFSConfig(
    offline: false,
    debug: true,
    network: NetworkConfig(listenAddresses: ['/ip4/127.0.0.1/udp/4006']),
  );

  final node = await IPFSNode.create(config);
  await node.start();
  print('Client Peer ID: ${node.peerID}');

  const protocolId = '/test/dialback';

  try {
    print('Client: Connecting to server at $serverMultiaddr...');
    await node.connectToPeer(serverMultiaddr);
    print('Client: Connected!');

    print('Client: Sending request...');
    final response = await node.container.get<NetworkHandler>().sendRequest(
      _extractPeerId(serverMultiaddr),
      protocolId,
      utf8.encode('HelloFromClient'),
    );

    final result = utf8.decode(response);
    print('Client: Received response: $result');

    print('Client: Entering sustainability phase (120s)...');
    for (int i = 0; i < 12; i++) {
      await Future<void>.delayed(const Duration(seconds: 10));
      print('Client: Sending checkin ${i + 1}/12...');
      final checkin = await node.container.get<NetworkHandler>().sendRequest(
        _extractPeerId(serverMultiaddr),
        protocolId,
        utf8.encode('Checkin-$i'),
      );
      print('Client: Received checkin response: ${utf8.decode(checkin)}');
    }
    print('✅ SUCCESS: Stability test complete!');
  } catch (e) {
    print('❌ FAILURE: Error: $e');
  } finally {
    await node.stop();
    print('Client stopped.');
    exit(0);
  }
}

String _extractPeerId(String multiaddr) {
  final parts = multiaddr.split('/');
  return parts.last;
}
