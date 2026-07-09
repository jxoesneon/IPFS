# dart_ipfs Monorepo Layout

This document describes the monorepo structure introduced in `dart_ipfs` v2.2.

## Overview

`dart_ipfs` is transitioning from a single umbrella package to a monorepo. Phase 1 extracts only the stable core primitives into a dedicated package, `dart_ipfs_core`, under `packages/`. Protocol and service layers remain in the umbrella package until they stabilize.

The umbrella package continues to re-export all public core APIs so existing consumers do not need to change their imports.

## Repository Layout

```
.
├── lib/                         # Umbrella package (dart_ipfs)
│   ├── dart_ipfs.dart           # Public barrel including re-exports
│   └── src/                     # Protocol and service implementations
│       ├── core/                # Core node logic (stays in umbrella)
│       ├── protocols/           # Bitswap, DHT, libp2p, etc.
│       ├── services/            # Gateway, RPC, IPNS, etc.
│       └── ...
├── packages/
│   └── dart_ipfs_core/          # Stable core primitives
│       ├── lib/
│       │   ├── dart_ipfs_core.dart
│       │   └── src/
│       │       ├── cid/         # CID, multibase, multicodec, multihash
│       │       ├── block/       # Block, BlockStore interfaces + in-memory store
│       │       ├── codec/       # DAG-CBOR, DAG-JSON, raw codecs
│       │       ├── crypto/      # Key utilities, hashing helpers
│       │       └── data_structures/ # Small immutable helpers
│       ├── test/
│       ├── pubspec.yaml
│       ├── README.md
│       └── analysis_options.yaml
├── melos.yaml                   # Workspace configuration
├── pubspec.yaml                 # Umbrella package
└── doc/
    └── monorepo.md              # This document
```

## Stability Tiers

| Tier | Location | Stability | Examples |
|------|----------|-----------|----------|
| Tier 1 — Stable Core | `packages/dart_ipfs_core/lib/` | Stable, spec-defined, low churn | `CID`, `Block`, `IBlockStore`, `IPLDCodec`, `CryptoUtils`, `Ed25519Signer` |
| Tier 2 — Umbrella Public | `lib/dart_ipfs.dart` | Public API, may evolve as services stabilize | `IPFSNode`, `GatewayServer`, `RPCServer`, `IPNSHandler` |
| Tier 3 — Unstable Internals | `lib/src/...` | Not part of public API; deprecated | Deep imports such as `package:dart_ipfs/src/core/cid.dart` |

## Dependency Direction

- `dart_ipfs_core` has **no dependency** on the umbrella package.
- The umbrella package depends on `dart_ipfs_core`.
- Protocol and service layers remain in the umbrella package until they stabilize.

## Versioning

`dart_ipfs_core` follows the umbrella package version exactly (single release train). Both packages share the same `CHANGELOG.md` entry and semver tag.

During development, the umbrella package uses a path dependency on `dart_ipfs_core`. After release, it uses a published version constraint.

## Workspace Tooling

[Melos](https://melos.invertase.dev/) is the recommended workspace tool. The root `melos.yaml` defines the workspace and common scripts.

Common commands:

```bash
# Bootstrap all packages
melos bootstrap

# Run tests in all packages
melos run test

# Run static analysis in all packages
melos run analyze
```

## Migration Guide

| Old Import | Recommended Replacement |
|------------|-------------------------|
| `package:dart_ipfs/src/core/cid.dart` | `package:dart_ipfs/dart_ipfs.dart` or `package:dart_ipfs_core/dart_ipfs_core.dart` |
| `package:dart_ipfs/src/core/data_structures/block.dart` | `package:dart_ipfs/dart_ipfs.dart` or `package:dart_ipfs_core/dart_ipfs_core.dart` |
| `package:dart_ipfs/src/core/crypto/ed25519_signer.dart` | `package:dart_ipfs_core/dart_ipfs_core.dart` |

## Adding Packages in Future Phases

Future phases may extract additional packages:

- `dart_ipfs_bitswap`
- `dart_ipfs_dht`
- `dart_ipfs_gateway`
- `dart_ipfs_rpc`

Each new package must:

1. Be approved by a maintainer review.
2. Depend only on stable packages (`dart_ipfs_core` and other approved packages).
3. Never depend on the umbrella package.
4. Include its own `README.md`, `analysis_options.yaml`, and tests.
5. Be added to `melos.yaml` and the root `pubspec.yaml` path dependency during development.

## Backward Compatibility

- `package:dart_ipfs/dart_ipfs.dart` remains the stable public API.
- Deep imports into `package:dart_ipfs/src/...` are deprecated in v2.2.0 and will be removed in v3.0.0.
- Existing consumers who use only the public umbrella API will not need code changes.
