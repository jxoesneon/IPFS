# dart_ipfs Plugin Ecosystem (Phase 1) Specification

**Document ID:** `PLUGINS_SPEC`  
**Version:** 1.0-draft  
**Target Release:** dart_ipfs v2.2  
**Status:** Draft specification for implementation  
**Council Priority:** P1 MODIFIED  
**Source:** `OPERATIONS_ECOSYSTEM_SPEC` section 4.6

---

## 1. Goal and Scope

The goal of this specification is to harden the plugin API for `dart_ipfs` with a capability-based security model, a signed manifest format, a lifecycle contract, and a set of in-repo example plugins. Phase 1 intentionally defers a public plugin registry or marketplace until v3.0 and focuses on making the plugin runtime safe, observable, and well-documented.

Scope for v2.2:

- Define a `PluginCapability` taxonomy and `PluginManifest` schema.
- Implement a `PluginHost` runtime that loads plugins, validates manifests, enforces capability ACLs, and routes lifecycle events.
- Implement an `Isolate`-based execution boundary for memory isolation and crash containment. **Dart Isolates are not a security sandbox;** capability gating and trust policy are the real controls.
- Add Ed25519 manifest signing and signature verification.
- Ship 1–2 simple in-repo example plugins (e.g., a metrics emitter and a logging observer) signed with a CI-generated ephemeral key.
- Document the plugin API in `doc/plugins.md`.

Out of scope for v2.2:

- A public plugin registry or marketplace.
- Hot-reload of plugins in production (plugins are loaded at startup).
- True OS-level sandboxing (Isolates are not a security boundary; operators must use containers/VMs for untrusted plugins).
- Dynamic plugin installation over the network.

---

## 2. Official References

- Dart Isolates: https://dart.dev/language/concurrency
- Dart package layout for plugins: https://dart.dev/tools/pub/package-layout
- Capability-based security model: https://en.wikipedia.org/wiki/Capability-based_security
- Ed25519 signature algorithm: https://ed25519.cr.yp.to/
- SPDX license list for plugin manifests: https://spdx.org/licenses/
- Semantic Versioning: https://semver.org/
- Code signing best practices (Sigstore / cosign): https://www.sigstore.dev/
- IPFS plugin architecture discussions: https://docs.ipfs.tech/

---

## 3. Current State in dart_ipfs

| Area | Current State | Gap |
|------|---------------|-----|
| Plugin API | Exists but is not hardened or documented. | No capability model, no signing, no lifecycle guarantees, no examples. |
| Manifest format | None. | Plugins cannot declare permissions or dependencies declaratively. |
| Sandbox | None. | Plugins would run with full access to the host node if loaded. |
| Signing | None. | No way to verify plugin integrity or authorship. |
| Examples | None. | No reference implementations for plugin authors. |

Key files to create or extend:

- `lib/src/plugin/plugin_host.dart`
- `lib/src/plugin/plugin_manifest.dart`
- `lib/src/plugin/plugin_lifecycle.dart`
- `lib/src/plugin/plugin_sandbox.dart`
- `lib/src/plugin/capability_blockstore.dart`
- `lib/src/plugin/capability_metrics.dart`
- `plugins/` or `examples/plugins/` directory for in-repo examples.
- `tool/sign_examples.dart` (test-only helper that generates an ephemeral CI key and signs example plugins).
- `doc/plugins.md`
- `test/plugin/` tests.

---

## 4. Target State / Requirements

### 4.1 Plugin API Surface

| Concept | Description |
|---------|-------------|
| `PluginCapability` | Declarative set of permissions (e.g., `blockstore.read`, `blockstore.write`, `dht.provide`, `network.dial`, `gateway.register_route`, `metrics.emit`). |
| `PluginManifest` | JSON/YAML file bundled with the plugin: `id`, `name`, `version`, `capabilities`, `hooks`, `author`, `signature`, `checksums`. |
| `PluginLifecycle` | Interface with `initialize`, `start`, `stop`, `onConfigChanged`, `onPeerConnected`, `onBlockStored`. |
| `PluginHost` | Runtime service that loads plugins, validates manifests, enforces capability ACLs, and routes lifecycle events. |
| `PluginSandbox` | `Isolate`-based execution boundary for memory isolation and crash containment. **Not a security sandbox.** |
| `Signature` | Ed25519 signature over the canonical manifest bytes (including the `archive_sha256` checksum of the plugin code), so the signature covers the plugin package content, not just the manifest. |

### 4.2 Manifest Schema (YAML)

