// example/full_node_example.dart
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/services/gateway/gateway_server.dart';
import 'package:dart_ipfs/src/services/rpc/rpc_server.dart';

/// Complete IPFS Node Example
///
/// Demonstrates a fully functional IPFS node with:
/// - DHT (Kademlia) for peer discovery
/// - Bitswap for block exchange
/// - HTTP Gateway (port 8080) for browser access
/// - RPC API (port 5001) for programmatic control
Future<void> main() async {
  print('🚀 Starting Complete IPFS Node...\n');

  // Step 1: Create configuration
  print('📝 Creating IPFS configuration...');
  final config = IPFSConfig();

  // Step 2: Initialize IPFS node
  print('🔧 Initializing IPFS node...');
  final node = await IPFSNode.create(config);
  await node.start();
  print('✅ Node started with Peer ID: ${node.peerId}\n');

  // Step 3: Start HTTP Gateway
  print('🌐 Starting HTTP Gateway...');
  final gateway = GatewayServer(
    blockStore: node.blockStore,
    address: 'localhost',
    port: 8080,
    corsOrigins: ['*'],
  );
  await gateway.start();
  print('✅ Gateway running at: ${gateway.url}\n');

  // Step 4: Start RPC API
  print('🔌 Starting RPC API...');
  final rpc = RPCServer(
    node: node,
    address: 'localhost',
    port: 5001,
    corsOrigins: ['*'],
  );
  await rpc.start();
  print('✅ RPC API running at: ${rpc.url}\n');

  // Display usage information
  _printUsageInfo(gateway.url, rpc.url, node.peerId);

  // Keep the node running
  print('\n⏹️  Press Ctrl+C to stop the node\n');
  await Future.delayed(Duration(days: 365));
}

void _printUsageInfo(String gatewayUrl, String rpcUrl, String peerId) {
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('                IPFS NODE IS READY                    ');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('\n📋 Node Information:');
  print('   Peer ID: $peerId');
  print('   Gateway: $gatewayUrl');
  print('   RPC API: $rpcUrl');

  print('\n🌐 Gateway Endpoints (Browser):');
  print('   $gatewayUrl/ipfs/{cid}');
  print('   $gatewayUrl/ipns/{name}');
  print('   $gatewayUrl/health');

  print('\n🔌 RPC API Examples:');
  print('   # Get node info');
  print('   curl -X POST $rpcUrl/api/v0/id');
  print('');
  print('   # Get node version');
  print('   curl -X POST $rpcUrl/api/v0/version');
  print('');
  print('   # List connected peers');
  print('   curl -X POST $rpcUrl/api/v0/swarm/peers');
  print('');
  print('   # Get content by CID');
  print('   curl -X POST "$rpcUrl/api/v0/cat?arg=QmYourCID"');
  print('');
  print('   # List directory');
  print('   curl -X POST "$rpcUrl/api/v0/ls?arg=/ipfs/QmYourCID"');
  print('');
  print('   # Find providers for CID');
  print('   curl -X POST "$rpcUrl/api/v0/dht/findprovs?arg=QmYourCID"');

  print('\n📚 Protocol Support:');
  print('   ✅ Kademlia DHT (peer discovery & routing)');
  print('   ✅ Bitswap 1.2.0 (block exchange)');
  print('   ✅ IPNS (naming system)');
  print('   ✅ UnixFS (file system)');
  print('   ✅ HTTP Gateway (browser access)');
  print('   ✅ RPC API (programmatic control)');

  print('\n🔗 Interoperability:');
  print('   Compatible with go-ipfs, js-ipfs, and other IPFS implementations');
  print('   Uses standard IPFS protocols and wire formats');

  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
}
