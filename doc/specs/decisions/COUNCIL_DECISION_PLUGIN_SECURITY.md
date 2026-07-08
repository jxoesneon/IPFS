# Ciel Council of Five Decision: Plugin Security Model & Developer-Key Handling

**Document ID:** `COUNCIL_DECISION_PLUGIN_SECURITY`  
**Date:** 2026-06-25  
**Scope:** `dart_ipfs` v2.2 Phase 1 plugin ecosystem (`PLUGINS_SPEC.md`)  
**Decision Required:**
1. What is the correct security model for plugins in v2.2?
2. How should in-repo example plugin signing keys be handled?
3. Should v2.2 support only signed/trusted plugins, or also unsigned development plugins with warnings?

---

## 1. Council Deliberation

### Coherence: Fit with existing plugin API and `SecurityManager`

`dart_ipfs` already has an in-process `IPFSPlugin` contract (`lib/src/core/plugins/ipfs_plugin.dart`) and a `SecurityManager` (`lib/src/core/security/security_manager.dart`) that manages Ed25519 keys in an encrypted keystore. The v2.2 design can build on these without replacing them.

- The new `PluginHost` becomes an optional, higher-level loader that wraps the existing `IPFSPlugin` lifecycle (`onInit`, `onStart`, `onStop`) but adds a manifest, capability check, and signature verification before invoking the plugin.
- `SecurityManager` and the existing `lib/src/core/crypto/ed25519_signer.dart` utility can be reused for key generation and signature verification, but the plugin trust model needs a new configuration section (`plugin.trustedKeysPath`, `plugin.allowUnsigned`, `plugin.enabled`).
- Capability-gated adapters must be mapped to the concrete service classes already created by `IPFSNodeBuilder` (`BlockStore`, `BitswapHandler`, `MetricsCollector`, etc.), which is straightforward once the service contracts are stable.

The main gap is that the current `IPFSNodeBuilder` registers the `LifecycleManager` but not `PluginHost`, so the spec must explicitly state how `PluginHost` is registered and disabled by default. Overall, the model fits the existing architecture without major rewrites.

**Score:** 7/10

### Capability: Does it still enable a useful plugin ecosystem?

The model still supports the intended ecosystem, but it narrows the Phase 1 scope to plugins that are safe to run inside the same OS process as the node.

- Signed, capability-limited plugins can observe, transform, and emit metrics without needing full node access.
- Example plugins can demonstrate manifest authoring, capability requests, and audit logging.
- The optional host avoids forcing the plugin runtime on every deployment.
- The trade-off is that v2.2 cannot safely run untrusted, third-party plugins out of the box; operators must pair plugin loading with OS-level isolation until v3.0 adds a stronger sandbox.

This is sufficient for v2.2 because the public registry is intentionally deferred to v3.0. The ecosystem remains useful for in-repo examples, first-party plugins, and trusted authors.

**Score:** 7/10

### Safety: How do we prevent malicious plugins from exfiltrating data or corrupting the node?

The most important safety issue is that Dart `Isolate`s are **not** a security sandbox. They share the same OS process, memory page table permissions, filesystem, network namespace, environment variables, and native library access (including `dart:ffi`). A malicious plugin can therefore bypass capability checks by calling `dart:io`, opening sockets, or loading native code. The spec must not claim otherwise.

The approved v2.2 safety model is therefore layered:

1. **Trust policy first:** Only load plugins from trusted authors, validated by Ed25519 signatures against a configurable trusted-key list. Unsigned plugins require explicit opt-in and are disabled by default.
2. **Capability ACLs:** Every plugin declares a non-empty, deny-by-default capability list. The host rejects unknown capabilities and exposes only capability-gated adapters that wrap real services (e.g., `CapabilityBlockStore`, `CapabilityMetricsEmitter`).
3. **No raw references:** Host code must never pass raw `IPFSNode`, `BlockStore`, `NetworkHandler`, or `SecurityManager` instances into a plugin.
4. **Audit logging:** Every capability exercise is logged with plugin ID, capability name, timestamp, and outcome. A plugin that attempts an ungranted action triggers `CapabilityException` and is disabled without crashing the node.
5. **Defense in depth:** Operators who need to load untrusted plugins must also run the node inside an OS-level sandbox (container, VM, seccomp, etc.). The v2.2 design does not replace this requirement.
6. **No committed keys:** The repository must never contain a private signing key. This removes a key-exfiltration path via public repo or CI artifacts.

