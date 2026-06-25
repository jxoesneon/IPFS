# dart_ipfs Roadmap

**Current Version**: 1.11.5 (Multi-Platform Production Ready)  
**Last Updated**: 2026-06-25

---

## 📍 Current Status

dart_ipfs **v1.11.5** is **multi-platform production ready** with:

- ✅ **IpfsPlatform**: Unified abstraction layer for IO and Web.
- ✅ **WebRTC Multiplexing**: Native p2p connectivity for browsers with standard libp2p stream support.
- ✅ **Bitswap Smart Routing**: Efficient block exchange with provider tracking.
- ✅ **90% Code Coverage**: Robust test suite with cross-platform validation.
- ✅ **Security Parity**: Unified security management across IO and Web platforms.

---

## 🗓️ Version Timeline

### v1.10 - Q1 2026 (The Multi-Platform Milestone)

**Focus**: Browser compatibility, storage abstraction, and unified API.

#### Features
- [x] IpfsPlatform abstraction layer.
- [x] IndexedDB storage provider for Web.
- [x] Browser-compatible SecurityManager.
- [x] Automated Chrome/Firefox testing suite.
- [x] Protocol standardization (Kubo compliance).

**Released**: February 2026

---

### v1.11 - Q2 2026 (Enhanced Connectivity)

**Focus**: Advanced browser networking and performance.

#### Features
- [x] Libp2p browser transport (WebRTC/WebTransport).
- [x] IPNS performance optimizations (DHT record caching).
- [x] Advanced IPLD codecs (DagCbor, DagJson, DagJose).
- [x] Flutter Web specific optimizations.
- [x] Multi-platform metrics dashboard.

**Released**: May 2026

---

### v2.0 - Q4 2026 (Ecosystem & Extensibility)

**Focus**: Speed and efficiency

#### Features

- [x] MFS (Mutable File System)
- [ ] Parallel block fetching
- [ ] Smart caching with ML
- [ ] Connection pooling
- [ ] Bandwidth shaping

#### Improvements

- [ ] Content routing optimization
- [ ] Multi-algorithm compression
- [ ] Binary size optimization
- [ ] Memory usage improvements

**Estimated Release**: September 2026

---

### v2.1 - Q1 2027 (Advanced Features)

**Focus**: Ecosystem and extensibility

#### Major Features

- [ ] Plugin system architecture
- [ ] QUIC transport
- [ ] Native Ed25519/X25519 crypto
- [ ] Advanced hole punching
- [ ] Chaos engineering framework

#### Breaking Changes

- Improved configuration API (more structured)
- Plugin-based architecture (optional)
- Enhanced type safety

**Estimated Release**: March 2027

---

### v2.1 - Q1 2027 (Security & Privacy)

**Focus**: Enterprise and privacy features

#### Features

- [ ] HSM (Hardware Security Module) support
- [ ] Content policy engine
- [ ] Multi-signature IPNS
- [ ] Zero-knowledge proof support
- [ ] Enhanced audit logging

#### Improvements

- [ ] Enterprise compliance features
- [ ] Advanced access control
- [ ] Privacy-preserving routing

**Estimated Release**: March 2027

---

### v2.2 - Q2 2027 (Developer Tools)

**Focus**: Developer experience

#### Features

- [ ] VS Code extension
- [ ] IntelliJ plugin
- [ ] Code generation tools
- [ ] Interactive tutorials
- [ ] Web dashboard UI

#### Improvements

- [ ] Hot reload support
- [ ] Better debugging tools
- [ ] Integration examples
- [ ] Video tutorial series

**Estimated Release**: June 2027

---

### v3.0 - Q3 2027+ (Innovation)

**Focus**: Next-generation features

#### Experimental

- [ ] Web Assembly build
- [ ] Marketplace integration
- [ ] Desktop native app
- [ ] IPFS over Bluetooth
- [ ] AI-powered content discovery
- [ ] Quantum-safe cryptography

**Estimated Release**: September 2027+

---

## 🎯 Feature Categories

### High Priority (Next 3 Versions)

#### 1. Cryptography Enhancement

- **v1.2**: Native Ed25519/X25519 implementation
- **Why**: Better libp2p compatibility, faster crypto operations
- **Status**: ✅ Completed (v1.2.1)

