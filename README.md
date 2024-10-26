# WIP IPFS Server in Dart ![IPFS Logo](lib/assets/logo.svg)

Welcome to the **IPFS Server in Dart** repository! This a **WIP** project that aims to deliver a robust, production-ready server leveraging Dart for seamless integration with the IPFS network.



[![GitHub issues](https://img.shields.io/github/issues/jxoesneon/IPFS)](https://github.com/jxoesneon/IPFS/issues)
[![GitHub forks](https://img.shields.io/github/forks/jxoesneon/IPFS)](https://github.com/jxoesneon/IPFS/network)
[![GitHub stars](https://img.shields.io/github/stars/jxoesneon/IPFS)](https://github.com/jxoesneon/IPFS/stargazers)
[![GitHub license](https://img.shields.io/github/license/jxoesneon/IPFS)](https://github.com/jxoesneon/IPFS/blob/main/LICENSE)

---

## 🚀 Features

- **🌐 Core IPFS Functionality:**
  - 🔗 Content addressing and CID generation
  - 🌲 Merkle DAG representation and traversal
  - 📦 Block storage and retrieval
  - 📁 Directory listing and file fetching

- **📡 Networking and Communication:**
  - 👥 libp2p-based peer-to-peer communication (utilizing `p2plib`)
  - 🌍 DHT for content discovery
  - 🔊 PubSub for real-time communication
  - 🔄 Circuit Relay for NAT traversal

- **🧭 Content Routing:**
  - 🎯 Content routing with DHT and alternative strategies
  - 🖇️ DNSLink support for name resolution

- **💾 Data Management:**
  - ⏳ Persistent data storage using a pluggable `Datastore`
  - 🛠️ IPLD resolution and processing
  - 📡 Graphsync for efficient data synchronization
  - 🗂️ CAR import and export

- **🔒 Security:**
  - 🔐 TLS encryption for secure communication
  - 🔑 Key management for IPNS
  - 🛡️ Input validation and sanitization
  - 📏 Quota management to prevent abuse

- **📈 Monitoring and Management:**
  - 📊 Metrics collection and monitoring
  - 📝 Logging with configurable levels
  - 🛠 Comprehensive node management capabilities

---

## 🏗 Architecture

This server is built with a modular architecture that enhances flexibility and maintainability. At its core is the `IPFSNode` class, coordinating various sub-components and modules to manage specific functionalities.

### 🌟 Core Data Structures

- **`Block`:** Represents a block of data alongside its CID.
- **`Node`:** Depicts a file or directory within the IPFS DAG.
- **`Link`:** Defines the connection between nodes in the DAG.

### 💡 IPFS Node Class (`IPFSNode`)

The primary conductor of our server, the `IPFSNode`, manages:

- **Initialization & Configuration:** Loads settings, initializes components, and establishes connections.
- **Content Management:** Oversees content addition, retrieval, and storage.
- **Protocol Management:** Handles Bitswap, DHT, PubSub, and Graphsync.
- **Routing & Resolution:** Manages content routing and resolves IPNS/DNSLinks.
- **Monitoring & Management:** Collects metrics, logs events, and offers management tools.

### ⚙ Sub-Components and Modules

Key components include:

- **`Bitswap`:** Facilitates block exchange with peers.
- **`Datastore`:** Provides persistent storage solutions.
- **`Keystore`:** Manages IPNS key pairs.
- **`DHTClient`:** Interfaces with the DHT for peer/content discovery.
- **`PubSubClient`:** Manages real-time communication.
- **`CircuitRelayClient`:** Ensures NAT traversal using circuit relay.
- **`ContentRouting`:** Enables diverse routing strategies.
- **`Graphsync`:** Synchronizes DAG subgraphs efficiently.
- **`IPLDResolver`:** Processes InterPlanetary Linked Data links.
- **`DNSLinkResolver`:** Handles IPFS content via DNSLink.
- **`MetricsCollector`:** Gathers performance and usage metrics.

This architecture promotes clear responsibility distribution, facilitating ease in understanding, maintaining, and extending the codebase.

---

## 🛠 Getting Started

1. **Clone the repository:**

   ```bash
   git clone https://github.com/jxoesneon/IPFS.git
   ```

2. **Install dependencies:**

    ```bash
    cd IPFS
    dart pub get
    ```

3. **Run the example:**

    ```bash
    dart example/main.dart
    ```

4. **Basic Usage:**

    ```dart
    import 'package:ipfs/ipfs.dart';

    void main() async {
      final node = await IPFS.create();
      await node.start();

      final cid = await node.addFile(Uint8List.fromList(utf8.encode('Hello IPFS!')));
      print('Added file with CID: $cid');

      final data = await node.get(cid);
      print('File content: ${utf8.decode(data!)}');

      await node.stop();
    }
    ```

---

## 🤝 Contributing

Contributions are always welcome! Feel free to open issues or submit pull requests.

### Development Process

1. Fork the repository.
2. Create a new branch: `git checkout -b feature/your-feature-name`.
3. Commit your changes: `git commit -m 'Add some feature'`.
4. Push to the branch: `git push origin feature/your-feature-name`.
5. Open a pull request.

---

## 📜 License

This project is under the MIT License. For more details, please refer to the [LICENSE](LICENSE) file.