This model is honest about its limits and does not give users a false sense of safety. It raises the bar for accidental or lazy misuse, but it cannot stop a determined malicious plugin from using OS-level resources. For that reason, the v2.2 plugin host is best described as a "trusted plugin runtime with capability gating," not a "sandbox."

**Score:** 7/10

### Efficiency: Is the model implementable without over-engineering?

The model is intentionally lean for Phase 1.

- It reuses existing `Isolate` support, the `SecurityManager` key store, and the `ed25519_signer.dart` utility.
- It requires only one new optional service (`PluginHost`) and a small set of capability-gated adapters aligned with existing services.
- It does not require OS-level sandboxing in v2.2, which would be a large cross-platform effort.
- The ephemeral CI key approach adds no operational key-management burden for users and no persistent secret to protect.
- The main implementation cost is the capability-to-service mapping table and the tests, which is proportional to the Phase 1 scope.

The main risk is that example plugins should be simple (read-only observers and metrics emitters) so that the capability mapping and tests can be completed without depending on still-stabilizing features like pinning.

**Score:** 7/10

### Evolution: Does it allow a future public registry with stronger sandboxing?

The model is designed to evolve cleanly.

- The manifest schema (`plugin.yaml`) and capability taxonomy are registry-ready once a public registry is added in v3.0.
- Ed25519 signing can be upgraded to Sigstore-style transparency or a public-key registry without changing the manifest format.
- The capability-gated adapter pattern is the right interface boundary for future OS-level sandboxing (separate process, seccomp, WASI, etc.).
- Because v2.2 is honest about Isolates not being a security boundary, v3.0 can introduce a true sandbox without contradicting the v2.2 documentation.

The only dependency is that the capability taxonomy and adapter interfaces must be kept stable, which is already a goal of the v2.2 design.

**Score:** 8/10

---

## 2. Binding Decisions

### Decision 1: Correct security model for plugins

`PLUGINS_SPEC.md` must be rewritten to make the following claims and requirements:

- **Dart Isolates are not a security sandbox.** They provide memory isolation and crash containment, but they run in the same OS process and share filesystem, network, environment, and native library access. They must not be described as a boundary against malicious code.
- The v2.2 security model is **trust-based, capability-based, and audit-based**:
  - **Trust:** Every production plugin must be signed by a key present in the operator's `plugin.trustedKeysPath` file. Unsigned plugins require explicit `plugin.allowUnsigned: true` and are disabled by default.
  - **Capabilities:** Capabilities are deny-by-default, declared in `plugin.yaml`, and enforced by host-side capability-gated adapters. Unknown capabilities are rejected. Each capability exercise is audited.
  - **No raw access:** Host services must never expose raw `IPFSNode`, `BlockStore`, `NetworkHandler`, or `SecurityManager` references to a plugin.
  - **Audit and disable:** A capability violation throws `CapabilityException`, logs the event, and disables the plugin without stopping the node.
- **Untrusted plugins must be combined with OS-level isolation.** The spec must state that operators who need to load untrusted or third-party plugins should run the node inside a container, VM, or other OS sandbox.
- Add a missing acceptance criterion: the spec must demonstrate that a plugin attempting filesystem or network access outside its granted capabilities is blocked by the capability layer, not by the Isolate boundary.

### Decision 2: Handling of in-repo example plugin signing keys

**No private signing key may be committed to the repository.** The existing `tool/plugin_dev_key.pem` proposal is rejected. The approved approach is:

