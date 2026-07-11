# dart_ipfs

A complete, production-ready IPFS (InterPlanetary File System) implementation in Dart, supporting offline, gateway, and full P2P modes. Built for a seamless multi-platform experience.

[![pub package](https://img.shields.io/pub/v/dart_ipfs.svg)](https://pub.dev/packages/dart_ipfs)
[![Dart](https://img.shields.io/badge/dart-%3E%3D3.10.0-blue.svg)](https://dart.dev/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A pure-Dart IPFS node supporting Dart VM (Windows, macOS, Linux, iOS, Android) and Web (Chrome, Firefox, Safari). The `IpfsPlatform` abstraction automatically handles storage (File System vs. IndexedDB) based on the target platform.

---

## Multi-Platform Support

| Platform | Runtime | Storage | Networking |
|----------|---------|---------|------------|
| **Windows** | Dart VM | File System | TCP, QUIC (optional) |
| **macOS** | Dart VM | File System | TCP, QUIC (optional) |
| **Linux** | Dart VM | File System | TCP, QUIC (optional) |
| **iOS** | Dart VM | File System | TCP, QUIC (optional) |
| **Android** | Dart VM | File System | TCP, QUIC (optional) |
| **Web** | JS / Wasm | IndexedDB | WebSocket, WebRTC, WebTransport |

> **Notes:**
> - Native platforms share the `IpfsPlatformIO` (`dart:io`) implementation: local file system storage, TCP as the primary P2P transport, and optional QUIC via `NetworkConfig.enableQuic` + the `dart_ipfs_quic` package.
> - Web uses `IpfsPlatformWeb` (`idb_shim` → IndexedDB). Browsers cannot listen on TCP/UDP directly; P2P connectivity relies on WebRTC (relay-signaled or WebRTC-Direct) and WebTransport dial-out, with WebSocket/WSS used for gateway and relay connectivity.
> - iOS and Android are supported through `dart:io` but are noted in the README "Known Limitations" as not yet optimized for battery and background execution.

---

## Documentation

- **[Architecture Guide](doc/ARCHITECTURE.md)** — Deep dive into the Manager-Handler pattern
- **[ACME Certificate Issuance](doc/ACME_CERTIFICATE_ISSUANCE.md)** — Automatic TLS certificate management
- **[API Reference](https://jxoesneon.github.io/IPFS/)** — Auto-generated Dart docs

---

## Table of Contents

- [What's New in v1.11](#whats-new-in-v111)
- [What's New in v1.10](#whats-new-in-v110)
- [Features](#features)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Use Cases](#use-cases)
- [Architecture](#architecture)
- [Security](#security)
- [Performance](#performance)
- [Known Limitations](#known-limitations)
- [Troubleshooting](#troubleshooting)
- [Examples](#examples)
- [Testing](#testing)
- [Contributing](#contributing)
- [Roadmap](#roadmap)
- [Comparison with go-ipfs](#comparison-with-go-ipfs)
- [License](#license)
- [Credits](#credits)
- [Support](#support)

---

## What's New in v1.11 (current: v1.11.6)

### Major Features

| Feature                 | Description                                                  |
| ----------------------- | ------------------------------------------------------------ |
| **WebRTC Multiplexing** | Native browser p2p transport using independent `DataChannel`s per libp2p stream (`lib/src/transport/webrtc/`). |
| **Bitswap 1.2.0**       | Smart routing via `_providersForBlock` tracking and `HAVE`/`DONT_HAVE` message support (`lib/src/protocols/bitswap/bitswap_handler.dart`). |
| **Advanced IPLD**       | Native support for `DagCborCodec`, `DagJsonCodec`, and `DagJoseCodec` (`lib/src/core/ipld/codecs/`). |
| **Cross-Platform CI**   | 3,477+ tests passing on Ubuntu, macOS, and Windows as of v1.11.6. |
| **Security Parity**     | `SecurityManager` and `SecurityManagerWeb` share `EncryptedKeystore` for rate-limiting, auth tracking, and key management. |

---

## What's New in v1.10.0

### Major Features

| Feature                 | Description                                                  |
| ----------------------- | ------------------------------------------------------------ |
| **IpfsPlatform**        | Unified `IpfsPlatform` abstraction with IO and IndexedDB-backed web implementations (`lib/src/platform/`). |
| **IndexedDB Storage**   | Production-ready persistent storage for Web browsers via `idb_shim` (`IpfsPlatformWeb`). |
| **SecurityManager**     | Multi-platform encrypted keystore (`EncryptedKeystore`) for secure identity management. |
| **Kubo Interop**        | P0/P1 Kubo interoperability tests for CAR, Bitswap, Gateway, DHT, and IPNS (continuous, not 100% protocol compliance). |
| **Web CI Build**        | Flutter web build validated in CI (`build.yml`); core web-node unit tests cover browser-specific behavior. |

---

## Features

### Core IPFS Functionality

- **Content-Addressable Storage**: CID v0 and v1 support
- **UnixFS**: File system implementation with chunking and HAMT sharded directories
- **DAG-PB**: MerkleDAG operations and IPLD traversal
- **CAR Files**: CAR v1/v2 import/export and streaming reader
- **Pinning**: Direct, recursive, and indirect pin management
- **Mutable File System (MFS)**: Kubo-compatible `/ipfs files` operations

### Networking & NAT Traversal

- **Bitswap 1.2.0**: Efficient block exchange with wantlist management
- **Kademlia DHT**: Distributed hash table for peer/content routing
- **AutoNAT**: Automatic NAT type detection with dialback verification
  - Direct connectivity testing
  - Symmetric NAT detection
  - Periodic dialback verification
- **UPnP/NAT-PMP**: Automatic port mapping via `NatTraversalService`
- **Circuit Relay v2**: Hole-punching via relay peers
  - HOP protocol (relay serving and reservations)
  - STOP protocol (connection handling)
  - Transport forwarding
- **libp2p Core**: Native TCP/Noise transport; optional QUIC probe, WebRTC, WebTransport; PNET private-network support
- **PubSub**: Gossipsub real-time messaging
- **mDNS**: Local peer discovery
- **Bootstrap Peers**: Network connectivity initialization
- **Identify Protocol**: Peer metadata exchange (`/ipfs/id/1.0.0`)
- **DCUtR / Hole Punching**: Direct connection upgrade through relay
- **Connection Manager (Cuttlefish)**: Tagged, prioritized connection pruning

### Services

- **HTTP Gateway**: Read-only gateway with path and subdomain resolution
  - Writable gateway mode not yet implemented
- **Trustless Gateway Response Formats**: `raw`, `car`, `ipns-record`, `dag-json`, `dag-cbor`
- **RPC API**: Kubo-compatible subset with API-key authentication
- **IPNS**: Mutable naming system with Ed25519 signatures
- **DNSLink**: Domain-based content resolution
- **GraphSync**: Efficient graph synchronization protocol with IPLD selector support
- **Remote Pinning Service API**: Pinning-service-compliant client
- **Metrics**: Prometheus-compatible monitoring and export

### Security

- **Production Cryptography**
  - Ed25519 identity and IPNS signing
  - RSA and secp256k1 signing support
  - Noise protocol for transport encryption
  - SHA-256 content hashing
- **Encrypted Keystore (SEC-001)**
  - AES-256-GCM encryption
  - PBKDF2 key derivation
  - Memory zeroing on lock
  - Configurable key rotation (rotation logic partially stubbed)
- **Sybil Protection (SEC-005)**
  - Static Proof-of-Work difficulty check on PeerId
  - Configurable difficulty via `SecurityConfig.dhtDifficulty`
  - Full S/Kademlia crypto puzzle not yet implemented
- **Rate Limiting**
  - Per-client request throttling
  - Authentication attempt tracking
  - DHT provider announcement limits
- **Content Verification**
  - CID parsing and recomputation
  - Block integrity checks
- **Operator Denylist**: Optional content denylist with block/log actions

### Web Platform

- **`IPFSWebNode`**: Browser-compatible implementation
- **IndexedDB Storage**: Persistent local storage via `IpfsPlatform`
- **WebRTC & WebTransport**: Browser P2P transports
  - WebSocket transport not yet implemented
- **Bitswap & PubSub**: Full protocol support in browsers

---

## Quick Start

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  dart_ipfs: ^1.11.6
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

**Automatic Setup**: dart_ipfs automatically detects and installs libsodium via `winget` on first run.

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
import 'dart:convert';
import 'dart:typed_data';
import 'package:dart_ipfs/dart_ipfs.dart';

void main() async {
  final node = await IPFSNode.create(
    IPFSConfig(
      dataPath: './ipfs_data',
      offline: true, // No P2P networking
    ),
  );

  await node.start();

  // Add content
  final cid = await node.addFile(
    Uint8List.fromList(utf8.encode('Hello, IPFS!')),
  );
  print('Added with CID: $cid');

  // Retrieve content
  final retrieved = await node.cat(cid);
  if (retrieved != null) {
    print('Retrieved: ${utf8.decode(retrieved)}');
  }

  await node.stop();
}
```

#### Gateway Mode (HTTP Server)

```dart
import 'package:dart_ipfs/dart_ipfs.dart';

void main() async {
  final node = await IPFSNode.create(
    IPFSConfig(
      dataPath: './gateway_data',
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

  // Stop with Ctrl+C or call node.stop() when done
}
```

**Automatic TLS with ACME**: The gateway supports automatic certificate issuance via Let's Encrypt/ZeroSSL. See [ACME Certificate Issuance](doc/ACME_CERTIFICATE_ISSUANCE.md) for configuration details.

#### P2P Network Mode (Full Node)

```dart
import 'package:dart_ipfs/dart_ipfs.dart';

void main() async {
  final node = await IPFSNode.create(
    IPFSConfig(
      dataPath: './p2p_data',
      offline: false, // Enable P2P networking
      network: NetworkConfig(
        bootstrapPeers: [
          '/dnsaddr/bootstrap.libp2p.io/p2p/QmNnooDu7bfjPFoTZYxMNLWUQJyrVwtbZg5gBMjTezGAJN',
        ],
        enableNatTraversal: true, // UPnP/NAT-PMP
      ),
    ),
  );

  await node.start();
  print('P2P Node ID: ${node.peerID}');
  // Node participates in DHT, Bitswap, PubSub
}
```

#### Web Platform (Browser)

```dart
import 'dart:typed_data';
import 'package:dart_ipfs/dart_ipfs.dart';

void main() async {
  final node = IPFSWebNode(
    bootstrapPeers: ['wss://relay.node.address/p2p/...'],
  );
  await node.start();

  final cid = await node.add(Uint8List.fromList('Hello Web!'.codeUnits));
  print('Added: $cid');

  final data = await node.get(cid.toString());
  if (data != null) {
    print('Retrieved: ${String.fromCharCodes(data)}');
  }

  await node.stop();
}
```

---

## Configuration

### Full Configuration Reference

```dart
IPFSConfig(
  // Top-level toggles
  offline: false,
  enablePubSub: true,
  enableDHT: true,
  enableRPC: false,
  enableCircuitRelay: true,
  enableContentRouting: true,
  enableDNSLinkResolution: true,
  enableIPLD: true,
  enableGraphsync: true,
  enableMetrics: true,
  enableIpnsPubSub: false,
  enableLogging: true,
  enableStructuredLogging: false,
  enableQuotaManagement: true,

  // Storage paths
  dataPath: './ipfs_data',
  datastorePath: './ipfs_data',
  keystorePath: './ipfs_keystore',
  blockStorePath: 'blocks',

  // Logging
  debug: true,
  verboseLogging: true,
  logLevel: 'info',

  // Quotas and limits
  defaultBandwidthQuota: 1048576,
  maxConcurrentBitswapRequests: 10,
  maxSelectorDepth: 32,
  maxSelectorNodes: 10000,
  ipnsCacheSize: 1000,

  // Garbage collection
  garbageCollectionEnabled: true,
  garbageCollectionInterval: Duration(hours: 24),

  // Networking
  network: NetworkConfig(
    listenAddresses: ['/ip4/0.0.0.0/tcp/4001'],
    bootstrapPeers: [...],
    maxConnections: 50,
    connectionTimeout: Duration(seconds: 30),
    enableNatTraversal: false, // Set true to enable UPnP/NAT-PMP
    enableMDNS: true,
    enableWebTransport: true,
    enableWebRtc: true,
    enableQuic: false,
  ),

  // HTTP Gateway
  gateway: GatewayConfig(
    enabled: true,
    port: 8080,
    address: '0.0.0.0',
    writable: false,
    enableCache: true,
    cacheSize: 104857600, // 100MB default
  ),

  // DHT
  dht: DHTConfig(
    protocolId: '/ipfs/kad/1.0.0',
    bucketSize: 20,
    alpha: 3,
    maxProvidersPerKey: 20,
    requestTimeout: Duration(seconds: 30),
    reproviderEnabled: true,
    reproviderInterval: Duration(hours: 12),
    reproviderStrategy: 'pinned',
  ),

  // Storage
  storage: StorageConfig(
    baseDir: '.ipfs',
    blocksDir: 'blocks',
    datastoreDir: 'datastore',
    keysDir: 'keys',
    maxStorageSize: 10 * 1024 * 1024 * 1024, // 10GB
    enableGC: true,
    gcInterval: Duration(hours: 1),
    maxBlockSize: 2 * 1024 * 1024, // 2MB
  ),

  // Security
  security: SecurityConfig(
    enableTLS: false,
    enableKeyRotation: true,
    keyRotationInterval: Duration(days: 30),
    maxAuthAttempts: 3,
    enableRateLimiting: true,
    maxRequestsPerMinute: 100,
    dhtDifficulty: 0,
    enableDenylist: false,
    denylistRefreshInterval: Duration(hours: 1),
    denylistDefaultAction: 'block',
  ),

  // Bitswap
  bitswap: BitswapConfig(
    maxConcurrentRequests: 10,
    enableHttpFallback: false,
    httpFallbackGateways: [],
    p2pTimeout: Duration(seconds: 30),
    httpTimeout: Duration(seconds: 10),
  ),

  // Graphsync
  graphsync: GraphsyncConfig(
    enabled: true,
    defaultMaxDepth: 32,
    defaultMaxBlocks: 1024,
    defaultMaxBytes: 16 * 1024 * 1024,
    fallBackToBitswap: true,
  ),

  // Metrics
  metrics: MetricsConfig(
    enabled: true,
    collectionIntervalSeconds: 60,
    enablePrometheusExport: false,
    prometheusEndpoint: '/metrics',
  ),
)
```

---

## Use Cases

### 1. Decentralized Storage

```dart
import 'dart:io';
import 'dart:typed_data';

final file = File('document.pdf');
final Uint8List bytes = await file.readAsBytes();
final cid = await node.addFile(bytes);
print('Document CID: $cid');
// Content is permanently addressable by its CID
```

### 2. Content Distribution Network

```dart
final config = IPFSConfig(
  offline: false,
  enableContentRouting: true,
  gateway: GatewayConfig(
    enabled: true,
    port: 8080,
    enableCache: true,
    cacheSize: 100 * 1024 * 1024, // 100MB
  ),
);
```

### 3. Peer-to-Peer Applications

```dart
// Subscribe to a PubSub topic
await node.subscribe('my-topic');

// Listen to the shared PubSub message stream
node.pubsubMessages.listen((message) {
  if (message.topic == 'my-topic') {
    print('Received from ${message.sender}: ${message.content}');
  }
});

// Publish a message to the topic
await node.publish('my-topic', 'Hello, peers!');
```

### 4. Decentralized Websites

`node.addDirectory` expects a `Map<String, dynamic>` where each key is an entry name and each value is either a `Uint8List` (file data) or a nested `Map<String, dynamic>` (subdirectory).

```dart
import 'dart:io';
import 'dart:typed_data';

/// Recursively build a directory map from a local [Directory].
Future<Map<String, dynamic>> buildDirectoryMap(Directory dir) async {
  final entries = <String, dynamic>{};
  final prefix = '${dir.path}${Platform.pathSeparator}';

  await for (final entity in dir.list(recursive: true, followLinks: false)) {
    if (entity is File) {
      final relativePath = entity.path.replaceFirst(prefix, '');
      entries[relativePath] = await entity.readAsBytes();
    }
  }
  return entries;
}

final websiteDir = Directory('./my-website');
final websiteContent = await buildDirectoryMap(websiteDir);
final rootCID = await node.addDirectory(websiteContent);
print('Website root CID: $rootCID');
// Access via: http://<gateway>/ipfs/<rootCID>/index.html
```

---

## Architecture

`dart_ipfs` follows a **Manager-Handler** pattern, coordinated by a `LifecycleManager`. Each major responsibility (Content, Network, Protocol, Storage, Security, and MFS) is encapsulated by a specialized manager or handler, making the core modular and testable.

The **`IpfsPlatform`** abstraction layer shields the core logic from platform-specific differences, automatically switching between `dart:io` (Desktop/Server via `IpfsPlatformIO`) and `dart:html`/`idb_shim` (Browser via `IpfsPlatformWeb`) implementations.

```
┌─────────────────────────────────────┐
│         Application Layer            │
│   (Your Dart/Flutter Application)    │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│         dart_ipfs Public API       │
│  (IPFSNode / IPFSWebNode Facade    │
│   & IpfsPlatform abstraction)        │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│         Service / Manager Layer      │
│  ContentManager  │  NetworkManager   │
│  ProtocolManager │  SecurityManager  │
│  MFSManager      │  LifecycleManager │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│         Handler / Protocol Layer     │
│  DatastoreHandler                    │
│  Bitswap │ DHT │ GraphSync          │
│  IPNS    │ PubSub │ Identify │ Ping │
│  AutoNAT │ DCUtR  │ Peering          │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│         Transport Layer              │
│  Native libp2p (ipfs_libp2p)         │
│  TCP / WebSocket / WebRTC            │
│  WebTransport / Circuit Relay v2     │
│  Noise (encryption)                  │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│         Storage Layer                │
│  VM:  BlockStore + HiveDatastore     │
│       (filesystem-backed)              │
│  Web: WebBlockStore + IndexedDB      │
│       (via IpfsPlatformWeb)          │
└─────────────────────────────────────┘
```

### Key components

- **`IPFSNode`** (`lib/src/core/ipfs_node/ipfs_node.dart`) — Facade exposing the public API. It wires together managers via a `ServiceContainer` and registers them with the `LifecycleManager`.
- **`LifecycleManager`** (`lib/src/core/ipfs_node/lifecycle_manager.dart`) — Starts and stops registered `ILifecycle` services in the correct order.
- **Managers** (`lib/src/core/ipfs_node/`)
  - `ContentManager` — Files, directories, UnixFS operations, CAR import/export, and pinning metadata.
  - `NetworkManager` — Peer connectivity, DHT operations, Bitswap, and content routing.
  - `ProtocolManager` — PubSub, IPNS, and DNSLink resolution.
  - `SecurityManager` / `SecurityManagerWeb` (`lib/src/core/security/`) — Identity, encrypted keystore, key rotation, and rate limiting.
  - `DatastoreHandler` (`lib/src/core/ipfs_node/datastore_handler.dart`) — Wraps the lower-level `Datastore`/`BlockStore` for block persistence and CAR operations.
  - `MFSManager` (`lib/src/core/mfs/mfs_manager.dart`) — Mutable File System operations.
- **Protocol handlers** (`lib/src/protocols/`)
  - `BitswapHandler`, `DHTHandler`, `GraphSyncHandler`, `IPNSHandler`, `PubSubHandler`, `IdentifyHandler`, `PingHandler`, `AutoNATHandler`, `DCUtRHandler`, `PeeringService` / `PeeringHandler`, and `CuttlefishConnectionManager`.
- **Transport** (`lib/src/transport/`)
  - `Libp2pRouter` uses `package:ipfs_libp2p` with Ed25519 identity, Noise encryption, TCP, WebSocket, WebRTC, WebTransport, and Circuit Relay v2. A private-network transport wrapper is also available via `pnet/`.
- **Storage** (`lib/src/core/data_structures/blockstore.dart`, `lib/src/storage/hive_datastore.dart`, `lib/src/core/ipfs_node/web_block_store.dart`)
  - VM: `BlockStore` (in-memory index with filesystem persistence) plus `HiveDatastore` for key-value metadata.
  - Web: `WebBlockStore` backed by `IpfsPlatformWeb` / IndexedDB.

For more details, see the **[Architecture Guide](doc/ARCHITECTURE.md)**.

---

## Performance

> **Note:** The values below are **engineering targets / observed ballparks** from local development runs. They are **not** the result of a committed benchmark suite, and they vary significantly with platform, hardware, network conditions, and configuration. No `benchmark/` directory or continuous performance regression tests currently exist in the repo.

| Metric          | Claimed value            | Caveat |
| --------------- | ------------------------ | ------ |
| Content Hashing | ~50 MB/s (SHA-256)       | Depends on chunk size, Dart VM vs. web, and whether multihash/codec overhead is included. Actual throughput on web will be lower. |
| Block Storage   | ~1000 ops/sec (Hive)     | Measured locally on a Hive-backed `Datastore`/`BlockStore`. Performance drops with larger blocks, concurrent writers, or filesystem latency. |
| Gateway Latency | <10ms (local cache hit)  | Only when content is already in the in-memory `BlockStore` index. First fetch over HTTP or P2P is orders of magnitude slower. |
| P2P Handshake   | <100ms (secp256k1 ECDH)  | Misleading: the transport layer currently defaults to **Ed25519** identity and **Noise** for encryption. Handshake latency varies with NAT, relay, and key-type negotiation. |
| Memory Baseline | ~50MB + content cache    | Rough VM baseline observed in local runs. Web builds and large caches will consume significantly more memory. |

### Recommendations for accurate performance claims

1. Add a `benchmark/` suite (e.g., `benchmark/hashing_benchmark.dart`, `benchmark/blockstore_benchmark.dart`, `benchmark/handshake_benchmark.dart`) using `package:benchmark_harness` or custom `Stopwatch` loops.
2. Run benchmarks on CI-representative hardware and report median / p95 values.
3. Replace the table above with measured numbers once benchmarks are in place, or keep the table but clearly label every entry as **estimated / target** until then.

---

## Security

> **IMPORTANT**: Production use requires strict sandboxing.
> See `docker-compose.yml` for a secure reference implementation.

### Production Cryptography

The node uses the following algorithms and parameters:

| Component | Algorithm / Size | Notes |
| --- | --- | --- |
| Keystore encryption | AES-256-GCM | 12-byte nonce, 16-byte authentication tag |
| Key derivation | PBKDF2-HMAC-SHA256 | 100,000 iterations default; configurable per `unlock()` |
| Salt | 16 bytes | Generated randomly if not supplied |
| Peer identity keys | Ed25519 | 32-byte seeds / public keys |
| IPNS records | Ed25519 signatures | With expiration timestamps |
| PubSub messages | HMAC-SHA256 signing | Per `SECURITY.md` |
| Hashing | SHA-256 | Used for CIDs, PeerID derivation, and PoW checks |

### Recommended Deployment

1. **Immutable Filesystem**: Run with a read-only root
2. **Non-Root Execution**: Use UID > 1000 (e.g., `10001`)
3. **Network Isolation**: Bind ports to localhost (`127.0.0.1`) only
4. **IP Diversity Limits**: Max **2 peers/IP** to prevent routing-table poisoning (`KademliaRoutingTable.maxPeersPerIp`)

### Encrypted Keystore

```dart
// Unlock keystore with password
await node.securityManager.unlockKeystore('your-password');

// Keys are encrypted at rest with AES-256-GCM
// Master key derived via PBKDF2-HMAC-SHA256 (100K iterations default)
// Automatic memory zeroing on lock
```

- `SecurityManager.unlockKeystore` delegates to `EncryptedKeystore.unlock()`.
- Private seeds are decrypted only when `getSecureKey()` is called and are zeroed afterward.
- `lockKeystore()` clears the derived master key from memory via `CryptoUtils.zeroMemory()`.

### S/Kademlia PoW

```dart
// Optional Sybil protection in DHT (disabled by default)
SecurityConfig(
  dhtDifficulty: 16,  // Require SHA-256(PeerID) to have >=16 leading zero bits
)
```

- `dhtDifficulty` defaults to `0` (PoW verification disabled).
- When `dhtDifficulty > 0`, incoming DHT messages are rejected if `PeerId.verifyPoW(difficulty: …)` fails.
- Peers that fail the PoW check are not added to the routing table.

### Key Rotation & Rate Limiting

- `SecurityConfig.enableKeyRotation` defaults to `true` with a 30-day interval; the scheduler is active but the current `_rotateKeys()` implementation records metrics only and does not rotate stored keys.
- Rate limiting defaults to `maxRequestsPerMinute: 100` with a 1-minute window.
- Authentication throttling defaults to `maxAuthAttempts: 3` before a client is blocked.

---

## Known Limitations

- **Web Platform**: Browsers cannot open raw TCP/UDP listen sockets. WebRTC and WebTransport transports are implemented, but browser-to-browser connections still require a signaling path or relay (for example, via `/p2p-circuit/webrtc`). Direct WebRTC listening is not available in browsers; use `IPFSWebNode` for web/WASM deployments.
- **Mobile**: Not yet optimized for iOS/Android battery, background execution, or aggressive connection/thermal management.
- **QUIC Transport**: A pure-Dart QUIC foundation package (`dart_ipfs_quic`) is available and can be enabled via `NetworkConfig(enableQuic: true)`, but it defaults to `false`. Full Kubo/Helia-interoperable QUIC production workloads (complete libp2p TLS 1.3 handshake, stream multiplexing, and interop tests) are still being hardened.
- **MFS**: Core Mutable File System operations are implemented (`mkdir`, `cp`, `mv`, `rm`, `ls`, `stat`, `read`, `write`, `flush`, `chcid`, `sync`) and exposed through the RPC `/api/v0/files/*` surface. Advanced filesystem semantics such as symbolic links, hard links, `chmod`/`chown`, and atomic snapshots are not yet supported.

---

## Troubleshooting

### Node Won't Start (Windows)

**Symptom**: Hangs or fails during startup with a libsodium-related error.

**Reason**: P2P networking depends on `libsodium.dll` for cryptography.

**Solution**: `dart_ipfs` auto-detects missing `libsodium.dll` and attempts to install it via `winget` on first run. If automatic setup fails, install it manually:

```powershell
winget install jedisct1.libsodium
```

Alternatively, run in offline mode if you do not need P2P networking:

```dart
IPFSConfig(offline: true)
```

### Bonjour "Blocked from Local Security Authority" Popup (Windows 11)

**Symptom**: A popup stating `mdnsNSP.dll` is blocked from loading into the Local Security Authority.

**Reason**: Known compatibility issue between older Apple Bonjour versions and Windows 11's "LSA Protection" feature. It happens when the IPFS node attempts local peer discovery via mDNS.

**Solution**:
1. **Update Bonjour**: Ensure you have the latest version installed.
2. **Uninstall Bonjour**: Remove it if you don't need it (often bundled with iTunes or older Apple software).
3. **Disable mDNS**: If you don't need local peer discovery, disable it in your configuration:

    ```dart
    IPFSConfig(
      network: NetworkConfig(enableMDNS: false),
    )
    ```

### AutoNAT Reports Private / Restricted NAT

**Symptom**: Peers can't connect to you; AutoNAT reports a private or restricted NAT status.

**Solution**: Enable port mapping if your router supports UPnP/NAT-PMP:

```dart
IPFSConfig(
  network: NetworkConfig(enableNatTraversal: true),
)
```

> **Note**: Symmetric or carrier-grade NAT may still block direct inbound connections even with port mapping enabled. In that case, rely on circuit relays or QUIC/WebTransport outbound dials.

### DHT Queries Slow

**Symptom**: `findProviders` takes more than 30 seconds.

**Solution**:
1. Ensure bootstrap peers are reachable and that your node has active connections.
2. Check that `SecurityConfig.dhtDifficulty` isn't set higher than necessary. It lives under `security`, not `dht`, and defaults to `0` (disabled):

    ```dart
    IPFSConfig(
      security: SecurityConfig(dhtDifficulty: 0),
    )
    ```

    Higher values increase Sybil resistance but slow down provider-record verification.

### Gateway Returns 404

**Symptom**: Content is not found through the HTTP gateway even though it was added.

**Reason**: The gateway first looks in the local block store and then falls back to Bitswap (or HTTP gateway fallback, when configured). A 404 means the block is neither local nor retrievable from peers.

**Solution**: Ensure the content is pinned so it isn't garbage-collected:

```dart
await node.pin(cid);
```

If running online, also verify that providers for the CID are reachable and that Bitswap/HTTP fallback is enabled. If running offline, the content must exist in the local block store.

---

## Examples

See the `example/` directory for full applications and focused code samples.

### Full applications

- **[Premium Dashboard](example/ipfs_dashboard)**: Flutter cross-platform dashboard with a premium glassmorphism UI, node management, file system, and real-time logs.
- **[CLI Dashboard](example/cli_dashboard)**: Matrix-style terminal interface with peer management, PubSub chat, pinning, and IPLD exploration.

### Code samples

- [Basic Usage](example/dart_ipfs_example.dart)
- [Node Starter](example/main.dart)
- [Offline Blog](example/blog_use_case.dart)
- [P2P Networking](example/online_test.dart)
- [HTTP Gateway](example/gateway_example.dart)
- [Full Node](example/full_node_example.dart)
- [RPC API Server](example/rpc_example.dart)
- [Keystore Unlock](example/keystore_unlock_example.dart)
- [Simple Smoke Test](example/simple_test.dart)
- [P2P Setup Check](example/test_p2p_setup.dart)
- [Web P2P Chat](example/web_p2p_chat.dart)
- [WASM Build Entry Point](example/wasm_main.dart)

### Plugin examples

- [Bitswap Logging Observer](example/plugins/logging_observer/main.dart)
- [Metrics Emitter](example/plugins/metrics_emitter/main.dart)

Run a standalone example:

```bash
dart run example/blog_use_case.dart
dart run example/online_test.dart
```

---

## Testing

```bash
# Run all tests (VM)
dart test

# Run with compact reporter
dart test --reporter=compact

# Run tests in Chrome (Web)
dart test -p chrome

# Run with verbose/expanded output
dart test -r expanded

# Static analysis
dart analyze
```

Expected results (as of 2026-07-11):

- `dart analyze`: **0 errors**. Pre-existing warnings/infos outside the current work-package scope are tolerated.
- `dart test`: **3478 tests passing**, **8 skipped**, **0 failing** on this platform.

For full local verification:

```bash
make analyze && make test
```

In the monorepo workspace:

```bash
melos bootstrap
melos run test:all
```

---

## Contributing

Contributions welcome! Please:

1. Open an issue to discuss significant changes before starting work.
2. Fork the repository and create a feature branch.
3. Write tests for new features and bug fixes.
4. Ensure `dart analyze` and `dart test` pass.
5. Update relevant docs or specs if you change user-facing behavior.
6. Submit a pull request with a clear description.

---

## Roadmap

### Completed

- Core IPFS protocols (Bitswap, DHT, PubSub/Gossipsub)
- Offline, Gateway, and P2P modes
- Production cryptography
- Web platform support
  - WebSocket, WebRTC, and WebTransport
  - WebRTC-Direct for browser-to-browser P2P
- libp2p core migration
- Circuit Relay v2
- AutoNAT lifecycle integration
- Encrypted keystore
- S/Kademlia PoW
- 95%+ Router Coverage
- Mutable File System (MFS)
- IPFS Pinning Service API (Remote Pinning)
- CLI / daemon binary
- Docker & multi-arch images
- Interoperability test suite (Kubo/Helia)
- Plugin ecosystem (phase 1)

### In Progress

- Native QUIC transport (foundation implemented in `packages/dart_ipfs_quic`; Kubo interop still hardening)
- Mobile optimization (Flutter performance, battery, and background execution)
- GraphSync server-side MVP hardening
- Gossipsub protobuf wire-format compliance

### Planned

- Verified streaming (BLAKE3-style incremental verification)
- Advanced hole punching / AutoNATv2
- Multi-signature IPNS
- Content policy engine
- FUSE mount
- WebAssembly build
- Hardware Security Module (HSM) support
- Zero-knowledge proof support
- Marketplace integration (long-term)

---

## Comparison with go-ipfs

| Feature                | dart_ipfs             | go-ipfs (Kubo) |
| ---------------------- | --------------------- | -------------- |
| Content Storage        | Yes                   | Yes            |
| UnixFS                 | Yes                   | Yes            |
| CID v0/v1              | Yes                   | Yes            |
| Bitswap 1.2.0          | Yes                   | Yes            |
| Kademlia DHT           | Yes                   | Yes            |
| HTTP Gateway           | Yes                   | Yes            |
| RPC API                | Yes                   | Yes            |
| PubSub                 | Yes (Gossipsub)       | Yes            |
| IPNS                   | Yes                   | Yes            |
| GraphSync              | Yes (server-side MVP) | Yes            |
| Circuit Relay v2       | Yes                   | Yes            |
| AutoNAT                | Yes                   | Yes            |
| Mutable File System    | Yes                   | Yes            |
| Remote Pinning Service | Yes                   | Yes            |
| QUIC Transport         | Partial (stabilizing) | Yes            |
| Language               | Dart                  | Go             |
| Mobile Support         | Yes (Flutter)         | No             |
| Web Support            | Yes (Dart Web)        | No             |

---

## License

MIT License — see [LICENSE](LICENSE) file for details.

---

## Credits

Built with:

- [ipfs_libp2p](https://pub.dev/packages/ipfs_libp2p) — Native P2P networking
- [pointycastle](https://pub.dev/packages/pointycastle) — Cryptography
- [hive](https://pub.dev/packages/hive) — Storage
- [protobuf](https://pub.dev/packages/protobuf) — Protocol buffers

Inspired by:

- [go-ipfs (Kubo)](https://github.com/ipfs/kubo) — Reference implementation
- [js-ipfs](https://github.com/ipfs/js-ipfs) — JavaScript implementation (archived)

---

## Support

- **Issues**: [GitHub Issues](https://github.com/jxoesneon/IPFS/issues)
- **Discussions**: [GitHub Discussions](https://github.com/jxoesneon/IPFS/discussions)
- **IPFS Docs**: [docs.ipfs.tech](https://docs.ipfs.tech/)

---

For more information, see the [GitHub repository](https://github.com/jxoesneon/IPFS).
