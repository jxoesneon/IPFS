# IPFS Server in Dart

This repository contains a Dart implementation of an IPFS server. It aims to provide a robust, production-ready server that can seamlessly integrate with the IPFS network.

## Features

* **Core IPFS Functionality:**
    * Content addressing and CID generation
    * Merkle DAG representation and traversal
    * Block storage and retrieval
    * Directory listing and file fetching
* **Networking and Communication:**
    * libp2p-based peer-to-peer communication (using `p2plib`)
    * DHT (Distributed Hash Table) for content discovery
    * PubSub for real-time communication
    * Circuit Relay for NAT traversal
* **Content Routing:**
    * Content routing with DHT and alternative strategies
    * DNSLink support for name resolution
* **Data Management:**
    * Persistent data storage using a pluggable `Datastore`
    * IPLD (InterPlanetary Linked Data) resolution and processing
    * Graphsync for efficient data synchronization
    * CAR (Content Addressable aRchive) import and export
* **Security:**
    * TLS encryption for secure communication
    * Key management for IPNS
    * Input validation and sanitization
    * Quota management to prevent abuse
* **Monitoring and Management:**
    * Metrics collection and monitoring
    * Logging with configurable levels
    * Comprehensive node management capabilities

## Architecture

The server follows a modular architecture to promote flexibility and maintainability. The core component is the `IPFSNode` class, which orchestrates various sub-components and modules responsible for specific functionalities.

### Core Data Structures

These structures represent the fundamental data units within the IPFS system:

*   **`Block`:**  Encapsulates a block of data and its corresponding Content Identifier (CID).
*   **`Node`:** Represents a file or directory within the IPFS Merkle DAG (Directed Acyclic Graph).
*   **`Link`:**  Defines a connection between nodes in the DAG, enabling navigation and retrieval of linked content.

### IPFS Node Class (`IPFSNode`)

The `IPFSNode` class serves as the central component of the server, managing all other components and exposing the primary API for interacting with the IPFS network. It is responsible for:

*   **Initialization and Configuration:**  Loading configuration settings, initializing sub-components, and establishing network connections.
*   **Content Management:**  Handling content addition, retrieval, and storage, including directory listing and file fetching.
*   **Protocol Management:**  Managing various IPFS protocols such as Bitswap, DHT, PubSub, and Graphsync.
*   **Routing and Resolution:**  Providing content routing capabilities and resolving IPNS names and DNSLinks.
*   **Monitoring and Management:**  Collecting metrics, logging events, and offering node management functionalities.

### Sub-Components and Modules

The `IPFSNode` interacts with several sub-components and modules, each responsible for a specific function:

*   **`Bitswap`:**  Handles the exchange of blocks with other peers in the IPFS network.
*   **`Datastore`:** Provides persistent storage for blocks, allowing retrieval even after the server restarts.
*   **`Keystore`:** Manages IPNS key pairs, enabling the publishing and resolution of IPNS records.
*   **`DHTClient`:**  Interacts with the Distributed Hash Table (DHT) to discover peers and content.
*   **`PubSubClient`:**  Facilitates real-time communication and event propagation through the PubSub protocol.
*   **`CircuitRelayClient`:**  Enables NAT traversal using circuit relay, allowing nodes behind firewalls to connect.
*   **`ContentRouting`:**  Provides content routing capabilities, potentially using DHT or alternative strategies.
*   **`Graphsync`:**  Enables efficient synchronization of subgraphs within the IPFS DAG.
*   **`IPLDResolver`:** Resolves and processes InterPlanetary Linked Data (IPLD) links, facilitating interaction with diverse data formats.
*   **`DNSLinkResolver`:**  Resolves IPFS content addressed through DNSLink entries.
*   **`MetricsCollector`:**  Collects and exposes metrics related to server performance and resource usage.

This modular structure ensures that each component has a well-defined responsibility, making the codebase easier to understand, maintain, and extend.
## Getting Started

1. **Clone the repository:**

   ```bash
   git clone [invalid URL removed]
2. **Install dependencies:**

    ```bash
    cd ipfs
    dart pub get
    ````

3. **Run the example:**

    ```Bash
    dart example/main.dart
    ````

4. **Usage:**

    ```dart
    import 'package:ipfs/ipfs.dart';

    void main() async {
    // Create a new IPFS node
    final node = await IPFS.create();

    // Start the node
    await node.start();

    // Add a file
    final cid = await node.addFile(Uint8List.fromList(utf8.encode('Hello IPFS!')));
    print('Added file with CID: $cid');

    // Get the file content
    final data = await node.get(cid);
    print('File content: ${utf8.decode(data!)}');

    // Stop the node
    await node.stop();
    }
    ```

## Contributing
Contributions are welcome! Please feel free to open issues and submit pull requests.

## License
This project is licensed under the MIT License - see the LICENSE file for details.

