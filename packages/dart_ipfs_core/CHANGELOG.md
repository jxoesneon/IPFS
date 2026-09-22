# Changelog

All notable changes to this package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.13.0] - 2026-09-22

### Changed
- **Strict DAG-CBOR canonical codec**: `DagCborCodec` was rewritten for full spec parity — canonical key ordering (length-first, then bytewise), tag 42 CID links, big integers via tags 2/3, strict tag handling, and `-0.0` normalization. The new `strict` flag (default `true`) makes `decode` reject non-canonical encodings — duplicate keys, indefinite-length items, non-shortest-form integers, and non-canonical map ordering — matching the go-ipld-cbor strict decoder. Pass `strict: false` to decode legacy/non-canonical data.
- `DagJsonCodec` updated for parity with the strict DAG-CBOR codec.

## [1.12.0] - 2026-09-19

### Added
- `CID.fromContent` gained `hashType` and `version` parameters; `CID.fromPrefixBytes`, `CID.validate`, `CID.computeForData`, and `CID.computeForDataSync` are now part of the public surface. `CID.toPrefixBytes` synthesizes the implicit `<version=0, codec=dag-pb>` header for CIDv0, matching the Bitswap block-prefix format.

## [1.11.7] - 2026-09-18

### Fixed
- `MultibaseUtils` now implements RFC 4648 encoding/decoding for base16, base32, and base64 variants directly. It previously delegated those bases to a big-integer base-x codec, which produced non-standard strings and could not decode standard CIDv1 strings such as `bafkrei...`. Base58btc still uses the base-x codec, which is correct for that base.
- `CID.hashCode` now hashes the multihash bytes by value instead of hashing a freshly allocated byte list by identity, restoring the `==`/`hashCode` contract so equal CIDs work correctly in sets and as map keys.

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
