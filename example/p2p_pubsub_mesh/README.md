# Encrypted P2P PubSub Mesh

A production-pattern sample for `dart_ipfs` demonstrating **end-to-end-encrypted group messaging** over IPFS PubSub. Nodes that share a room passphrase derive the same AES-256-GCM key via PBKDF2 (`CryptoUtils.deriveKey`), exchange ciphertext frames with `publishData`, and authenticated-decrypt incoming `pubsubMessages`. Peers without the passphrase — including relays — see only ciphertext.

## What it demonstrates

- `subscribe` / `publishData` / `pubsubMessages`: binary-safe PubSub messaging (`PubSubMessage.data` carries raw ciphertext).
- `CryptoUtils.deriveKey` + `CryptoUtils.encrypt`/`decrypt`: PBKDF2-HMAC-SHA256 room-key derivation and AES-256-GCM authenticated encryption, all through the public `dart_ipfs` API.
- `EncryptedData.toBytes()` / `EncryptedData.fromBytes()`: a compact `[nonce ‖ ciphertext‖tag]` wire envelope.
- `connectToPeer` / `pubsubPeers`: explicit mesh formation and topic membership inspection.
- `CryptoUtils.zeroMemory`: wiping the derived key on shutdown.

## Running

```bash
cd example/p2p_pubsub_mesh
dart pub get
dart run bin/main.dart --message "hello mesh"
```

To form a real mesh, start a second instance in another terminal (or another machine) with the same topic and passphrase, and connect it to the first node's printed Peer ID:

```bash
dart run bin/main.dart --connect /ip4/127.0.0.1/tcp/4001/p2p/<PEER_ID>
```

Each node publishes one encrypted frame and listens for 8 seconds. Frames from peers holding a different passphrase fail the GCM tag check and are reported as undecryptable.

## Production notes

- The shared passphrase is a demo convenience. For real deployments, derive per-pair keys with an ECDH handshake over the libp2p channel and rotate the room key on membership changes.
- Combine with `IPFSConfig(privateNetworkPsk: ...)` for a pre-shared-key private swarm so ciphertext never leaves your mesh.
