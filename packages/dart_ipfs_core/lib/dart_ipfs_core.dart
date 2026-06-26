/// Stable core primitives for the dart_ipfs IPFS implementation.
///
/// This library exposes the low-level, spec-defined building blocks used by
/// the umbrella `dart_ipfs` package and by plugins:
///
/// - CID, multibase, multicodec, and multihash helpers
/// - Content-addressed blocks and a simple in-memory block store
/// - DAG-CBOR, DAG-JSON, and raw codecs
/// - Cryptographic hashing, key derivation, and Ed25519 helpers
/// - Small immutable data structures
///
/// Protocol and service layers (Bitswap, DHT, Gateway, RPC, etc.) remain in
/// the umbrella `dart_ipfs` package.
library;

export 'src/block/block.dart' show Block, IBlock;
export 'src/block/block_store.dart' show BlockStoreResult, IBlockStore;
export 'src/block/memory_block_store.dart' show InMemoryBlockStore;

export 'src/cid/cid.dart' show CID;
export 'src/cid/multibase.dart' show MultibaseUtils;
export 'src/cid/multicodec.dart' show Multicodec;
export 'src/cid/multihash.dart' show MultihashInfo, MultihashUtils;

export 'src/codec/codec.dart' show IPLDCodec;
export 'src/codec/dag_cbor_codec.dart' show DagCborCodec;
export 'src/codec/dag_json_codec.dart' show DagJsonCodec;
export 'src/codec/raw_codec.dart' show RawCodec;

export 'src/crypto/crypto_utils.dart' show CryptoUtils, EncryptedData;
export 'src/crypto/ed25519_signer.dart' show Ed25519Signer, KeyPairExtensions;

export 'src/data_structures/immutable_bytes.dart' show ImmutableBytes;
export 'src/data_structures/typed_map.dart' show TypedMap;