- **CI-generated ephemeral key:** For every test run, CI generates an ephemeral Ed25519 key pair, uses it to sign the in-repo example plugins, and loads the ephemeral public key into the test configuration as the only trusted key. The private key is discarded after the test run and never stored in the repository, CI logs, or artifacts.
- **Production trust is external:** Production deployments supply their own `plugin.trustedKeysPath` pointing to a file of trusted author public keys managed outside the repository. There is no default repository key that could be accidentally trusted.
- **Well-known test public key (optional):** A test fixture may contain a public key explicitly documented as "test only, never trusted in production" to support local development without running CI. This fixture must contain only the public key, never the private key, and must not be referenced by default configuration.
- **Tooling:** Provide a helper script (e.g., `tool/sign_examples.dart`) that CI can run to generate the ephemeral key and re-sign example manifests. The script must be clearly marked as test-only and must not be used to create production keys.

This removes the key-leakage risk while keeping the example plugins loadable and verifiable in CI and local development.

### Decision 3: Signed-only vs. unsigned development plugins in v2.2

**v2.2 supports both modes with a clear security hierarchy:**

- **Default:** Only signed plugins from a trusted key list are loaded. This is the production posture.
- **Development opt-in:** Unsigned plugins may be loaded if, and only if, `plugin.allowUnsigned: true` is set explicitly in the node configuration. A warning is logged at node startup, and the plugin audit log marks the plugin as unsigned.
- **Deprecation:** The spec should state that unsigned plugin loading is deprecated in v2.2 and will be removed or restricted to a separate development-mode build in v3.0. A migration table should be added to the backward-compatibility section.
- This preserves the spec's current `allowUnsigned` flag but makes the default and warning behavior explicit, and aligns with the Safety lens by not allowing unsigned plugins to pass silently.

---

## 3. Mandatory Amendments to `PLUGINS_SPEC.md`

The following changes must be applied before `PLUGINS_SPEC.md` is treated as release-blocking for v2.2:

| Section | Amendment |
|---------|-----------|
| Goal and Scope | Remove the claim that `PluginSandbox` is a security boundary. State that Isolates provide memory/crash isolation and that capability gating is the control mechanism. |
| 4.1 Plugin API Surface | Rewrite the `PluginSandbox` description to: "Isolate-based execution boundary for memory isolation and crash containment; not a security sandbox." |
| 4.3 Capability Model | Add the requirement that host services must expose only capability-gated adapters, never raw service references. |
| 4.4 Signing and Trust | Delete the `tool/plugin_dev_key.pem` reference. Replace it with the CI-generated ephemeral key model and the external `plugin.trustedKeysPath` requirement. |
| 4.5 Example Plugins | Reduce Phase 1 examples to one or two simple, read-only plugins (e.g., a metrics emitter and a logging observer). Defer the pin-policy plugin until pinning is stable. |
| 5. Acceptance Criteria | Add criteria for: (a) capability violation disables the plugin and logs the event; (b) unsigned plugin fails by default and passes only with `allowUnsigned: true` and a warning; (c) plugin host does not block node startup when disabled; (d) audit log entries include plugin ID, capability, timestamp, and outcome. |
| 6. Security Considerations | Replace the Isolate sandbox paragraph with the layered safety model in Decision 1. Add a paragraph requiring OS-level isolation for untrusted plugins. |
| 9. Backward Compatibility | Add a deprecation table: "Unsigned plugin loading (default) — deprecated in v2.2.0, removed in v3.0.0." |
| Key files to create or extend | Remove `tool/plugin_dev_key.pem`. Add `tool/sign_examples.dart` (test-only signer) and `plugin.trustedKeysPath` config mapping. |

---

## 4. Council Scores and Final Verdict

| Lens | Score |
|------|-------|
| Coherence | 7/10 |
| Capability | 7/10 |
| Safety | 7/10 |
| Efficiency | 7/10 |
| Evolution | 8/10 |

### Final Verdict: **APPROVED with mandatory amendments**

The Ciel Council of Five approves the v2.2 plugin security model as a **trust-based, capability-based, auditable runtime**. The model is implementable, preserves the ecosystem, and is honest about the limitations of Dart Isolates. The specification is **not** approved as currently written; it must be amended to remove the false Isolate-sandbox claim, eliminate the committed repository signing key, and reduce the example scope before implementation begins. Once those amendments are made, `PLUGINS_SPEC.md` may proceed to the implementation phase.