```yaml
plugin:
  id: com.example.bitswap-logger
  name: Bitswap Logger
  version: 1.0.0
  dart_ipfs_version: ">=2.2.0 <2.3.0"
  author: "Dart IPFS Contributors <security@dart-ipfs.invalid>"
  capabilities:
    - network.bitswap.observe
    - metrics.emit
  hooks:
    - on_bitswap_message
    - on_metrics_flush
  entrypoint: plugin/main.dart
  signature:
    algorithm: ed25519
    public_key: base64://...
    signature: base64://...
  checksums:
    archive_sha256: "..."
```

Requirements:

- The manifest must be valid YAML and pass a schema check.
- `id` must be a reverse-DNS-style identifier.
- `version` must follow semantic versioning.
- `dart_ipfs_version` must be a valid Dart semver constraint.
- `capabilities` must be a non-empty list unless the plugin is purely passive (subject to Host policy).
- `entrypoint` must reference a file inside the plugin archive.
- `signature` and `checksums` must be present for signed plugins.

### 4.3 Capability Model

- Capabilities are **deny-by-default**.
- The plugin must request capabilities at load time; any runtime access outside the granted set throws a `CapabilityException` and disables the plugin.
- Host services expose capability-gated adapters (e.g., `CapabilityBlockStore`, `CapabilityMetricsEmitter`) rather than raw service references.
- Every plugin action that exercises a capability is logged with plugin ID, capability, and outcome.
- The `PluginHost` must reject a plugin whose manifest contains unknown capabilities.

### 4.4 Signing and Trust

- **No private signing key is committed to the repository.** The `tool/plugin_dev_key.pem` approach is rejected.
- In-repo example plugins are signed with a **CI-generated ephemeral Ed25519 key pair** for each test run. The ephemeral public key is loaded as the only trusted key for the test; the private key is discarded after the run and never stored in the repo, CI logs, or artifacts.
- Local development may use a well-marked test-only public key fixture (public key only, never the private key).
- `tool/sign_examples.dart` is a test-only helper that generates the ephemeral key and re-signs example manifests.
- Production deployments must supply a trusted-keys file via config (`plugin.trustedKeysPath`) pointing to author public keys managed outside the repository.
- Unsigned plugins may only be loaded if `plugin.allowUnsigned` is explicitly set to `true` in the node configuration (default: `false`). A warning is logged at startup, and the audit log marks the plugin as unsigned.
- Signature verification must cover the manifest and the archive checksum. If the archive is tampered with, loading fails.
- Unsigned plugin loading is **deprecated** in v2.2.0 and will be removed or restricted to a development-mode build in v3.0.0.

### 4.5 Capability-to-Service Mapping

The host must never expose raw `IPFSNode`, `BlockStore`, `NetworkHandler`, or `SecurityManager` references to a plugin. Instead, it provides capability-gated adapters:

| Capability | Gated Adapter | Backing Service | Permitted Operations |
|------------|---------------|-----------------|----------------------|
| `blockstore.read` | `CapabilityBlockStore` | `BlockStore` | `hasBlock`, `getBlock` |
| `blockstore.write` | `CapabilityBlockStore` | `BlockStore` | `putBlock` |
| `network.bitswap.observe` | `CapabilityBitswapObserver` | `BitswapHandler` | subscribe to wantlist/have events |
| `metrics.emit` | `CapabilityMetricsEmitter` | `MetricsCollector` | emit counters/histograms |
| `gateway.observe` | `CapabilityGatewayObserver` | `GatewayServer` | observe request metadata |
| `pin.add` | `CapabilityPinManager` | `ContentManager` | pin a CID |

### 4.6 Example Plugins

Phase 1 examples are limited to simple, read-only observers:

| Plugin ID | Purpose | Capabilities |
|-----------|---------|--------------|
| `org.dart-ipfs.examples.metrics-emitter` | Emits a custom counter/histogram to the metrics collector. | `metrics.emit` |
| `org.dart-ipfs.examples.bitswap-logger` | Logs Bitswap wantlist/have messages to the configured log destination. | `network.bitswap.observe`, `metrics.emit` |

The `pin-policy` and `gateway-metrics` examples are deferred until pinning and gateway internals are stable.

Each example must:

- Include a `plugin.yaml` manifest.
- Be signed with the CI-generated ephemeral key.
- Include unit tests demonstrating capability behavior.
- Be loaded successfully by the `PluginHost` in CI.

---

## 5. Detailed Acceptance Criteria

