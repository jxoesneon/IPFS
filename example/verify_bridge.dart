import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:dart_ipfs/dart_ipfs.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/utils/base58.dart';
import 'package:p2plib/p2plib.dart' as p2p;

void main() async {
  print('--- Libp2p Bridge Verification ---');

  // 1. Configure Node A (Sender)
  final configA = IPFSConfig(
    offline: false,
    enableLibp2pBridge: true,
    libp2pListenAddress: '/ip4/0.0.0.0/tcp/4001',
    datastorePath: './test_repo_a/data',
    network: NetworkConfig(listenAddresses: ['/ip4/127.0.0.1/udp/5001']),
  );

  // 2. Configure Node B (Receiver)
  final configB = IPFSConfig(
    offline: false,
    enableLibp2pBridge: true,
    libp2pListenAddress: '/ip4/0.0.0.0/tcp/4002',
    datastorePath: './test_repo_b/data',
    network: NetworkConfig(listenAddresses: ['/ip4/127.0.0.1/udp/5002']),
  );

  print('Initializing nodes...');
  Logger.root.level = Level.ALL; // Added this line
  final nodeA = await IPFSNode.create(configA);
  final nodeB = await IPFSNode.create(configB);

  await nodeA.start();
  await nodeB.start();

  print('Nodes started.');
  print('Node A PeerID: ${nodeA.peerId}');
  print('Node B PeerID: ${nodeB.peerId}');

  // 3. Register a protocol handler on Node B to verify message reception
  final completer = Completer<String>();

  // Since we want to test the BRIDGE, we need to ensure nodeA sends via libp2p.
  // We'll manually add Node B's address to Node A's router but as a LIBP2P address.
  // Actually, p2plib.Router will use the Libp2pTransport if it's the only one that handles the address,
  // or if we force it.

  // Actually, let's just use the sendMessage API.

  final testProtocolId = '/test/1.0.0';

  final networkHandlerB = nodeB.container.get<NetworkHandler>();
  networkHandlerB.p2pRouter.registerProtocolHandler(testProtocolId, (packet) {
    final message = String.fromCharCodes(packet.datagram);
    print('Node B received message: $message');
    completer.complete(message);
  });

  print('Waiting for nodes to initialize...');
  await Future.delayed(Duration(seconds: 2));

  // 4. Send message from Node A to Node B via the bridge
  final dstPeerIdStr = nodeB.peerId;
  final multiaddr = '/ip4/127.0.0.1/tcp/4002/p2p/$dstPeerIdStr';

  print('Node A connecting to Node B via $multiaddr...');
  final networkHandlerA = nodeA.container.get<NetworkHandler>();

  try {
    await networkHandlerA.p2pRouter.connect(multiaddr);
    print('Connection successful.');
  } catch (e) {
    print(
      'Connect failed, but if addresses are already in router it might still work. Error: $e',
    );
  }

  final messageText = 'Hello from Libp2p Bridge! ' * 10;
  print('Node A sending message to Node B...');
  await networkHandlerA.p2pRouter.sendMessage(
    dstPeerIdStr,
    Uint8List.fromList(messageText.codeUnits),
    protocolId: testProtocolId,
  );

  try {
    final result = await completer.future.timeout(Duration(seconds: 15));
    if (result == messageText) {
      print('✅ SUCCESS: Message received via Libp2p Bridge!');
    } else {
      print('❌ FAILURE: Unexpected message received: $result');
    }
  } catch (e) {
    print(
      '❌ FAILURE: Timeout waiting for message. Bridge might be broken. Error: $e',
    );
  }

  print('Stopping nodes...');
  await nodeA.stop();
  await nodeB.stop();

  // Cleanup test repos
  try {
    Directory('./test_repo_a').deleteSync(recursive: true);
    Directory('./test_repo_b').deleteSync(recursive: true);
  } catch (_) {}

  exit(0);
}
