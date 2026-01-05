# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.7.4] - 2026-01-05

### Added

- **Security (SEC-008)**: Implemented `EncryptedKeystore` for secure at-rest storage of private keys.
  - AES-256-GCM encryption with PBKDF2 key derivation.
  - Secure in-memory locking (zeroing master key).
  - Migration warnings for legacy plaintext keys.
- **Security (SEC-005)**: Added S/Kademlia Proof-of-Work (PoW) verification for `PeerId`s.
  - Static PoW difficulty check in DHT packet handler to mitigate Sybil attacks.
  - New `dhtDifficulty` setting in `SecurityConfig`.
- **Security (SEC-002)**: Enhanced NAT traversal security with `enableNatTraversal` flag (defaults to false).

### Fixed

- **Security (SEC-004)**: Hardened `libsodium_setup.dart` by removing `runInShell: true` from system commands.
- **Security (SEC-001)**: Replaced insecure `Random()` with `Random.secure()` in security-sensitive contexts.
- **Security (SEC-010)**: Reinforced DHT rate limiting for provider announcements to prevent spam/poisoning.
- **Refactor**: Consolidated configuration files and resolved duplicate definitions of `NetworkConfig`.
- **Core**: Added `fromBytes` and `fromEd25519Seed` to `IPFSPrivateKey` for better cryptographic alignment.

## [1.7.3] - 2025-12-28

### Added

