# Troubleshooting Guide

This guide covers common issues and solutions when working with dart_ipfs.

## Table of Contents

- [Installation Issues](#installation-issues)
- [Build Issues](#build-issues)
- [Runtime Issues](#runtime-issues)
- [Networking Issues](#networking-issues)
- [Storage Issues](#storage-issues)
- [Test Issues](#test-issues)
- [WASM/Web Issues](#wasmweb-issues)

## Installation Issues

### `pub get` fails with dependency conflicts

**Problem:** `dart pub get` fails with version constraint errors.

**Solution:**
```bash
# Clean dependencies
dart pub cache repair
dart pub get

# If still failing, check dependency overrides in pubspec.yaml
# Some packages have documented overrides for security/compatibility
```

### Missing native dependencies on Linux

**Problem:** Build fails with missing system libraries.

**Solution:**
```bash
# Install required system packages
sudo apt-get update
sudo apt-get install -y libgtk-3-dev libblkid-dev liblzma-dev
```

## Build Issues

### `dart compile exe` fails

**Problem:** AOT compilation fails with type errors.

**Solution:**
```bash
# Run analyzer first
dart analyze

# Fix any errors, then retry compilation
dart compile exe example/dart_ipfs_example.dart -o ipfs_node
```

### Flutter build fails on Linux

**Problem:** Flutter dashboard build fails on Linux.

**Solution:**
```bash
# Install Linux build dependencies
sudo apt-get update
sudo apt-get install -y libgtk-3-dev libblkid-dev liblzma-dev

# Clean and rebuild
cd example/ipfs_dashboard
flutter clean
flutter pub get
flutter build linux --debug
```

## Runtime Issues

### Node fails to start with "keystore locked"

**Problem:** IPFS node fails to start with keystore encryption error.

**Solution:**
```dart
// Unlock keystore with password
final node = await IPFSNode.create(
  config: config,
  keystorePassword: 'your-password',
);
```

Or use the keystore unlock example:
```bash
dart example/keystore_unlock_example.dart
```

### DHT provider announcements fail

**Problem:** DHT content routing doesn't work, providers not announced.

**Solution:**
```dart
// Ensure DHT is enabled in config
final config = IPFSConfig(
  enableDHT: true,
  dhtBootstrapPeers: [...], // Add bootstrap peers
);

// Verify connectivity
await node.start();
print('Connected peers: ${node.router.connectedPeers.length}');
```

### Gateway returns 404 for valid CIDs

**Problem:** Gateway returns 404 even though CID exists in blockstore.

**Solution:**
```dart
// Verify block is in blockstore
final block = await node.blockstore.get(cid);
if (block == null) {
  print('Block not found in local blockstore');
  // Fetch from network
  await node.bitswap.fetch(cid);
}

// Check gateway configuration
final gatewayConfig = GatewayConfig(
  enableTrustlessGateway: true, // Enable trustless mode
);
```

## Networking Issues

### Peers not connecting

**Problem:** Node starts but no peer connections established.

**Solution:**
```dart
// Check if listening addresses are configured
final config = IPFSConfig(
  listenAddresses: [
    '/ip4/0.0.0.0/tcp/4001',
    '/ip4/0.0.0.0/udp/4001/quic-v1',
  ],
  bootstrapPeers: [...], // Add bootstrap peers
);

// Check firewall settings
# Linux
sudo ufw allow 4001/tcp
sudo ufw allow 4001/udp

# Windows (PowerShell)
New-NetFirewallRule -DisplayName "IPFS" -Direction Inbound -LocalPort 4001 -Protocol TCP -Action Allow
New-NetFirewallRule -DisplayName "IPFS UDP" -Direction Inbound -LocalPort 4001 -Protocol UDP -Action Allow
```

### WebRTC connections fail

**Problem:** WebRTC peer-to-peer connections fail in browser.

**Solution:**
```dart
// Ensure signaling server is configured
final config = IPFSConfig(
  webrtcSignalingServers: [
    'wss://signaling.example.com',
  ],
);

// Check browser console for STUN/TURN errors
// Configure STUN/TURN servers if behind NAT
final config = IPFSConfig(
  webrtcIceServers: [
    'stun:stun.l.google.com:19302',
    'turn:turn.example.com:3478?transport=udp',
  ],
);
```

### QUIC transport not available

**Problem:** QUIC transport fails to initialize.

**Solution:**
```dart
// Ensure dart_ipfs_quic package is installed
dart pub add dart_ipfs_quic

// Check if QUIC is enabled in config
final config = IPFSConfig(
  enableQUIC: true,
);

// Note: QUIC requires dart_ipfs_quic adapter package
// See packages/dart_ipfs_quic/ for details
```

## Storage Issues

### Blockstore corruption

**Problem:** Blockstore returns invalid data or throws errors.

**Solution:**
```dart
// Clear blockstore and re-sync
await node.blockstore.clear();
await node.bitswap.fetch(cid); // Re-fetch from network

// Or delete data directory and restart
rm -rf ipfs_data/
```

### IndexedDB quota exceeded (Web)

**Problem:** Web storage fails with quota exceeded error.

**Solution:**
```dart
// Configure storage limits
final config = IPFSConfig(
  webStorageMaxSize: 100 * 1024 * 1024, // 100MB
);

// Clear old data
await node.blockstore.clear();
```

### Hive database locked

**Problem:** Hive database fails with "database is locked" error.

**Solution:**
```dart
// Ensure only one node instance per data directory
// Check for stale lock files
rm -f *.hive.lock

// Use unique data directories for multiple nodes
final config = IPFSConfig(
  dataDirectory: 'ipfs_data_${uniqueId}',
);
```

## Test Issues

### Tests fail with "connection refused"

**Problem:** Integration tests fail with connection errors.

**Solution:**
```bash
# Start required services (Kubo, Helia) before running tests
cd test/interop/kubo
docker-compose up -d

cd test/interop/helia
npm install
npm start

# Then run tests
dart test test/interop/
```

### Tests timeout

**Problem:** Tests timeout after 30 seconds.

**Solution:**
```dart
// Increase timeout for slow tests
testWidgets('slow test', (tester) async {
  // ...
}, timeout: const Timeout(Duration(minutes: 2)));
```

Or run with increased timeout:
```bash
dart test --timeout=2m
```

### Fuzz tests crash

**Problem:** Fuzz tests cause crashes or hangs.

**Solution:**
```dart
// Limit fuzz iterations
fuzzTest('my parser', (input) {
  // ...
  maxIterations: 1000,
  maxDuration: const Duration(seconds: 30),
);
```

## WASM/Web Issues

### WASM compilation fails

**Problem:** `dart compile wasm` fails with dart:io errors.

**Solution:**
```bash
# Use web-specific entry point
dart compile wasm example/wasm_main.dart -o build/dart_ipfs.wasm

# Ensure no dart:io imports in web code
dart analyze --no-fatal-infos
```

### WASM module fails to load in browser

**Problem:** WASM module loads but throws errors in browser console.

**Solution:**
```javascript
// Ensure correct MIME types
// Serve .wasm as application/wasm
// Serve .mjs as text/javascript

// Check browser compatibility
// Chrome 57+, Firefox 52+, Safari 11+
```

### IndexedDB not working in WASM

**Problem:** WASM module can't access IndexedDB.

**Solution:**
```dart
// Use IPFSWebNode instead of IPFSNode for web
final node = await IPFSWebNode.create(
  config: config,
);

// IPFSWebNode uses web-specific storage (IndexedDB)
```

## Getting Help

If you're still experiencing issues:

1. Check the [Architecture Guide](ARCHITECTURE.md) for implementation details
2. Review [GitHub Issues](https://github.com/jxoesneon/IPFS/issues) for similar problems
3. Open a new issue with:
   - dart_ipfs version
   - Dart SDK version
   - Operating system
   - Full error message
   - Minimal reproduction code
   - Steps to reproduce

## Debug Mode

Enable debug logging for troubleshooting:

```dart
import 'package:logging/logging.dart';

void main() async {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  final node = await IPFSNode.create(config: config);
  // ...
}
```