#### 2. Transport Improvements

- **v1.2**: WebRTC transport for browser compatibility
- **v2.0**: QUIC transport for better performance
- **Why**: Broader platform support, faster connections
- **Effort**: 4-6 weeks each
- **Status**: Planned

#### 3. Mutable File System (MFS)

- **v1.11.5**: Full MFS implementation
- **Why**: Familiar file system interface, better DX
- **Effort**: 6-8 weeks
- **Status**: ✅ Completed

#### 4. Plugin System

- **v2.0**: Extensible plugin architecture
- **Why**: Community contributions, custom protocols
- **Effort**: 8-10 weeks
- **Status**: Planned

### Medium Priority (Future Versions)

#### 5. Performance Optimization

- Parallel block fetching
- Smart caching
- Connection pooling
- Compression improvements

#### 6. Developer Experience

- CLI enhancements
- Flutter widgets
- IDE plugins
- Code generators

#### 7. Security Features

- HSM support
- Content policies
- Multi-sig IPNS
- ZK proofs

#### 8. Platform-Specific

- Mobile optimizations
- Web Assembly
- Desktop app
- Browser extensions

### Low Priority (Long-term)

#### 9. Experimental Features

- Bluetooth transport
- AI content discovery
- Quantum-safe crypto
- Marketplace integration

---

## 🏆 Parity & Superiority Backlog (from 2026-06-25 IPFS implementation review)

The items below were identified by comparing dart_ipfs v1.11.5 against Kubo v0.42.0, Helia, and Iroh. They are required to make dart_ipfs the **superior, fully compliant** IPFS implementation. Each item has been reviewed by the Ciel Council of Five (Coherence, Capability, Safety, Efficiency, Evolution). Verdicts are: **APPROVED** (greenlight), **MODIFIED** (proceed with stated scope change), **DEFERRED** (postponed), or **REJECTED**.

### v2.0 — Q4 2026: Protocol Compliance & Core Data Layer

Focus: close the highest-impact interoperability gaps. Ciel Council verdicts: **APPROVED** unless noted.

- [ ] **P0 — Standard CAR v1/v2 format** ✅ Approved. Delete the old protobuf-based `CAR`/`CarHeader`/`CarIndex` classes and replace them with the standard `CarReader`/`CarWriter`/`CarHeader`/`CarSection`/`IndexBuilder` API (CBOR header + varint CID/block frames, CARv2 pragma/header/index/footer). See `COUNCIL_DECISION_CAR_MIGRATION.md`.
- [ ] **P0 — UnixFS basic directories** ✅ Approved. Fix directory node creation, cumulative `Tsize`, and path resolution integration. (HAMT sharding + symlinks split to P1 below.)
- [ ] **P1 — UnixFS HAMT sharding + symlinks** ✅ Approved. Add large-directory HAMT builder/walker and symlink node creation with cycle guards.
- [ ] **P0 — Full DAG-CBOR codec** ✅ Approved. Make `EnhancedCBORHandler` spec-compliant: CID links as tag `42` with `0x00` prefix, raw bytes without tag `45`, canonical key ordering, big-int support, and strict rejection of non-IPLD CBOR tags.
- [ ] **P1 — Consolidated DAG-JSON codec** 🔧 Modified. Replace both existing `IPLDCodec` interfaces with a single unified interface exposing `name`/`code` and async typed `encode`/`decode` on `IPLDNode`. Delete `dag_json_codec.dart`, make `DagJsonCodec` in `standard_codecs.dart` spec-compliant (safe integers, bytes, CID links, `"/"` escape), and introduce a `MulticodecRegistry` in `IPLDHandler`. See `COUNCIL_DECISION_IPLDCODEC_RECONCILIATION.md`.
- [ ] **P0 — Spec-compliant IPLD selector execution** ✅ Approved. Replace the custom selector model with the official vocabulary (`exploreAll`, `exploreFields`, `exploreIndex`, `exploreRange`, `exploreRecursive`, `exploreUnion`, `matcher`, etc.) serialized as DAG-CBOR. Wire into `IPLDHandler` and GraphSync.
- [ ] **P2 — Full IPLD Schema DSL validation** ⏸ Deferred. Keep the lightweight `IPLDSchema` stopgap; revisit after core data codecs are spec-compliant.
- [ ] **P0 — MFS completeness** ✅ Approved. Add `flush`/`sync`, complete `/api/v0/files/*` RPC coverage, and ensure `read/write/stat/ls` semantics match Kubo.
- [ ] **P0 — Real metrics collection** ✅ Approved. Replace stub `MetricsCollector` getters with actual Prometheus-compatible counters/histograms and wire the configured endpoint.
- [ ] **P2 — OpenTelemetry support** ⏸ Deferred. Revisit after real metrics are production-grade; low value/effort ratio today.
- [ ] **P1 — Subdomain gateway** ✅ Approved. Complete the stub `handleSubdomain` with strict host/CID validation and optional DNSLink resolution.
- [ ] **P0 — Trustless gateway full compliance** ✅ Approved. Honor `Accept` and `?format=` for raw block, CAR, IPNS-record, and DAG-JSON/CBOR responses without returning HTML.
- [ ] **P1 — Content blocking / compact denylist** ✅ Approved. Add an operator-controlled denylist service (default-off, auditable) alongside `SecurityManager`.
- [ ] **P1 — Reprovide strategies** ✅ Approved. Implement a `Reprovider` service with pinned, roots, all, and pinned+mfs strategies, plus unique/entities variants.
- [ ] **P1 — DHT Provide Sweep optimization** ✅ Approved. Implement XOR-ordered reprovide and proximity grouping inside the `Reprovider` service.
- [ ] **P1 — On-demand provide refinement** 🔧 Modified. Enrich the existing `/api/v0/dht/provide` endpoint and `DHTHandler.provide` with explicit `once` semantics, success/failure feedback, and optional queueing — do not create a separate duplicate feature.

