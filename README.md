# dart_ipfs

A complete, production-ready IPFS (InterPlanetary File System) implementation in Dart, supporting offline, gateway, and full P2P modes. Built for mobile (Flutter), desktop, and web platforms.

[![pub package](https://img.shields.io/pub/v/dart_ipfs.svg)](https://pub.dev/packages/dart_ipfs)
[![Dart](https://img.shields.io/badge/dart-%3E%3D3.0.0-blue.svg)](https://dart.dev/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Build Status](https://github.com/jxoesneon/IPFS/actions/workflows/test.yml/badge.svg)](https://github.com/jxoesneon/IPFS/actions/workflows/test.yml)
[![Tests](https://img.shields.io/badge/tests-1098-brightgreen.svg)](https://github.com/jxoesneon/IPFS/actions)
[![Ko-Fi](https://img.shields.io/badge/Ko--fi-F16061?style=flat&logo=ko-fi&logoColor=white)](https://ko-fi.com/jxoesneon)

> **TL;DR**: A pure-Dart IPFS node for mobile, desktop, and web. Supports offline content-addressable storage, full P2P networking with NAT traversal, HTTP gateways, and production-grade security.

---

## 📚 Documentation

- **[Wiki](https://github.com/jxoesneon/IPFS/wiki)** — Guides, Installation, Architecture
- **[API Reference](https://jxoesneon.github.io/IPFS/)** — Auto-generated Dart docs

---

## Table of Contents

- [What's New in v1.8](#-whats-new-in-v18)
- [Features](#features)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Use Cases](#use-cases)
- [Architecture](#architecture)
- [Security](#-security)
- [Performance](#performance)
- [Known Limitations](#known-limitations)
- [Troubleshooting](#troubleshooting)
- [Examples](#examples)
- [Contributing](#contributing)
- [Roadmap](#roadmap)
- [License](#license)

---

## 🚀 What's New in v1.9

### Major Features

| Feature                 | Description                                                  |
| ----------------------- | ------------------------------------------------------------ |
| **Native libp2p Core**  | Fully migrated to `dart_libp2p` for standard IPFS networking |
| **95% Router Coverage** | Core `Libp2pRouter` achieves **95.6%** test coverage         |
| **Stability Baseline**  | 100% pass rate confirmed across 1098 unit/integration tests  |
| **Cleanup**             | Removed all legacy `p2plib` dependencies and shims           |

## 🚀 What's New in v1.8

### Major Features

| Feature                | Description                                               |
| ---------------------- | --------------------------------------------------------- |
| **libp2p Bridge**      | TCP/Noise transport to connect with standard libp2p nodes |
| **Circuit Relay v2**   | Full HOP/STOP/RESERVE implementation for hole-punching    |
| **AutoNAT**            | Automatic NAT type detection (symmetric/restricted/none)  |
| **S/Kademlia PoW**     | Sybil attack protection for DHT routing                   |
| **Encrypted Keystore** | AES-256-GCM with PBKDF2 key derivation                    |

### Security Hardening (v1.7.4+)

- SEC-001: Secure random number generation
- SEC-002: NAT traversal security controls
- SEC-004: Hardened command execution
- SEC-005: S/Kademlia Proof-of-Work
- SEC-008: Encrypted key storage
- SEC-010: DHT rate limiting

### Stability

- 1098 tests passing
- Resolved 50+ issues since v1.7.0
- Protocol compliance with go-ipfs (Kubo)

---

## Features

### ✅ Core IPFS Functionality

- **Content-Addressable Storage**: CID v0 and v1 support
- **UnixFS**: Full file system implementation with chunking
- **DAG-PB**: MerkleDAG operations and IPLD traversal
- **CAR Files**: Import/export support
- **Pinning**: Content persistence management

### ✅ Networking & NAT Traversal

- **Bitswap 1.2.0**: Efficient block exchange with wantlist management
- **Kademlia DHT**: Distributed hash table for peer/content routing
- **AutoNAT**: Automatic NAT type detection
  - Direct connectivity testing
  - Symmetric NAT detection
  - Periodic dialback verification
- **UPnP/NAT-PMP**: Automatic port mapping via `NatTraversalService`
- **Circuit Relay v2**: Hole-punching via relay peers
  - HOP protocol (relay serving)
  - STOP protocol (connection handling)
  - RESERVE protocol (relay reservations)
- **libp2p Core**: Native TCP/Noise transport for standard P2P networking
- **PubSub**: Real-time messaging (Gossipsub)
- **mDNS**: Local peer discovery
- **Bootstrap Peers**: Network connectivity initialization

### ✅ Services

- **HTTP Gateway**: Read-only and writable modes
- **RPC API**: Compatible with go-ipfs API
- **IPNS**: Mutable naming system with Ed25519 signatures
- **DNSLink**: Domain-based content resolution
- **GraphSync**: Efficient graph synchronization protocol
- **Metrics**: Prometheus-compatible monitoring

### ✅ Security

- **Production Cryptography**
  - secp256k1 key exchange (128-bit security)
  - ChaCha20-Poly1305 AEAD encryption
  - SHA-256 content hashing
  - Ed25519 IPNS signatures
- **Encrypted Keystore (SEC-008)**
  - AES-256-GCM encryption
  - PBKDF2 key derivation
  - Automatic key rotation
  - Memory zeroing on lock
- **Sybil Protection (SEC-005)**
  - S/Kademlia Proof-of-Work for PeerId verification
  - Configurable difficulty via `SecurityConfig.dhtDifficulty`
- **Rate Limiting**
  - Per-client authentication throttling
  - DHT provider announcement limits
- **Content Verification**
  - Automatic CID validation
  - Merkle tree verification
  - Block integrity checks

### ✅ Web Platform

- **`IPFSWebNode`**: Browser-compatible implementation
- **IndexedDB Storage**: Persistent local storage
- **WebSocket Transport**: Networking via secure relays
- **Bitswap & PubSub**: Full protocol support in browsers

---

## Quick Start

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  dart_ipfs: ^1.9.0
```

Or from Git for latest development:

```yaml
dependencies:
  dart_ipfs:
    git:
      url: https://github.com/jxoesneon/IPFS.git
```

Then run:

```bash
dart pub get
```

### Windows Setup

**Important**: On Windows, P2P networking requires `libsodium` for cryptography.

**✅ Automatic Setup**: dart_ipfs automatically detects and installs libsodium via `winget` on first run.

**Manual Installation** (if auto-install fails):

```powershell
# Via winget (recommended)
winget install jedisct1.libsodium

# Or use offline mode (no P2P)
IPFSConfig(offline: true)
```

### Basic Usage

#### Offline Mode (Local Storage)

```dart
import 'package:dart_ipfs/dart_ipfs.dart';

void main() async {
  final node = await IPFSNode.create(
    IPFSConfig(
      dataDir: './ipfs_data',
      offline: true,  // No P2P networking
    ),
  );

  await node.start();

  // Add content
  final cid = await node.add('Hello, IPFS!');
  print('Added with CID: $cid');

  // Retrieve content
  final retrieved = await node.cat(cid);
  print('Retrieved: $retrieved');

  await node.stop();
}
```

#### Gateway Mode (HTTP Server)

```dart
final node = await IPFSNode.create(
  IPFSConfig(
    dataDir: './gateway_data',
    offline: true,
    gateway: GatewayConfig(
      enabled: true,
      port: 8080,
    ),
  ),
);

await node.start();
print('Gateway running at http://localhost:8080');
// Access content at: http://localhost:8080/ipfs/<CID>
```

#### P2P Network Mode (Full Node)

```dart
final node = await IPFSNode.create(
  IPFSConfig(
    dataDir: './p2p_data',
    offline: false,  // Enable P2P networking
    network: NetworkConfig(
      bootstrapPeers: [
        '/dnsaddr/bootstrap.libp2p.io/p2p/...',
      ],
      enableNatTraversal: true,  // UPnP/NAT-PMP
    ),
  ),
);

await node.start();
print('P2P Node ID: ${node.peerID}');
// Node participates in DHT, Bitswap, PubSub
```

#### Web Platform (Browser)

```dart
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_web_node.dart';

void main() async {
  final node = IPFSWebNode(
    bootstrapPeers: ['wss://relay.node.address/p2p/...'],
  );
  await node.start();

  final cid = await node.add(Uint8List.fromList('Hello Web!'.codeUnits));
  print('Added: $cid');

  final data = await node.get(cid.encode());
  print('Retrieved: ${String.fromCharCodes(data!)}');
}
```

---

## Configuration

### Full Configuration Reference

```dart
IPFSConfig(
  // Storage
  dataDir: './ipfs_data',

  // Networking
  offline: false,
  network: NetworkConfig(
    bootstrapPeers: [...],
    listenAddresses: ['/ip4/0.0.0.0/tcp/4001'],
    enableNatTraversal: true,  // UPnP/NAT-PMP port mapping
  ),

  // Gateway
  gateway: GatewayConfig(
    enabled: true,
    port: 8080,
    writable: false,
    cacheSize: 1024 * 1024 * 1024,  // 1GB
  ),

  // RPC API
  rpc: RPCConfig(
    enabled: true,
    port: 5001,
  ),

  // DHT
  dht: DHTConfig(
    mode: DHTMode.server,  // client, server, or auto
    bucketSize: 20,
  ),

  // Security
  security: SecurityConfig(
    dhtDifficulty: 16,              // S/Kademlia PoW difficulty
    rateLimitWindow: Duration(minutes: 1),
    maxAuthAttempts: 5,
    keyRotationInterval: Duration(days: 30),
  ),

  // Logging
  debug: false,
  verboseLogging: false,
)
```

---

## Use Cases

### 1. Decentralized Storage

```dart
final file = File('document.pdf');
final bytes = await file.readAsBytes();
final cid = await node.addBytes(bytes);
print('Document CID: $cid');
// Content is permanently addressable
```

### 2. Content Distribution Network

```dart
final config = IPFSConfig(
  gateway: GatewayConfig(
    enabled: true,
    port: 8080,
    cacheSize: 1024 * 1024 * 1024,
  ),
);
```

### 3. Peer-to-Peer Applications

```dart
// PubSub messaging
await node.pubsub.subscribe('my-topic', (message) {
  print('Received: $message');
});

await node.pubsub.publish('my-topic', 'Hello, peers!');
```

### 4. Decentralized Websites

```dart
final websiteDir = Directory('./my-website');
final rootCID = await node.addDirectory(websiteDir);
// Access via: http://gateway/ipfs/<rootCID>/index.html
```

---

## Architecture

```
┌─────────────────────────────────────┐
│         Application Layer            │
│   (Your Dart/Flutter Application)    │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│         dart_ipfs Public API         │
│  (IPFSNode, add, cat, pin, etc.)    │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│         Service Layer                │
│  Gateway │ RPC │ PubSub │ IPNS      │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│        Protocol Layer                │
│  Bitswap │ DHT │ GraphSync │ Relay  │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│        Transport Layer               │
│        P2P (Native libp2p)           │
│  AutoNAT │ Circuit Relay v2           │
│  Crypto (Ed25519 + Noise)            │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│         Storage Layer                │
│   UnixFS │ DAG-PB │ BlockStore       │
│   Datastore (Hive) │ Pinning         │
└─────────────────────────────────────┘
```

---

## 🛡️ Security

> **IMPORTANT**: Production use requires strict sandboxing.
> See `docker-compose.yml` for a secure reference implementation.

### Recommended Deployment

1.  **Immutable Filesystem**: Run with a read-only root
2.  **Non-Root Execution**: Use UID > 1000 (e.g., `10001`)
3.  **Network Isolation**: Bind ports to localhost (`127.0.0.1`) only
4.  **IP Diversity Limits**: Max 5 peers/IP to prevent routing table poisoning

### Encrypted Keystore

```dart
// Unlock keystore with password
await node.securityManager.unlockKeystore('your-password');

// Keys are encrypted at rest with AES-256-GCM
// Master key derived via PBKDF2
// Automatic memory zeroing on lock
```

### S/Kademlia PoW

```dart
// Enable Sybil protection in DHT
SecurityConfig(
  dhtDifficulty: 16,  // Require 16-bit PoW prefix
)
// Peers with insufficient PoW are rejected from routing table
```

---

## Performance

| Metric          | Value                   |
| --------------- | ----------------------- |
| Content Hashing | ~50 MB/s (SHA-256)      |
| Block Storage   | ~1000 ops/sec (Hive)    |
| Gateway Latency | <10ms (local cache hit) |
| P2P Handshake   | <100ms (secp256k1 ECDH) |
| Memory Baseline | ~50MB + content cache   |

---

## Known Limitations

None.

---

## Troubleshooting

### Node Won't Start (Windows)

**Symptom**: Hangs during startup

**Solution**: Install libsodium:

```powershell
winget install jedisct1.libsodium
```

### AutoNAT Reports "Symmetric"

**Symptom**: Peers can't connect to you

**Solution**: Enable port mapping:

```dart
NetworkConfig(enableNatTraversal: true)
```

### DHT Queries Slow

**Symptom**: `findProviders` takes >30s

**Solution**: Ensure bootstrap peers are reachable and check `dhtDifficulty` isn't too high.

### Gateway Returns 404

**Symptom**: Content not found even though added

**Solution**: Check if content is pinned:

```dart
await node.pin(cid);
```

---

## Examples

See the `example/` directory for full applications:

- **[📱 Premium Dashboard](example/ipfs_dashboard)**: Flutter desktop app with glassmorphism UI
- **[📟 CLI Dashboard](example/cli_dashboard)**: Matrix-style terminal interface

Other examples:

- [Basic Usage](example/dart_ipfs_example.dart)
- [Offline Blog](example/blog_use_case.dart)
- [P2P Networking](example/online_test.dart)
- [HTTP Gateway](example/gateway_example.dart)
- [Full Node](example/full_node_example.dart)
- [Keystore Unlock](example/keystore_unlock_example.dart)
- [libp2p Bridge Verification](example/verify_bridge.dart)

Run examples:

```bash
dart run example/blog_use_case.dart
dart run example/online_test.dart
```

---

## Testing

```bash
# Run all tests
dart test

# Run with verbose output
dart test -r expanded

# Static analysis
dart analyze
```

Expected results:

- ✅ 0 errors
- ✅ 0 warnings
- ✅ 1098 tests pass

---

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Write tests for new features
4. Ensure `dart analyze` and `dart test` pass
5. Submit a pull request

---

## Roadmap

### ✅ Done

- Core IPFS protocols (Bitswap, DHT, PubSub)
- Offline, Gateway, and P2P modes
- Production cryptography
- Web platform support
- libp2p core migration
- Circuit Relay v2
- AutoNAT
- Encrypted keystore
- S/Kademlia PoW
- 95%+ Router Coverage

### 🔄 In Progress

- Mobile optimization (Flutter performance)
- QUIC transport (native, beyond libp2p bridge)

### 📋 Planned

- Full WebRTC transport
- Filecoin integration

---

## Comparison with go-ipfs

| Feature          | dart_ipfs   | go-ipfs (Kubo) |
| ---------------- | ----------- | -------------- |
| Content Storage  | ✅          | ✅             |
| UnixFS           | ✅          | ✅             |
| CID v0/v1        | ✅          | ✅             |
| Bitswap 1.2.0    | ✅          | ✅             |
| Kademlia DHT     | ✅          | ✅             |
| HTTP Gateway     | ✅          | ✅             |
| RPC API          | ✅          | ✅             |
| PubSub           | ✅          | ✅             |
| IPNS             | ✅          | ✅             |
| GraphSync        | ✅          | ✅             |
| Circuit Relay v2 | ✅          | ✅             |
| AutoNAT          | ✅          | ✅             |
| Language         | Dart        | Go             |
| Mobile Support   | ✅ Flutter  | ❌             |
| Web Support      | ✅ Dart Web | ❌             |

---

## License

MIT License — see [LICENSE](LICENSE) file for details

---

## Credits

Built with:

- [dart_libp2p](https://pub.dev/packages/dart_libp2p) — Native P2P networking
- [pointycastle](https://pub.dev/packages/pointycastle) — Cryptography
- [hive](https://pub.dev/packages/hive) — Storage
- [protobuf](https://pub.dev/packages/protobuf) — Protocol buffers

Inspired by:

- [go-ipfs (Kubo)](https://github.com/ipfs/kubo) — Reference implementation
- [js-ipfs](https://github.com/ipfs/js-ipfs) — JavaScript implementation

---

## Support

- **Issues**: [GitHub Issues](https://github.com/jxoesneon/IPFS/issues)
- **Discussions**: [GitHub Discussions](https://github.com/jxoesneon/IPFS/discussions)
- **IPFS Docs**: [docs.ipfs.tech](https://docs.ipfs.tech/)

---

**Ready to build decentralized applications? Get started with dart_ipfs today!** 🚀
