IPFS Server in Dart ![IPFS Logo](lib/assets/logo.svg)

Welcome to the **IPFS Server in Dart** repository! This is a **WIP** project that aims to deliver a robust, production-ready server leveraging Dart for seamless integration with the IPFS network.

[![GitHub issues](https://img.shields.io/github/issues/jxoesneon/IPFS)](https://github.com/jxoesneon/IPFS/issues)
[![GitHub forks](https://img.shields.io/github/forks/jxoesneon/IPFS)](https://github.com/jxoesneon/IPFS/network)
[![GitHub stars](https://img.shields.io/github/stars/jxoesneon/IPFS)](https://github.com/jxoesneon/IPFS/stargazers)
[![GitHub license](https://img.shields.io/github/license/jxoesneon/IPFS)](https://github.com/jxoesneon/IPFS/blob/main/LICENSE)

---

## 🚀 Features

**🌐 Core IPFS Functionality:**
 - 🔗 Content addressing with CIDv0 and CIDv1 support
 - 🌲 Merkle DAG with HAMT and trickle-dag support
 - 📦 Block storage with pluggable datastores
 - 📁 Directory handling with UnixFS

**📡 Networking and Communication:**
 - 👥 libp2p-based P2P using ```p2plib```
 - 🌍 Kademlia DHT with configurable parameters
 - 🔊 PubSub with topic-based messaging
 - 🔄 Circuit Relay for NAT traversal

**🧭 Content Routing:**
 - 🎯 DHT-based content routing with fallback strategies
 - 🖇️ DNSLink resolution with caching
 - 🔍 Provider record management

**💾 Data Management:**
 - ⏳ Persistent storage with configurable backends
 - 🛠️ IPLD with multiple codec support
 - 📡 Graphsync protocol implementation
 - 🗂️ CAR import/export functionality

**🔒 Security:**
 - 🔐 TLS with custom security configurations
 - 🔑 IPNS key management and signing
 - 🛡️ Input validation and sanitization
 - 📏 Configurable quota management

**📈 Monitoring and Management:**
 - 📊 Prometheus-compatible metrics
 - 📝 Structured logging with levels
 - 🛠 Comprehensive node management API

## 🏗 Architecture

The server follows a modular architecture with clear separation of concerns. The core components are:

### Core Components

```dart
// Example node initialization
final node = await IPFS.create(config);
await node.start();
```

Key components include:

**IPFSNode**: Central coordinator managing all subsystems
**DHTHandler**: Implements Kademlia DHT protocol
**BitswapHandler**: Handles block exchange protocol
**PubSubHandler**: Manages pub/sub messaging
**NetworkHandler**: Coordinates P2P communications
**DatastoreHandler**: Manages persistent storage

### Data Structures

The system uses several key data structures:

**CID**: Content identifiers with multihash support
**Block**: Raw data with associated CID
**MerkleDAGNode**: DAG nodes with links
**UnixFSNode**: File system representation

### Configuration

The system is highly configurable:

```dart
final config = IPFSConfig(
 enableDHT: true,
 enablePubSub: true,
 maxConnections: 100,
 datastorePath: './ipfs_data'
);
```

## 🛠 Getting Started

1. **Add dependency:**

```yaml
dependencies:
 dart_ipfs: 1.0.0
```

2. **Basic usage:**

```dart
import 'package:dart_ipfs/dart_ipfs.dart';

void main() async {
 final node = await IPFS.create();
 await node.start();

 // Add content
 final cid = await node.addFile(Uint8List.fromList(utf8.encode('Hello IPFS!')));
 print('Added file with CID: $cid');

 // Retrieve content
 final data = await node.get(cid);
 print('Content: ${utf8.decode(data!)}');

 await node.stop();
}
```

## 🤝 Contributing

Contributions are welcome! Please read our [Contributing Guidelines](CONTRIBUTING.md) first.

1. Fork the repository
2. Create your feature branch: ```git checkout -b feature/amazing-feature```
3. Commit your changes: ```git commit -m 'Add amazing feature'```
4. Push to the branch: ```git push origin feature/amazing-feature```
5. Open a Pull Request

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