### v2.1 — Q1 2027: Networking, Naming & Full P2P

Focus: make the node a credible participant in the public IPFS network. Ciel Council verdicts: **APPROVED** unless noted.

- [ ] **P0 — QUIC transport** ✅ Approved. Add a native QUIC transport plugged into `Libp2pRouter`; target `/udp/.../quic-v1` listen addresses with TCP fallback.
- [ ] **P0 — Full libp2p Gossipsub compliance** ✅ Approved. Replace the custom JSON/HMAC wire format with the Gossipsub protobuf wire format and peer-key message signing; add message-history cache and full peer scoring.
- [ ] **P0 — Real Amino DHT network integration** 🔧 Modified. Finish iterative `FIND_NODE`/`GET_PROVIDERS`, add provider-record validation, implement reprovide sweep, and fix request/response correlation in `DHTClient` so the node can join the public DHT.
- [ ] **P0 — IPNS DHT-first signed records** 🔧 Modified. Use the existing `IPNSRecord` Ed25519 signing + `DHTClient.storeValue/getValue`, derive names from public keys, and require signature verification on resolve. PubSub notifications are gated behind the Gossipsub compliance item.
- [ ] **P0 — Circuit relay v2 client dialing** ✅ Approved. Complete the relayed client dialing path via `/p2p-circuit` multiaddr semantics after reservation.
- [ ] **P1 — Browser Transport Hardening** 🔧 Modified. (Replaces "WebRTC/WebTransport maturity.") Implement WebTransport IO listener/dialer, validate `certhash` in web dialer, replace the hardcoded Google STUN server with configurable STUN/TURN, and implement missing `Conn` metadata without `UnimplementedError`.
- [ ] **P1 — Server-side GraphSync MVP** 🔧 Modified. (Replaces "GraphSync full wiring.") Respond to a single requesting peer with selected blocks in `GraphsyncMessage.blocks`, enforce selector depth/block-count budgets, and fall back to Bitswap for missing blocks. Defer bidirectional pause/resume and client-side matching until the router supports unicast response streams.
- [ ] **P1 — Bitswap HTTP fallback** 🔧 Modified. Integrate `HttpGatewayClient` as a fallback inside `BitswapHandler` after P2P attempts fail; verify every HTTP-fetched block against the requested CID.
- [ ] **P2 — Badger / Pebble datastore backends** ⏸ Deferred. Hive is sufficient for v2.1; re-evaluate once mature Dart bindings exist or profiling proves a bottleneck.
- [ ] **P1 — AutoTLS / TLS for WSS gateway** ✅ Approved. Add optional TLS termination to `GatewayServer` using `SecurityContext` from config, plus an off-by-default AutoTLS/ACME mode for public gateways.

