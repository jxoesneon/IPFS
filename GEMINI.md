# dart_ipfs v1.11.5 Roadmap & Architecture

## Core Lifecycle Pattern
- **Pattern**: Every major IPFS service MUST implement the `ILifecycle` interface from `package:dart_ipfs/src/core/interfaces/i_lifecycle.dart`.
- **Sequencing**: Use the `LifecycleManager` to orchestrate `start()` and `stop()` calls across services to guarantee deterministic startup/shutdown behavior.
- **Implementation**: New services must mark `start` and `stop` with `@override`. Services that do not require explicit startup/shutdown should still implement the interface with empty overrides.

- **IPLD**: Use the Strategy pattern for codecs to ensure extensibility.
- **Security**: Never expose private keys. Use `IPFSPrivateKey` abstraction.
- **Documentation**: 100% public API documentation is required.

## Specialized Managers
- `ContentManager`: Handles file/directory additions, pinning, and CAR files.
- `NetworkManager`: Handles peer connectivity, provider discovery, and Bitswap block requests.
- `ProtocolManager`: Handles PubSub, IPNS, and DNSLink resolution.

## Strategy: IPLD Codecs
Codecs are implemented as `IPLDCodec` strategies registered in `IPLDHandler`:
- `RawCodec` (raw)
- `DagPbCodec` (dag-pb)
- `DagCborCodec` (dag-cbor)
- `DagJsonCodec` (dag-json)
- `DagJoseCodec` (dag-jose)
- `CarCodec` (car)

## Workflow: Development
1. Implement changes in specialized handlers/managers.
2. Update `IPFSNode` facade to expose new functionality.
3. Verify with `dart analyze` and tests.
4. Update `CHANGELOG.md`.
