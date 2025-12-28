// Test script to verify libsodium setup functionality
import 'dart:io';
import 'package:dart_ipfs/dart_ipfs.dart';

void main() async {
  stdout.writeln('═══════════════════════════════════════════');
  stdout.writeln('Testing dart_ipfs with Proactive Libsodium Setup');
  stdout.writeln('═══════════════════════════════════════════\n');

  stdout.writeln('Step 1: Creating IPFS node with P2P enabled...');

  try {
    final node = await IPFSNode.create(
      IPFSConfig(offline: false), // P2P mode - requires libsodium
    );

    stdout.writeln('✅ Node created successfully!');
    stdout.writeln('   libsodium check passed\n');

    stdout.writeln('Step 2: Starting node...');
    await node.start();

    stdout.writeln('✅ Node started!');
    stdout.writeln('   Peer ID: ${node.peerId}\n');

    stdout.writeln('Step 3: Stopping node...');
    await node.stop();

    stdout.writeln('✅ All tests passed!');
    stdout.writeln('\n═══════════════════════════════════════════');
    stdout.writeln('Success: dart_ipfs P2P mode working correctly');
    stdout.writeln('═══════════════════════════════════════════');
  } catch (e, stackTrace) {
    stdout.writeln('❌ Error: $e');
    stdout.writeln('\nStack trace:');
    stdout.writeln(stackTrace);
    stdout.writeln('\n═══════════════════════════════════════════');
    stdout.writeln('Test failed - see error above');
    stdout.writeln('═══════════════════════════════════════════');
  }
}
