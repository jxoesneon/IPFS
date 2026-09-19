// ignore_for_file: avoid_print
import 'package:dart_ipfs/dart_ipfs.dart';

/// Template: Secure Gateway Node
///
/// A production-ready node optimized for HTTP Gateway service.
/// Includes:
/// - SecurityManager with Encrypted Keystore
/// - Read-only HTTP Gateway
/// - Structured JSON logs via the IPFS_JSON_LOGS environment variable
void main() async {
  // 1. Create a secure configuration
  final config = IPFSConfig(
    dataPath: './gateway_data',
    offline: false, // Enable P2P to fetch remote content
    gateway: const GatewayConfig(enabled: true, port: 8080),
  );

  // 2. Initialize the node
  final node = await IPFSNode.create(config);

  // 3. Unlock the SecurityManager (Mandatory for identity operations)
  // In production, pull the password from environment variables or HSM
  const keystorePassword = 'secure-password-123';
  await node.securityManager.unlockKeystore(keystorePassword);
  print('SecurityManager unlocked.');

  // 4. Start the services
  await node.start();

  print('Secure Gateway running at: http://localhost:8080');
  print('Health status available at: http://localhost:8080/health');
  print('Peer ID: ${node.peerId}');

  // Node will run until terminated
}
