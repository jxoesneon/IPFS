// ignore_for_file: avoid_print
// example/gateway_example.dart
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/services/gateway/gateway_server.dart';

/// Example of running the IPFS HTTP Gateway
///
/// This demonstrates how to start an IPFS gateway server that serves
/// content via standard HTTP endpoints.
void main() async {
  print('🚀 Starting IPFS Gateway Example...\n');

  // Create a blockstore (in-memory for this example)
  final blockStore = BlockStore(path: './blocks');

  // Create the gateway server
  final gateway = GatewayServer(
    blockStore: blockStore,
    address: 'localhost',
    port: 8080,
    corsOrigins: ['*'], // Allow all origins for testing
  );

  // Start the server
  await gateway.start();

  print('\n📖 Gateway is running!');
  print('   URL: ${gateway.url}');
  print('\n🌐 Try these endpoints:');
  print('   GET  ${gateway.url}/ipfs/{cid}          - Retrieve content');
  print('   HEAD ${gateway.url}/ipfs/{cid}          - Get content metadata');
  print('   GET  ${gateway.url}/api/v0/version     - Get version info');
  print('   GET  ${gateway.url}/health             - Health check');
  print('\n💡 Examples:');
  print('   curl ${gateway.url}/api/v0/version');
  print('   curl ${gateway.url}/health');
  print('\n⏹️  Press Ctrl+C to stop the server\n');

  // Keep the server running
  await Future<void>.delayed(const Duration(days: 1));
}