### v2.2 — Q2 2027: Operations, Modularity & Ecosystem

Focus: production deployment and library adoption at scale. Ciel Council verdicts: **APPROVED** unless noted.

- [ ] **P0 — CLI / daemon binary** ✅ Approved. Create `bin/ipfs.dart` with `daemon`, `add`, `cat`, `ls`, `pin`, `id`, `swarm`, `config`, `version` subcommands. Canonical config is JSON (`$IPFS_PATH/config.json`) with YAML read-fallback; `IPFSNodeBuilder` registers `RPCServer` and `GatewayServer` with `LifecycleManager`. See `COUNCIL_DECISION_CONFIG_LIFECYCLE.md`.
- [ ] **P0 — Docker & multi-arch images** ✅ Approved. Fix stale image tag, add CI build/publish, multi-arch support, and supply-chain hardening. Default runtime base: `cgr.dev/chainguard/glibc-dynamic` (hardened glibc) to satisfy the `libsodium` dependency; experimental static variant only if static linking is proven. See `COUNCIL_DECISION_DOCKER_BASE.md`.
- [ ] **P1 — Kubernetes manifests & Helm chart** ✅ Approved. Add a `k8s/` base manifest set after Docker CI is complete.
- [ ] **P0 — Interoperability test suite** ✅ Approved. P0 release-blocking: Kubo CAR exchange, Bitswap fetch, and gateway retrieval. P1 allowed-to-fail/allowed-to-skip: DHT provide/find and IPNS resolution until networking specs stabilize. Helia tests move to a separate nightly workflow. See `COUNCIL_DECISION_INTEROP_SCOPE.md`.
- [ ] **P1 — Package modularization (phase 1)** 🔧 Modified. Create the `packages/` monorepo scaffold and extract only the stable `dart_ipfs_core` layer (CID, multibase, block interfaces, common codecs). Keep protocol/service layers in the umbrella package until v2.1 stabilizes; maintain backward-compatible re-exports.
- [ ] **P1 — Plugin ecosystem (phase 1)** 🔧 Modified. Harden the plugin API with a trust-based, capability-gated, auditable runtime. Ship one or two simple read-only example plugins (e.g., metrics emitter, logging observer). No committed signing keys; use CI-generated ephemeral keys for tests. Defer a public registry to v3.0. See `COUNCIL_DECISION_PLUGIN_SECURITY.md`.
- [ ] **P2 — WASM build** ⏸ Deferred. Keep web code wasm-clean, but do not ship a production wasm node in v2.2; revisit v3.0.
- [ ] **P2 — FUSE mount** ⏸ Deferred. Revisit only after CLI, Docker, and interoperability parity are solid.
- [ ] **P2 — Reference WebUI** 🔧 Modified. Promote the existing `example/ipfs_dashboard` and `web/` demo as the maintained, optional reference WebUI; add a web build CI target and documentation. Do not create a separate productized WebUI in v2.2.

### v2.3+ / v3.0 — Long-term Superiority

- [ ] **Verified streaming** (BLAKE3-style incremental verification, comparable to Iroh)
- [ ] **Advanced hole punching / AutoNATv2** (beyond current NAT traversal)
- [ ] **Multi-signature IPNS** (enterprise naming)
- [ ] **Content policy engine** (granular allow/deny rules)
- [ ] **Hardware Security Module (HSM) support**
- [ ] **Zero-knowledge proof support** (content/ownership proofs)
- [ ] **Quantum-safe cryptography** (experimental)
- [ ] **AI-powered content discovery** (experimental)

---

## 🚀 Quick Wins

These can be implemented quickly with high impact:

### Immediate (Next Release)

1. **Docker Images** (1 week)
   - Official Docker Hub images
   - Multiple variants (gateway, full-node, dev)
2. **Health Checks** (1 week)

   - Kubernetes-ready endpoints
   - Load balancer integration

3. **Structured Logging** (1 week)

   - JSON log format
   - Better log aggregation

4. **Template Library** (1-2 weeks)
   - Project scaffolding
   - Common use cases

### Short-term (Next Quarter)

1. **Enhanced CLI** (2-3 weeks)

   - Full feature parity with API
   - Better UX

