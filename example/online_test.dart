// example/online_test.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:dart_ipfs/dart_ipfs.dart';

/// Test: Online Mode (Full P2P Networking)
///
/// This test runs the same blog publishing scenario but with
/// the P2P network layer ENABLED (offline: false).
/// This verifies if the node can initialize the LibP2P stack
/// and generate its cryptographic identity.
void main() async {
  print('🌐 Starting Online Mode Test...\n');

  // 1. Initialize IPFS Config (Online Mode)
  final config = IPFSConfig(
    offline: false, // ENABLE NETWORKING
    debug: true,
    verboseLogging: true,
    blockStorePath: './online_data/blocks',
    datastorePath: './online_data/datastore',
  );

  print('🔹 Initializing IPFS Node (Online Mode)...');
  // This step previously hung due to p2plib crypto initialization
  final node = await IPFSNode.create(config);
  
  print('🔹 Starting Node...');
  await node.start();
  print('✅ IPFS Node started with PeerID: ${node.peerID}');
  print('   Addresses: ${node.addresses}');

  try {
    print('\n🔹 Creating Blog Assets...');
    
    final indexHtml = '<h1>Hello from the P2P World!</h1>';
    
    // 2. Add file to IPFS
    print('🔹 Adding file...');
    final cid = await node.addFile(Uint8List.fromList(utf8.encode(indexHtml)));
    print('   📝 content CID: $cid');

    // 3. Retrieve Content
    print('🔹 Retrieving content...');
    final retrieved = await node.get(cid);
    
    if (retrieved != null && utf8.decode(retrieved) == indexHtml) {
      print('   ✅ Content verified!');
    } else {
      print('   ❌ Content verification failed.');
    }

    // 4. Find Providers (Network specific)
    print('\n🔹 Finding providers for CID...');
    final providers = await node.findProviders(cid);
    print('   Found ${providers.length} providers (expected at least self)');

  } catch (e, stack) {
    print('❌ Error occurred: $e');
    print(stack);
  } finally {
    print('\n🔹 Stopping IPFS Node...');
    await node.stop();
    print('✅ Node stopped.');
  }
}
