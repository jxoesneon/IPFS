# dart_ipfs_core

Stable core primitives for the [`dart_ipfs`](https://pub.dev/packages/dart_ipfs) IPFS implementation.

This package is the first extraction of the `dart_ipfs` monorepo (Phase 1). It contains only the low-level, spec-defined, low-churn building blocks that other packages and plugins need without pulling in the full protocol/service stack.

## What's in this package

| Module | Public API | Notes |
|--------|------------|-------|
| `cid` | `CID`, `MultibaseCodec`, `Multicodec`, `MultihashInfo` | CID v0/v1, multibase, multicodec, multihash helpers |
| `block` | `Block`, `IBlock`, `IBlockStore`, `InMemoryBlockStore` | Content-addressed blocks and a simple in-memory store |
| `codec` | `IPLDCodec`, `RawCodec`, `DagCborCodec`, `DagJsonCodec` | DAG-CBOR, DAG-JSON, and raw codecs |
| `crypto` | `CryptoUtils`, `Ed25519Signer` | Hashing, PBKDF2, AES-GCM, Ed25519 helpers |
| `data_structures` | `ImmutableBytes`, `TypedMap` | Small immutable helpers |

## What's NOT in this package

Protocol and service layers remain in the umbrella `dart_ipfs` package:

- Bitswap / DHT / libp2p
- HTTP Gateway / RPC API
- MFS / Pinning / Reprovider
- CLI / daemon

## Stability tiers

- **Tier 1 (stable):** `CID`, `MultihashInfo`, `MultibaseCodec`, `Block`, `IBlockStore`, `IPLDCodec` — these are the stable primitives extracted in this package.
- **Tier 2 (umbrella public):** `IPFSNode`, `GatewayServer`, `RPCServer`, `IPNSHandler` — public umbrella API but subject to change as the monorepo evolves.
- **Tier 3 (unstable):** deep imports into `package:dart_ipfs/src/...` — deprecated in v2.2.0 and will be removed in v3.0.0.

## Usage

```dart
import 'package:dart_ipfs_core/dart_ipfs_core.dart';

void main() async {
  final data = Uint8List.fromList([0, 1, 2, 3]);
  final cid = await CID.fromContent(data);
  print(cid.encode()); // bafkrei...

  final block = await Block.fromData(data);
  final store = InMemoryBlockStore();
  await store.put(block);
  final found = await store.get(cid);
  print(found?.cid.encode());
}
```

## Backward compatibility

The umbrella `dart_ipfs` package re-exports the public APIs of this package from `package:dart_ipfs/dart_ipfs.dart`. Existing consumers who use the public umbrella API do not need to change their imports.

Deep imports into `package:dart_ipfs/src/...` are **not** part of the public API and are deprecated in v2.2.0; they will be removed in v3.0.0.

## Versioning

`dart_ipfs_core` follows the same version as the umbrella `dart_ipfs` package (single release train). The umbrella package depends on a matching version of this package.

## License

MIT — see the repository LICENSE file.