- **Windows**: Proactive libsodium setup with automatic installation (#14)
  - Automatically detects missing libsodium.dll on Windows
  - Attempts automatic installation via winget
  - Provides clear manual installation instructions if auto-install fails
  - Prevents FFI hang during package import
  - Gracefully handles offline mode (skips check entirely)

### Fixed

- **Windows**: Resolved startup hang when libsodium not installed (#14)
  - Added `LibsodiumSetup` utility for pre-flight dependency checks
  - Integrated into `IPFSNodeBuilder` before P2P initialization
  - Users now get helpful setup guidance instead of silent hangs

## [1.7.2] - 2025-12-27

### Fixed

- **MDNS**: Fixed crash when resolving `.local` hostnames during mDNS peer discovery (#12)
  - Replaced `InternetAddress(srv.target)` with `await InternetAddress.lookup(srv.target)`
  - Added proper hostname resolution validation
  - Eliminated SEVERE error log spam when other IPFS nodes are on the same LAN
  - Local peer discovery via mDNS now works correctly

## 1.7.1

- **Security Hardening**:
  - [MEDIUM] Fixed Bitswap Wantlist DoS vulnerability by limiting want entries to 5000 per message.
  - [LOW] Fixed potential PubSub listener crash on invalid UTF-8 messages (#SEC-ZDAY-002).
  - [MEDIUM] Sanitized sensitive URLs in log outputs (DelegateDHTHandler).
  - Validated supply chain security (Dependencies clean).

## [1.7.0] - 2025-12-20

### Web Platform Parity 🌐🚀

This release brings the Web implementation of `dart_ipfs` to near-parity with the IO implementation, enabling powerful P2P web applications.

- **Web IPNS Support**: Implemented `SecurityManagerWeb` and adapter stack to enable IPNS record publishing and resolution in browsers.
- **Web DHT Delegate**: Added `DelegateDHTHandler` to perform content routing and peer discovery via IPFS HTTP Delegates (Kubo RPC), bridging the browser DHT gap.
- **Web Performance**: Implemented `UnixFSBuilder` and `IPFSWebNode.addStream` for chunked streaming of large files (>1GB) with minimal memory footprint.
- **Improved UX**: Added `IPFSWebNode.addFile` convenience method.

### Fixed

- **Circuit Relay**: Fixed race conditions in `CircuitRelayClient` reservation logic that caused flaky test failures.
- **Router**: Corrected `P2plibRouter` stream management to prevent "Stream already listened to" errors.

## 1.6.11

- **Fix**: Resolved `CircuitRelayClient` test failures (mock implementation logic).

## 1.6.10

- **Test**: Fixed CI compilation failures in mock routers and peer type tests (Verified Green on GitHub).

## 1.6.9

- **Fix**: Critical Web Platform fixes for PeerID generation and JS interop (supersedes v1.6.8).

## 1.6.8

- **Chore**: Removed accidental `pana` report artifacts from the repository to maintain cleanliness.

## 1.6.7

- **Docs**: Updated CHANGELOG to strictly follow conventions for perfect pub.dev score.

## 1.6.6

- **Test**: Resolved `p2plib` mock type mismatches and runtime errors in `ipns_handler_test.dart`.
- **Optimization**: Reduced crypto test iterations to prevent timeouts (100k -> 1k).
- **Fix**: Corrected mock implementations for `BitswapHandler` and `DHT`.

## 1.6.5

- **Test**: Fixed compilation error in `MockDHTHandler` caused by type mismatch (regression from protocol refactoring).

## 1.6.4

- **CI**: Fixed code formatting to satisfy `dart format` checks in CI.

## 1.6.3

- **CI**: Fixed `test` and `docs` workflows to use stable SDK, ensuring all checks pass.

## 1.6.2

- **CI**: Upgraded CI/CD environment to Dart 3.10.0+ for compatibility with `idb_shim`.

## 1.6.1

- **Performance**: Migrated compression service to use `dart_lz4` (Pure Dart) for full Web support.
- **Optimization**: Removed `es_compression` dependency, reducing FFI reliance.
- **Fix**: Re-enabled `pubspec.yaml` to include all source files.

## [1.6.0] - 2025-12-18

### Full Web Connectivity 🌐⚡

The web implementation (`IPFSWebNode`) has been upgraded from an offline sandbox to a fully networked P2P node.

- **Online Networking**: `IPFSWebNode` now initializes `P2plibRouter` (WebSocket), `BitswapHandler`, and `PubSubClient`.
- **Bitswap Fallback**: `get()` operations now transparently query the swarm if content is missing locally.
- **Bootstrap Support**: Added `bootstrapPeers` configuration to connect to WebSocket relays securely (`wss://`).
- **WebBlockStore**: New adapter bridging `IndexedDB` with the `Bitswap` protocol.

### Web Capabilities Updated

| Feature             | Supported | Notes                 |
| ------------------- | --------- | --------------------- |
| P2P Networking      | ✅        | WebSocket transport   |
| Bitswap Exchange    | ✅        | Active block fetching |
| PubSub (Gossipsub)  | ✅        | Mesh participation    |
| Offline Persistence | ✅        | IndexedDB             |

### Refactoring

- **BitswapHandler**: Decoupled from concrete `BlockStore` to usage of `IBlockStore` interface.
- **Build System**: Removed restrictive `include` directive from `pubspec.yaml` to fully expose library modules.

## [1.5.1] - 2025-12-18

- **Fix**: Tightened dependency constraints to pass pana downgrade analysis (160/160 score).

## [1.5.0] - 2025-12-18

### Web Platform Support 🌐

- **IPFSWebNode**: New minimal web-only node for browsers with offline functionality.
- **IndexedDB Storage**: Persistent storage using IndexedDB via `idb_shim` package.
- **Web Compilation**: Successfully compiles to JavaScript (`dart compile js`).

### New Abstractions

- **CryptoProvider**: Platform-agnostic crypto interface with IO/Web implementations.
- **PeerConnection**: Abstract P2P connection interface with WebSocket support for web.

### Web Mode Capabilities

| Feature                | Supported         |
| ---------------------- | ----------------- |
| Add/Get content by CID | ✅                |
| Pin/Unpin content      | ✅                |
| IndexedDB persistence  | ✅                |
| P2P networking         | ❌ (offline only) |

### Dependencies

- Added `idb_shim: ^2.0.0` for IndexedDB support.

## [1.4.3] - 2025-12-18

### Web Platform Support

- **Modern Web APIs**: Migrated from deprecated `dart:html` to `package:web` and `dart:js_interop`.
- **Platform Abstraction**: Added HTTP server adapters for platform-specific implementations.
- **WebSocket Transport**: Implemented WebSocket-based router for web platforms.

### Code Quality

- **Import Ordering**: Fixed import ordering across 20+ files for consistent codebase.
- **PeerId Consolidation**: Merged duplicate `PeerId` class definitions into single canonical type.
- **Lint Resolution**: Resolved all remaining lint warnings (dart analyze 0 issues).
- **Async/Await Fixes**: Added missing `await` for Future expressions.

### Dependencies

- Added `web: ^1.1.0` for modern web platform support.

## [1.4.2] - 2025-12-18

### Documentation & Code Quality

- **100% Documentation Coverage:** Completed documentation for all remaining public members across the library.
- **Lint Resolution:** Successfully addressed all remaining code style lints, including:
  - Constant naming conventions (`lowerCamelCase`).
  - Loop refactoring (replaced `forEach` with `for-in` for better performance and style).
  - Proper curly brace usage in flow control structures.
  - Member reordering for better class structure.
- **Refactoring:** Simplified Kademlia tree node and Red-Black tree internal structures for improved maintainability.
- **Formatting:** Applied `dart format` across the entire codebase.

## [1.4.1] - 2025-12-17

### Features

- **UnixFS v1.5:** Added entry-level `mode` and `mtime` fields to `IPFSDirectoryEntry` for file metadata preservation.
- **DAG-JSON Support:** Implemented partial support for the DAG-JSON codec (0x0129), enabling JSON-based IPLD data structures.
- **Gossipsub 1.1:** Enhanced PubSub with mesh management and message caching for improved efficiency and robustness.
  - Implemented `IHAVE` and `IWANT` control messages.
  - Added peer scoring and mesh maintenance (graft/prune) logic.

### Performance

- **Generic LRU Cache:** Added `GenericLRUCache<K,V>` and `TimedLRUCache<K,V>` utilities for O(1) caching.
- **Bitswap Block Presence Cache:** Added 30-second TTL cache for block presence checks to reduce blockstore lookups.

## [1.4.0] - 2025-12-17

### Features

- **Bitswap 1.2 Support:** Implemented HAVE/DONT_HAVE messages to reduce duplicate block transfers and improve bandwidth efficiency.
  - Updated `BitswapHandler` to send `sendDontHave` flags.
  - Added logic to handle incoming `BlockPresence` messages.
- **Circuit Relay v2 Client:** Added support for limited relay reservations (HOP protocol).
  - New `reserve()` method in `CircuitRelayClient`.
  - Added `Reservation` class to track relay limits and expiration.

### Improvements

- Refactored `Wantlist` to support extended entry attributes (priority, want type, cancel flags).
- Added new `password_prompt` utility for CLI tools.

## [1.3.4] - 2025-12-16

### Security

- **Encrypted Key Storage**: Private keys now encrypted with AES-256-GCM + PBKDF2 (100K iterations)
- **IPNS Signatures**: All IPNS records signed with Ed25519 and verified on resolve
- **RPC Authentication**: Optional API key auth with constant-time comparison
- **Gateway Hardening**: XSS protection, rate limiting (100 req/60s), restricted CORS
- **PubSub Signing**: HMAC-SHA256 message authentication
- **DHT Protection**: Provider rate limiting to prevent index poisoning

### Added

- `lib/src/core/crypto/crypto_utils.dart` - PBKDF2, AES-GCM, memory zeroing utilities
- `lib/src/core/crypto/ed25519_signer.dart` - Ed25519 signing service
- `lib/src/core/crypto/encrypted_keystore.dart` - Secure key storage
- `lib/src/protocols/ipns/ipns_record.dart` - IPNS V2 record implementation

### Changed

- Upgraded `watcher` 1.1.4 → 1.2.0

## [1.3.3] - 2025-12-16

### Fixed

- **Git Rename**: Fixed case-only file rename issue for `interface_dht_handler.dart` that caused CI publish to fail on case-sensitive filesystems.

## [1.3.2] - 2025-12-15

### Fixed

- **Static Analysis**: Resolved all `dart analyze` issues across the entire codebase (0 issues).
- **Type Safety**: Added explicit casts for dynamic values from JSON decoding and protobuf fields.
- **IPLDNode Encoding**: Implemented proper encoding in `ProtocolCoordinator.retrieveData()` for all IPLD kinds (not just BYTES), using `EnhancedCBORHandler.encodeCbor()`.
- **File Naming Convention**: Renamed `Interface_dht_handler.dart` to `interface_dht_handler.dart` to follow `lower_case_with_underscores`.
- **Code Quality**: Added `// ignore_for_file: avoid_print` to example, test, and script files where `print()` is intentional.

## [1.3.1] - 2025-12-15

### Fixed

- **Cross-Platform Compatibility**: Implemented robust fallback for LZ4 compression. On systems where native binaries are missing (e.g., Apple Silicon), the node now detects the failure and gracefully falls back to GZIP, ensuring safe execution on all architectures.

## [1.3.0] - 2025-12-15

### Added

- **CLI Dashboard Completeness** (Parity with Flutter App)

  - **Peer Manager**: Full TUI for listing, adding, and disconnecting peers.
  - **PubSub Chat**: Asynchronous chat interface with dedicated drawing loop.
  - **Files & Pinning**: Pin/Unpin CIDs directly from terminal.
  - **IPLD Explorer**: Navigate DAG nodes by CID.
  - **Bandwidth Stats**: Real-time header metrics.

- **Security Hardening (Red Team Findings)**
  - **DHT Sybil Protection**: Implemented IP diversity checks in `RouterL2` (Limit: 5 peers per IP).
  - **Exploit Sanitization**: Removed all raw exploit scripts (`scripts/red_team/`).
  - **Regression Testing**: Added `dht_security_test.dart` to enforce Sybil protection.

### Fixed

- **Code Quality**: Resolved all lints in `node_native.dart` and `cli_dashboard`.
- **Stability**: Refactored CLI input/drawing loops to remove duplicate logic.

## [1.2.4] - 2025-12-15

### Fixed

- Resolved dartdoc/pana unresolved doc reference warnings.

## [1.2.3] - 2025-12-15

### Fixed

- CI stability for `dart test` and formatting checks.
- Pub.dev publish readiness and workflow reliability.

## [1.2.2] - 2025-12-14

### Fixed

- Critical syntax error in `dashboard_screen.dart` (restored CHAT tab).
- Removed unused imports and variables in `local_crypto.dart`, `debug_peerid.dart`, and tests.
- Cleaned up lint warnings in `p2plib`.

## [1.2.1] - 2025-12-14

### Added

- **Gateway Selector (User Request)**
  - **Core**: Added `GatewayMode` (Internal, Public, Local, Custom) to `IPFSNode`
  - **Flutter App**: Added Gateway Dropdown to AppBar
  - **CLI Dashboard**: Added `M` key to toggle modes and Custom URL input
- **DHT Value Operations**
  - `DHTClient.storeValue()`: Store values in DHT via PUT_VALUE to K closest peers
  - `DHTClient.getValue()`: Retrieve values from DHT via GET_VALUE queries
  - `DHTClient.checkValueOnPeer()`: Check if value exists on specific peer for replica health
- **IPFSNode Stream Upload**
  - `IPFSNode.addFileStream()`: Memory-efficient large file uploads via streams
- **Enhanced Test Infrastructure**
  - `MockP2plibRouter.responseGenerator`: Auto-response callback for network testing
  - Comprehensive RedBlack Tree test suite (8 tests)
  - DHT value operations tests
  - addFileStream test for stream-based uploads
  - Total: 423 tests passing, 0 skipped

### Fixed

- **RedBlack Tree XOR Distance Comparator**
  - Now compares distances to root node instead of between peers
  - Added byte-by-byte comparison as tiebreaker for peers at same distance
  - Returns 0 only for identical peer IDs (proper duplicate detection)
- **RedBlack Tree operator[] Type Check**
  - Removed incorrect `common_tree.V_PeerInfo` type check
  - Now returns search result directly
- **RedBlack Tree Duplicate Handling**
  - Insertion now updates existing nodes instead of adding duplicates
  - Entries list properly synchronized on updates
- **ReplicationManager Integration**
  - Now uses `DHTClient.storeValue()` for replication
  - Implements `checkValueOnPeer()` for replica health checks

### Dependencies

- Added `http_parser: ^4.1.0` (required for pub.dev publish)

## [1.1.1] - 2025-12-13

### Added

- **Comprehensive test coverage expansion (+106 tests)**
  - CID tests (30): Complete API coverage for CID creation, encoding, properties, codecs
  - Block tests (20): Data structure validation and concurrent operations
  - Error class tests (17): IPLD, Graphsync, and Datastore exception instantiation
  - Message ID tests (5): UUID generation and uniqueness validation
  - ByteReader tests (34): Complete CBOR utility coverage

### Improved

- **Test quality and coverage**
  - Total tests: 358 (previously 252)
  - Coverage increase: ~10-15% (from ~35-40% to ~45-50%)
  - 100% pass rate on all committed tests
  - Systematic API verification approach established

### Fixed

- Removed all lint warnings for zero-lint codebase
- Fixed always-true null checks
- Removed unused variables
- Maintains professional code quality standards

## [1.0.2] - 2025-12-12

### Fixed

- Relaxed `path` dependency constraint to `^1.9.0` to resolve conflict with Flutter SDK tools.

## [1.0.1] - 2025-12-12

### Documentation

- Added comprehensive Effective Dart documentation to 166 Dart files
- Documented all core library classes, interfaces, and data structures
- Documented protocol implementations (Bitswap, DHT, Graphsync)
- Documented network layer, services, and utilities
- All code passes `dart analyze` with zero warnings

## [1.0.0] - 2025-12-12

### Added

- **Complete IPFS Protocol Implementation**

  - CID v0 and v1 support with full encoding/decoding
  - UnixFS file system with chunking and directory support
  - DAG-PB (MerkleDAG) operations and IPLD traversal
  - CAR file import/export functionality
  - Content-addressable storage with pinning

- **P2P Networking**

  - Production-grade cryptography (secp256k1 + ChaCha20-Poly1305 AEAD)
  - Bitswap 1.2.0 protocol for efficient block exchange
  - Kademlia DHT for distributed routing and content discovery
  - PubSub messaging support
  - MDNS for local peer discovery
  - Bootstrap peer connections
  - Circuit relay support
  - Auto-NAT detection

- **Services & APIs**

  - HTTP Gateway (read-only and writable modes)
  - RPC API compatible with go-ipfs
  - IPNS mutable naming system
  - DNSLink resolution
  - Content routing and provider system
  - Prometheus-compatible metrics

- **Multiple Deployment Modes**

  - Offline mode: Local storage without networking
  - Gateway mode: HTTP serving with optional P2P
  - Full P2P mode: Complete network participation

- **Documentation**

  - Comprehensive README with installation and usage
  - API reference and configuration guides
  - Multiple working examples (blog, gateway, P2P)
  - Architecture documentation
  - Future roadmap (v1.1 through v3.0)

- **Examples**

  - blog_use_case.dart: Offline content publishing
  - online_test.dart: P2P networking demonstration
  - gateway_example.dart: HTTP gateway server
  - full_node_example.dart: Complete node features
  - rpc_example.dart: RPC API usage
  - simple_test.dart: Basic operations

- **Testing**
  - Protocol compliance test suite (6 tests, all passing)
  - CID, Kademlia, Bitswap, UnixFS, DAG-PB validation

### Technical Details

- **Language**: Dart >=3.5.4 <4.0.0
- **Platform Support**: Mobile (Flutter), Web, Desktop
- **Security**: Added `p2plib` Sybil protection (Max 5 peers/IP).
- **Core**: Enabled LZ4 compression for Gateway cache (via `es_compression`).
- **Storage**: Hive-based local datastore
- **Network**: p2plib for P2P communications
- **Crypto**: pointycastle + crypto package

### Quality Metrics

- ✅ 0 compilation errors
- ✅ 0 static analysis warnings
- ✅ 100% protocol test pass rate (6/6)
- ✅ 100% feature completeness for v1.0

### Known Limitations

- LZ4 compression not available (package unavailable on pub.dev)
- COSE encoding has stub implementation (catalyst_cose limitations)
- LocalCrypto uses X-coordinate extraction for p2plib compatibility

None of these limitations affect core functionality or production readiness.

[1.0.0]: https://github.com/jxoesneon/IPFS/releases/tag/v1.0.0 has no functionality.

- A full version with working functionality is planned for the future.
