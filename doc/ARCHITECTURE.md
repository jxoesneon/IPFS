# Architecture Guide

`dart_ipfs` is designed with modularity, scalability, and multi-platform support at its core. It follows a **Manager-Handler** architectural pattern to ensure that different responsibilities are isolated and easily testable.

---

## Core Components

### 1. LifecycleManager
The `LifecycleManager` is the orchestrator of the entire node. It is responsible for:
- Initializing all specialized managers in the correct order.
- Managing the transition between states (Starting, Running, Stopping, Stopped).
- Ensuring graceful shutdowns by closing network connections and flushing storage buffers.

### 2. Specialized Managers
Each major functional area of IPFS is encapsulated within a dedicated manager:
- **ContentManager**: Handles UnixFS operations (add, cat, ls), MerkleDAG traversal, and pinning logic.
- **NetworkManager**: Manages P2P connectivity, Bitswap block exchange, and DHT routing.
- **ProtocolManager**: Orchestrates high-level protocols like PubSub, IPNS, and DNSLink resolution.
- **SecurityManager**: Handles identity (PeerId), cryptographic keys, and the encrypted keystore.
- **StorageManager**: Coordinates block storage and metadata persistence.

### 3. Platform Abstraction (IpfsPlatform)
The `IpfsPlatform` class is the key to multi-platform support. It provides a unified interface for platform-specific operations, shielding the core logic from the differences between `dart:io` (VM) and `dart:html`/`idb_shim` (Web).

- **IOPlatform**: Implementation for Windows, macOS, and Linux using `dart:io`.
- **WebPlatform**: Implementation for browsers using `idb_shim` and `package:http`.

### 4. Storage Providers
Storage is decoupled from the core through the `BlockStore` and `Datastore` interfaces.
- **FileStore (IO)**: Persists blocks as individual files or within a consolidated database (Hive) on the local filesystem.
- **IndexedDB (Web)**: Uses the browser's IndexedDB via `idb_shim` for persistent, high-performance storage in a web environment.

---

## The Manager-Handler Pattern

Each Manager often delegates specific protocol logic to **Handlers**. For example:
- `NetworkManager` delegates Bitswap logic to the `BitswapHandler`.
- `ContentManager` delegates IPLD codec logic to specialized `IPLDCodec` strategies (DagPb, DagCbor, etc.).

This allows the project to support new protocols or codecs by simply registering a new handler/strategy without modifying the core manager logic.

---

## Networking Stack

`dart_ipfs` leverages a native Dart implementation of **libp2p**:
1. **Transports**: TCP, WebSocket, WebRTC, and WebTransport.
2. **Security**: Noise protocol for encrypted handshakes.
3. **Muxing**: Yamux and Mplex for stream multiplexing.
4. **Discovery**: mDNS (local) and DHT (global).

---

## Data Flow: Adding a File

1. **API**: User calls `IPFSNode.add(data)`.
2. **ContentManager**: Chunks the data according to the UnixFS strategy.
3. **StorageManager**: Computes the CID and stores the blocks in the local `BlockStore`.
4. **NetworkManager**: Announces the new CID to the DHT so other peers can find it.
5. **Bitswap**: Serves the blocks to requesting peers.