2. **Flutter Widgets** (3-4 weeks)

   - Pre-built UI components
   - Mobile app acceleration

3. **API Docs Site** (2-3 weeks)
   - Searchable documentation
   - Examples and guides

---

## 📊 Effort Estimation

### Development Time by Category

| Category               | Total Effort | Priority | Timeline   |
| ---------------------- | ------------ | -------- | ---------- |
| **Crypto Enhancement** | 2-3 weeks    | High     | v1.2       |
| **Transport Layers**   | 8-12 weeks   | High     | v1.2, v2.0 |
| **MFS**                | 6-8 weeks    | High     | v1.3       |
| **Plugin System**      | 8-10 weeks   | High     | v2.0       |
| **Performance**        | 12-16 weeks  | Medium   | v1.3       |
| **Developer Tools**    | 10-14 weeks  | Medium   | v2.2       |
| **Security**           | 12-16 weeks  | Medium   | v2.1       |
| **Platform-Specific**  | 16-20 weeks  | Low      | v2.0+      |
| **Experimental**       | Ongoing      | Low      | v3.0+      |

---

## 🎓 Community Contributions

We welcome contributions in these areas:

### Good First Issues

- Documentation improvements
- Example applications
- Bug fixes
- Test coverage
- Performance benchmarks

### Help Wanted

- Mobile platform optimizations
- Browser compatibility testing
- Integration examples
- Translation/i18n

### Advanced

- Protocol implementations
- Transport layers
- Cryptography improvements
- Plugin development

---

## 📈 Success Metrics

### v1.x Goals

- [ ] 1000+ stars on GitHub
- [ ] 50+ production deployments
- [ ] 10+ community contributors
- [ ] 95%+ test coverage maintained

### v2.x Goals

- [ ] 5000+ downloads per month
- [ ] 100+ production deployments
- [ ] 50+ community contributors
- [ ] 20+ plugins available

### v3.x Goals

- [ ] 10,000+ active users
- [ ] Feature parity with go-ipfs
- [ ] Official IPFS implementation status
- [ ] Vibrant plugin ecosystem

---

## 🤝 How to Contribute

### Areas We Need Help

1. **Documentation**

   - Tutorial writing
   - API documentation
   - Example applications
   - Translation

2. **Testing**

   - Integration tests
   - Platform testing
   - Performance benchmarks
   - Protocol compliance

3. **Features**

   - See "Good First Issues" label
   - Check roadmap for planned features
   - Propose new features via discussions

4. **Community**
   - Answer questions
   - Write blog posts
   - Give talks
   - Share projects

### Process

1. Check existing issues and discussions
2. Propose changes via issue or discussion
3. Get feedback from maintainers
4. Submit PR with tests and docs
5. Code review and merge

---

## 🔮 Long-term Vision

### dart_ipfs in 2027

- **Primary IPFS implementation for Dart/Flutter**
- **100% feature parity with go-ipfs**
- **Thriving plugin ecosystem**
- **Production-ready for all platforms**
- **First-class mobile IPFS experience**
- **Leading in performance and DX**

### Strategic Goals

1. **Become official IPFS implementation**
2. **Power 1000+ production apps**
3. **Enable IPFS on mobile at scale**
4. **Bootstrap decentralized web on Dart**

---

## 📞 Stay Updated

- **GitHub Releases**: Follow for version updates
- **GitHub Discussions**: Feature discussions and feedback
- **GitHub Issues**: Bug reports and feature requests
- **README**: Current status and quick start

---

## 📝 Notes

### Version Numbering

- **Major (x.0.0)**: Breaking changes, major features
- **Minor (1.x.0)**: New features, no breaking changes
- **Patch (1.0.x)**: Bug fixes, minor improvements

### Timeline Flexibility

Dates are estimates and may change based on:

- Community contributions
- Priority shifts
- Resource availability
- Feedback and needs

### Feedback Welcome

This roadmap is a living document. We welcome:

- Feature suggestions
- Priority feedback
- Timeline input
- Use case discussions

---

**Last Updated**: 2026-06-25 (v1.11.5) — parity & superiority backlog added with Ciel Council verdicts
**Status**: Active Development  
**Current Version:** 1.11.5
**Target for Next Release:** 2.0.0 (Q4 2026)
