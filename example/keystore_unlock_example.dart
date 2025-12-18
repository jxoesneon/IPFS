#!/usr/bin/env dart
// example/keystore_unlock_example.dart
//
// Example demonstrating secure keystore unlock flow.
// Usage: dart run example/keystore_unlock_example.dart

// ignore_for_file: avoid_print

import 'dart:io';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/config/security_config.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/security/security_manager.dart';
import 'package:dart_ipfs/src/utils/password_prompt.dart';

Future<void> main() async {
  print('=== IPFS Keystore Unlock Example ===\n');

  // Create configuration
  final config = IPFSConfig(offline: true);
  final securityConfig = const SecurityConfig();
  final metrics = MetricsCollector(config);

  // Create security manager
  final securityManager = SecurityManager(securityConfig, metrics);

  // Check if we have existing secure keys
  final hasExistingKeys = securityManager.hasSecureKey('self');

  String? password;
  if (hasExistingKeys) {
    // Existing keystore - prompt for unlock
    print('Existing keystore found.\n');
    password = PasswordPrompt.prompt('Enter keystore password: ');
  } else {
    // New keystore - create with password
    print('No keystore found. Creating new encrypted keystore.\n');
    password = PasswordPrompt.promptNew('Create keystore password: ');
    if (password != null && !PasswordPrompt.isStrongEnough(password)) {
      exit(1);
    }
  }

  if (password == null) {
    stderr.writeln('Error: Password required');
    exit(1);
  }

  // Unlock keystore
  try {
    print('\nUnlocking keystore...');
    await securityManager.unlockKeystore(password);
    print('✓ Keystore unlocked successfully!\n');

    // Migrate any plaintext keys
    final migratedCount = await securityManager.migrateKeysFromPlaintext();
    if (migratedCount > 0) {
      print('✓ Migrated $migratedCount keys to encrypted storage\n');
    }

    // Show status
    final status = await securityManager.getStatus();
    print('Keystore Status:');
    print('  - Unlocked: ${securityManager.isKeystoreUnlocked}');
    print('  - TLS Enabled: ${status['tls_enabled']}');

    // Generate example key if none exist
    if (!securityManager.hasSecureKey('self')) {
      print('\nGenerating default identity key...');
      final publicKey = await securityManager.generateSecureKey(
        'self',
        label: 'Node Identity',
      );
      print('✓ Identity key generated (${publicKey.length} bytes)\n');
    } else {
      print('  - Identity key: present');
    }

    // Lock keystore when done
    securityManager.lockKeystore();
    print('\n✓ Keystore locked');
  } catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  }

  print('Done!');
}
