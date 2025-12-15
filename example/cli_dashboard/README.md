# IPFS CLI Dashboard (Project Neo)

A robust, "hacker-style" terminal interface for controlling `dart_ipfs`. This dashboard attempts to bring feature parity with the GUI version to the command line.

## Features
- **Matrix UI**: Raw ANSI output with scrolling logs and status panes.
- **Zero Dependencies**: Runs on the pure Dart VM (no Flutter/Xcode required).
- **Interactive**: Full keyboard control loop.

## Modes

### 1. Peer Manager `[P]`
- List all connected peers with latency stats.
- **[A]** Add Peer (Input Multiaddr).
- **[D]** Disconnect Peer.

### 2. PubSub Chat `[C]`
- Real-time decentralized chat.
- **[S]** Subscribe to topic.
- **[Enter]** Send message.

### 3. Files & Pinning `[F]`
- View pinned content.
- **[P]** Pin CID.
- **[U]** Unpin CID.

### 4. IPLD Explorer `[E]`
- Traverse the Merkle DAG.
- **[G]** Go to CID.

### 5. Settings `[H]` / `[M]`
- **[M]** Toggle Gateway Mode (Internal/Public/Local/Custom).
- **[H]** View Node Stats & Bandwidth.

## Running the App
```bash
dart pub get
dart run bin/main.dart
```

## Global Controls
- **[Q]** Quit
- **[Tab]** Switch Focus / Help

