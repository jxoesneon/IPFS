// ignore_for_file: avoid_print
// example/rpc_example.dart
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/services/rpc/rpc_server.dart';

/// Example of running the IPFS RPC API server
///
/// This demonstrates the HTTP RPC API for programmatic control
void main() async {
  print('🚀 Starting IPFS RPC API Example...\n');

  // Create IPFS configuration
  final config = IPFSConfig();

  // Start the IPFS node
  final node = await IPFSNode.create(config);
  await node.start();

  // Create the RPC server
  final rpcServer = RPCServer(
    node: node,
    address: 'localhost',
    port: 5001,
    corsOrigins: ['*'],
  );

  // Start the server
  await rpcServer.start();

  print('\n📖 RPC API is running!');
  print('   URL: ${rpcServer.url}');
  print('\n🌐 Available endpoints (POST):');
  print('   ${rpcServer.url}/api/v0/version       - Get version');
  print('   ${rpcServer.url}/api/v0/id            - Get peer ID');
  print('   ${rpcServer.url}/api/v0/cat?arg=CID   - Get content');
  print('   ${rpcServer.url}/api/v0/ls?arg=PATH   - List directory');
  print('   ${rpcServer.url}/api/v0/swarm/peers   - List peers');
  print('   ${rpcServer.url}/api/v0/name/publish?arg=PATH');
  print('   ${rpcServer.url}/api/v0/dht/findprovs?arg=CID');
  print('\n💡 Examples:');
  print('   curl -X POST ${rpcServer.url}/api/v0/version');
  print('   curl -X POST ${rpcServer.url}/api/v0/id');
  print('   curl -X POST ${rpcServer.url}/api/v0/swarm/peers');
  print('\n⏹️  Press Ctrl+C to stop the server\n');

  // Keep the server running
  await Future<void>.delayed(const Duration(days: 1));
}