1. `PluginHost` loads the two Phase 1 example plugins in CI.
2. The plugin host is optional and disabled by default; it does not block node startup when disabled.
3. Removing a capability from a manifest causes the plugin to fail to load.
4. The metrics-emitter plugin emits a counter when invoked.
5. The bitswap-logger plugin records a Bitswap message when two nodes exchange a block.
6. An unsigned plugin fails to load unless `allowUnsigned: true` is set in the node configuration, and a warning is logged.
7. A tampered plugin archive fails signature verification before any code is loaded or initialized.
8. The plugin API is documented in `doc/plugins.md` with a manifest schema, capability list, and migration guide.
9. Capability-gated adapters throw `CapabilityException` when a plugin attempts an ungranted action; the plugin is disabled and the node continues running.
10. Plugin lifecycle events (`initialize`, `start`, `stop`) are routed correctly and logged.
11. Plugin audit logs include plugin ID, capability exercised, timestamp, and outcome.
12. A plugin attempting filesystem or network access outside its granted capabilities is blocked by the capability layer, not by the Isolate boundary.

---

## 6. Security Considerations

- Dart `Isolate`s provide memory isolation and crash containment, but they are **not a security sandbox**. A malicious plugin can still access the filesystem, network, environment, and native libraries via `dart:io` and `dart:ffi` because it runs in the same OS process as the host.
- The v2.2 security model is **trust-based, capability-based, and audit-based**: plugins must be signed by a trusted key; capabilities are deny-by-default; host services expose only capability-gated adapters; every capability exercise is audited.
- Host services must never expose raw `IPFSNode`, `BlockStore`, `NetworkHandler`, or `SecurityManager` references to a plugin.
- Unsigned plugins fail to load unless explicitly allowed, and a warning is emitted.
- Signed plugins must verify the manifest signature against a trusted key list.
- Plugin audit logs are written to the configured log destination and must not be truncated or skipped on failure.
- Operators who need to load untrusted or third-party plugins must run the node inside an OS-level sandbox (container, VM, seccomp, etc.).
- The plugin archive checksum must be verified before loading, and the signature must cover the checksum.
- Plugin configuration from the node config must be validated against a schema to prevent injection of unsafe paths or commands.
- No private signing key is committed to the repository.

---

## 7. Testing Strategy

### 7.1 Unit Tests

- Test `PluginManifest` parsing and schema validation.
- Test `PluginHost` load, start, stop, and unload sequences.
- Test capability enforcement with mocked services.
- Test signature verification with valid, invalid, and tampered signatures.
- Test that removing a capability causes the plugin to fail or disables a specific operation.

### 7.2 Integration Tests

- Load the two Phase 1 example plugins in a real node and exercise their documented behaviors.
- Verify the metrics-emitter plugin emits a counter when invoked.
- Verify the bitswap-logger plugin captures a Bitswap message during a block exchange.

### 7.3 CI Pipeline

- Add or extend `.github/workflows/lint.yml` to run plugin tests on changes to `lib/src/plugin/`, `plugins/`, or `test/plugin/`.
- Verify plugin examples load in the Docker smoke test.
- Add a test that an unsigned plugin fails by default.
- Add a test that a tampered archive fails signature verification.

### 7.4 Security Tests

- Attempt to load a plugin requesting a non-existent capability and confirm rejection.
- Attempt to access a raw `BlockStore` from inside a plugin and confirm it is blocked.
- Verify audit logs contain the expected entries after a capability is exercised.

---

## 8. Dependencies and Ordering

- **Prerequisites:**
  - Stable `BlockStore` and key interfaces (preferably in `dart_ipfs_core`, see `MODULARIZATION_SPEC.md`).
  - A stable node lifecycle so `PluginHost` can be initialized during `IPFSNode` startup.
  - A CLI and config system that can read `plugin.*` configuration (see `CLI_SPEC.md`).
- **Order:** Plugin API hardening is a P1 item and is part of the v2.2 rc / optional v2.2.x phase. It depends on modularization of the core interfaces and the stability of the node lifecycle.
- **Downstream consumers:**
  - Future v3.0 public plugin registry.
  - Third-party plugin authors who will use the API and example plugins as templates.

---

## 9. Backward Compatibility Notes

- Pre-v2.2 plugin loading (if any existed) is replaced by the new manifest/capability model.
- Old plugin packages must add a `plugin.yaml` manifest and request explicit capabilities.
- The example plugins serve as migration templates.
- The plugin API surface is new and may evolve in v2.3. The in-repo examples are the canonical reference.
- The deny-by-default capability model and unsigned-plugin rejection are new behaviors. Operators who previously loaded unsigned plugins must explicitly set `plugin.allowUnsigned: true` and accept the associated risk.
- Deprecation timeline:

| Item | Deprecated In | Removed In |
|------|---------------|------------|
| Unsigned plugin loading (default) | v2.2.0 | v3.0.0 (require signing) |
| Pre-v2.2 plugin loader (if any) | v2.2.0 | v3.0.0 |
| `PluginSandbox` as a security claim | v2.2.0 | v3.0.0 (replaced by OS-level sandbox) |

- True OS-level sandboxing may be added in v3.0; the v2.2 Isolate execution boundary is the supported isolation boundary for Phase 1.
