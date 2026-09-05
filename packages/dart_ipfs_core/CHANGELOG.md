# Changelog

All notable changes to this package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.11.6] - 2026-09-05

### Fixed
- Fixed 64-bit integer overflow in `DagCborCodec` on Flutter-web (JavaScript runtime) by parsing bounds using `BigInt.parse()` instead of literal 64-bit integer values (`-9223372036854775808` / `9223372036854775807`).

## [1.11.5] - 2026-07-08

### Added
- Initial extraction of `dart_ipfs_core` from the `dart_ipfs` umbrella package.
- Stable core primitives: `CID`, `MultibaseUtils`, `Multicodec`, `MultihashInfo`, `MultihashUtils`.
- Block abstractions: `Block`, `IBlock`, `IBlockStore`, `BlockStoreResult`, `InMemoryBlockStore`.
- Common codecs: `IPLDCodec`, `RawCodec`, `DagCborCodec`, `DagJsonCodec`.
- Cryptographic helpers: `CryptoUtils`, `EncryptedData`, `Ed25519Signer`, `KeyPairExtensions`.
- Small immutable data structures: `ImmutableBytes`, `TypedMap`.
