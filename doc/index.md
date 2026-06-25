# dart_ipfs Documentation

Welcome to the documentation for **dart_ipfs**, a production-ready IPFS implementation in Dart.

## Guides

- [Getting Started](../README.md#quick-start)
- [Architecture](ARCHITECTURE.md)
- [WebRTC Transport](../README.md#networking--nat-traversal)
- [Protobuf 6.0.0 Compatibility](PROTOBUF_COMPATIBILITY.md)
- [Roadmap](../ROADMAP.md)

## v2.0+ Parity & Superiority Specifications

Ciel Council of Five approved backlog specs for making dart_ipfs the superior IPFS implementation:

- [Protocol Compliance & Core Data Layer](specs/PROTOCOL_COMPLIANCE_SPEC.md)
- [Networking, Naming & Full P2P](specs/NETWORKING_P2P_SPEC.md)
- [Services & APIs](specs/SERVICES_APIS_SPEC.md)
- [Operations, Modularity & Ecosystem](specs/OPERATIONS_ECOSYSTEM_SPEC.md)

## Per-Feature Deep Specifications

Research-backed, standalone specifications for every approved/modified backlog item:

### Core Data Layer

- [CAR v1/v2 Format](specs/features/CAR_FORMAT_SPEC.md)
- [UnixFS Directories, HAMT, and Symlinks](specs/features/UNIXFS_SPEC.md)
- [DAG-CBOR Codec](specs/features/DAG_CBOR_SPEC.md)
- [DAG-JSON Codec Consolidation](specs/features/DAG_JSON_SPEC.md)
- [IPLD Selectors](specs/features/IPLD_SELECTORS_SPEC.md)

### Services & APIs

- [MFS Completeness](specs/features/MFS_SPEC.md)
- [Real Metrics Collection](specs/features/METRICS_SPEC.md)
- [Subdomain Gateway](specs/features/SUBDOMAIN_GATEWAY_SPEC.md)
- [Trustless Gateway](specs/features/TRUSTLESS_GATEWAY_SPEC.md)
- [Content Blocking / Denylist](specs/features/CONTENT_BLOCKING_SPEC.md)
- [Reprovide Strategies & DHT Provide Sweep](specs/features/REPROVIDE_SPEC.md)

### Networking, Naming & P2P

- [QUIC Transport](specs/features/QUIC_SPEC.md)
- [Gossipsub Compliance](specs/features/GOSSIPSUB_SPEC.md)
- [Amino DHT Network Integration](specs/features/DHT_INTEGRATION_SPEC.md)
- [IPNS DHT-First Signed Records](specs/features/IPNS_SPEC.md)
- [Circuit Relay v2 Client Dialing](specs/features/CIRCUIT_RELAY_SPEC.md)
- [Browser Transport Hardening](specs/features/BROWSER_TRANSPORTS_SPEC.md)
- [Server-Side GraphSync MVP](specs/features/GRAPHSYNC_SPEC.md)
- [Bitswap HTTP Fallback](specs/features/BITSWAP_HTTP_FALLBACK_SPEC.md)
- [Gateway TLS / AutoTLS](specs/features/GATEWAY_TLS_SPEC.md)

### Operations, Modularity & Ecosystem

- [CLI / Daemon Binary](specs/features/CLI_SPEC.md)
- [Docker Images](specs/features/DOCKER_SPEC.md)
- [Kubernetes / Helm](specs/features/KUBERNETES_SPEC.md)
- [Interoperability Test Suite](specs/features/INTEROP_TESTS_SPEC.md)
- [Package Modularization](specs/features/MODULARIZATION_SPEC.md)
- [Plugin Ecosystem](specs/features/PLUGINS_SPEC.md)

## API Reference

- [Pub.dev Documentation](https://pub.dev/documentation/dart_ipfs/latest/)

## Examples

- [Flutter Dashboard](../example/ipfs_dashboard/README.md)
- [CLI Dashboard](../example/cli_dashboard/README.md)

## Development

- [Development Guidelines](../GEMINI.md)

## Maintenance

- [Maintainer Guide](MAINTAINER_GUIDE.md)
