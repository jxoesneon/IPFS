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
- Implement a `PluginSandbox` boundary using Dart `Isolate`s with capability gating.
- Add Ed25519 manifest signing and signature verification.
- Ship 2–3 in-repo example plugins signed with a repository development key.
- Document the plugin API in `doc/plugins.md`.

Out of scope for v2.2:

- A public plugin registry or marketplace.
- Hot-reload of plugins in production (plugins are loaded at startup).
- True OS-level sandboxing ( Isolate-only in v2.2).
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
- `tool/plugin_dev_key.pem` (repository dev key, not for production).
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
| `PluginSandbox` | Execution boundary for untrusted plugins. In v2.2 this is Dart `Isolate`-based with capability gating; true OS sandboxing is deferred. |
| `Signature` | Ed25519 signature of the plugin package manifest (tar/gz archive) by a trusted author or the in-repo key. |

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

- In-repo example plugins are signed with a repository dev key stored in `tool/plugin_dev_key.pem`. This key is **not for production use**.
- Production deployments may supply a trusted-keys file via config (`plugin.trustedKeysPath`).
- Unsigned plugins may only be loaded if `plugin.allowUnsigned` is explicitly set to `true` in the node configuration (default: `false`).
- Signature verification must cover the manifest and the archive checksum. If the archive is tampered with, loading fails.

### 4.5 Example Plugins

| Plugin ID | Purpose | Capabilities |
|-----------|---------|--------------|
| `org.dart-ipfs.examples.bitswap-logger` | Logs all Bitswap wantlist/have messages to a local file. | `network.bitswap.observe`, `metrics.emit` |
| `org.dart-ipfs.examples.pin-policy` | Auto-pins CIDs matching a configured allowlist. | `blockstore.read`, `blockstore.write`, `pin.add` |
| `org.dart-ipfs.examples.gateway-metrics` | Emits gateway request counts/histograms to a custom backend. | `gateway.observe`, `metrics.emit` |

Each example must:

- Include a `plugin.yaml` manifest.
- Be signed with the dev key.
- Include unit tests demonstrating capability behavior.
- Be loaded successfully by the `PluginHost` in CI.

---

## 5. Detailed Acceptance Criteria

1. `PluginHost` loads all three example plugins in CI.
2. Removing a capability from a manifest causes the plugin to fail to load.
3. The logging plugin records a Bitswap message when two nodes exchange a block.
4. The pin-policy plugin successfully pins a CID matching the configured allowlist.
5. An unsigned plugin fails to load unless `allowUnsigned: true` is set in the node configuration.
6. A tampered plugin archive fails signature verification.
7. The plugin API is documented in `doc/plugins.md` with a manifest schema, capability list, and migration guide.
8. Capability-gated adapters throw `CapabilityException` when a plugin attempts an ungranted action.
9. Plugin lifecycle events (`initialize`, `start`, `stop`) are routed correctly and logged.
10. Plugin audit logs include plugin ID, capability exercised, timestamp, and outcome.

---

## 6. Security Considerations

- Plugins run in Dart `Isolate`s with no shared mutable state with the host.
- The capability model is deny-by-default; host services must never expose raw references to node internals.
- Unsigned plugins fail to load unless explicitly allowed, and a warning is emitted.
- Signed plugins must verify the manifest signature against a trusted key list.
- Plugin audit logs are written to the configured log destination and must not be truncated or skipped on failure.
- In v2.2, plugins cannot escalate to OS-level operations. FUSE and raw socket access are blocked by capability design.
- The repository dev key (`tool/plugin_dev_key.pem`) must be clearly marked as not for production use in documentation and comments.
- The plugin archive checksum must be verified before loading, and the signature must cover the checksum.
- Plugin configuration from the node config must be validated against a schema to prevent injection of unsafe paths or commands.

---

## 7. Testing Strategy

### 7.1 Unit Tests

- Test `PluginManifest` parsing and schema validation.
- Test `PluginHost` load, start, stop, and unload sequences.
- Test capability enforcement with mocked services.
- Test signature verification with valid, invalid, and tampered signatures.
- Test that removing a capability causes the plugin to fail or disables a specific operation.

### 7.2 Integration Tests

- Load all three example plugins in a real node and exercise their documented behaviors.
- Verify the logging plugin captures a Bitswap message during a block exchange.
- Verify the pin-policy plugin pins content matching the allowlist and ignores content that does not match.
- Verify the gateway-metrics plugin emits a metric when a gateway request is served.

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

- True OS-level sandboxing may be added in v3.0; the v2.2 Isolate sandbox is the supported boundary for Phase 1.
