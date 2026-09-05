# dart_ipfs_core Example

This example demonstrates how to use the core primitives provided by `dart_ipfs_core`:

1. **Content Identifiers (CID)**: Computing CIDv1 hashes from raw content.
2. **Blocks & BlockStore**: Storing and retrieving content-addressed blocks using `InMemoryBlockStore`.
3. **IPLD Codecs**: Encoding and decoding structured documents with `DagCborCodec`.
4. **Cryptographic Primitives**: Generating Ed25519 keypairs, signing payloads, and verifying signatures.

## Running the Example

From the package root:

```bash
dart run example/main.dart
```
