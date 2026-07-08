# Ciel Council of Five Decision — Interoperability Test Suite Scope for dart_ipfs v2.2

**Decision ID:** `COUNCIL_DECISION_INTEROP_SCOPE`  
**Date:** 2026-06-25  
**Convened by:** Ciel Council of Five (Coherence, Capability, Safety, Efficiency, Evolution)  
**Subject:** Release-blocking status and minimum protocol coverage of the v2.2 cross-implementation interoperability test suite.  
**Inputs:**
- `doc/specs/features/INTEROP_TESTS_SPEC.md` (v1.0-draft)
- `doc/specs/audits/COUNCIL_AUDIT_OPERATIONS_ECOSYSTEM.md`
- `doc/specs/audits/COUNCIL_AUDIT_NETWORKING_P2P_1.md`
- `lib/src/protocols/dht/dht_client.dart`
- `lib/src/protocols/ipns/ipns_handler.dart`

---

## 1. Questions Under Review

1. Should the interop test suite be **P0 release-blocking** for v2.2, or **P1 allowed-to-fail/skip** initially?
2. Which protocols must be tested at minimum for a credible v2.2 release?
3. Which tests may be allowed to fail or be marked `skip` until the underlying protocol implementation is proven?
4. Should the CI job fail the build on interop failures, or report them as a separate status?

---

## 2. Council Deliberation

### 2.1 Coherence — Does the decision fit the v2.2 plan and the other specs?

**Score: 8/10**

The `INTEROP_TESTS_SPEC.md` correctly identifies cross-implementation drift as the highest-risk item in the v2.2 operations backlog (`COUNCIL_AUDIT_OPERATIONS_ECOSYSTEM.md`, line 181). However, treating **every** listed scenario as P0 release-blocking is incoherent with the current implementation state:

- The networking specs (`DHT_INTEGRATION_SPEC.md`, `IPNS_SPEC.md`) are themselves marked **CONDITIONAL** and depend on missing primitives (`PeerId` base36 methods, `DHTConfig` server/client mode, iterative DHT queries).
- The audit explicitly recommends conditioning the interop spec on protocol stability (`COUNCIL_AUDIT_OPERATIONS_ECOSYSTEM.md`, line 339).
- A split-tier model (P0 data-exchange tests, P1 naming/routing tests) keeps the suite aligned with the v2.2 release plan while respecting the dependency ordering in `COUNCIL_AUDIT_NETWORKING_P2P_1.md`, section 6.2.

**Coherence finding:** A P0 interop job is required, but only the CAR, Bitswap, and gateway scenarios should gate the release.

### 2.2 Capability — Does it prove real interoperability where it matters?

**Score: 8/10**

The v2.2 release must demonstrate that dart_ipfs can exchange content with Kubo at the wire level. The most valuable, immediately testable capabilities are:

1. **CAR exchange** — proves block serialization and DAG transport compatibility.
2. **Bitswap fetch** — proves the primary content-routing protocol works in both directions.
3. **Gateway retrieval** — proves HTTP trustless gateway conformance (`?format=raw` and `?format=car`).

DHT provide/find and IPNS resolution are also strategically important, but a failing test of a still-stabilizing protocol does not prove a real interoperability gap. It proves that the local implementation is incomplete. The capability value of DHT/IPNS interop is therefore conditional on first completing the networking specs.

**Capability finding:** A credible v2.2 release must pass Kubo interop for CAR, Bitswap, and gateway. DHT and IPNS interop remain release goals but are not yet credible release gates.

### 2.3 Safety — What is the risk of claiming parity without tests? What is the risk of blocking releases on unstable protocols?

**Score: 8/10**

Two opposing risks must be balanced:

- **Risk of claiming parity without tests:** If v2.2 ships without any cross-implementation verification, the project cannot claim Kubo/Helia parity for CAR, Bitswap, or gateway. This undermines the v2.2 operations narrative and invites regressions in protocol code.
- **Risk of blocking releases on unstable protocols:** The current codebase has a custom DHT client that is only single-hop (`dht_client.dart:146-194`), and IPNS resolution hardcodes `QmResolvedCid` (`ipns_handler.dart:191`) while publishing is stubbed (`ipns_handler.dart:194-197`). Gating v2.2 on these tests would hand the release schedule to unfinished networking work and could delay v2.2 indefinitely.

The safer path is to require P0 interop tests for stable data-exchange protocols and to allow DHT/IPNS tests to report results without blocking release. This avoids both false parity claims and an unbounded release blocker.

**Safety finding:** Release-blocking gates are only safe when the underlying protocol is itself stable. Data-exchange protocols are ready; DHT/IPNS are not.

### 2.4 Efficiency — Can the CI job run reliably within a reasonable time?

**Score: 7/10**

The draft spec proposes generous timeouts (120–180 s for DHT/IPNS) and a Helia job matrix that would run on every PR. If everything is treated as P0, a single PR touching protocol code could wait 15–30 minutes for interop feedback, and the Helia matrix would add maintenance cost for marginal v2.2 value.

The recommended split improves efficiency:

- P0 Kubo scenarios (CAR, Bitswap, gateway) target a **total job budget of 10 minutes**.
- P1 DHT/IPNS scenarios use tighter 60 s timeouts and `continue-on-error: true` while stabilizing.
- Helia tests move to a **separate nightly workflow** that does not run on every PR.
- Packet-capture artifacts are retained for a maximum of 7 days and must use synthetic data, addressing retention and privacy concerns.

**Efficiency finding:** The suite is efficient only if it is tiered and the slow, unstable scenarios are decoupled from the PR critical path.

### 2.5 Evolution — Does it set up a path to stricter gating later?

**Score: 9/10**

A tiered model is explicitly evolutionary:

- The P0 job, Docker Compose network, RPC clients, and pinned Kubo version create the infrastructure needed for stricter gating.
- The P1 scenarios remain in the codebase as test stubs, so they can be promoted to P0 once `DHT_INTEGRATION_SPEC.md` and `IPNS_SPEC.md` are fully implemented and the missing primitives (`PeerId` base36, iterative DHT queries, DHT mode configuration) are in place.
- The nightly Helia workflow gives the project a place to mature Helia interop without destabilizing v2.2.
- A separate status check for P1 results ensures visibility even when failures do not block the merge.

**Evolution finding:** The decision turns a potential release blocker into a progressive gate: prove the protocol, then promote the test.

---

## 3. Final Verdict Matrix

| Lens | Score | Summary |
|------|-------|---------|
| Coherence | 8/10 | Split-tier model aligns with v2.2 plan and dependency ordering. |
| Capability | 8/10 | Proves data-exchange parity with Kubo; defers naming/routing parity until the protocol is ready. |
| Safety | 8/10 | Balances parity claims against unbounded release risk. |
| Efficiency | 7/10 | Keeps PR job under 10 minutes; moves slow/unstable work to P1 and nightly. |
| Evolution | 9/10 | Builds infrastructure and a clear promotion path for stricter gating. |

**Overall Verdict: CONDITIONAL APPROVED — with mandatory scope split.**

The interop test suite is approved as a P0 deliverable, but only the CAR, Bitswap, and gateway scenarios are P0 release-blocking. DHT and IPNS interop tests are required to exist but are P1 allowed-to-fail/allowed-to-skip until the underlying networking specs are proven. Helia tests are moved to a separate nightly workflow.

---

## 4. Binding Decisions

### 4.1 Release-blocking status

- **P0 release-blocking:** The interop CI job itself is required to exist and run on PRs touching `lib/src/protocols/`, `lib/src/services/`, or `bin/`.
- **P0 scenarios (must pass for v2.2 release):**
  - CAR exchange (import/export) against Kubo.
  - Bitswap fetch in both directions against Kubo.
  - Gateway retrieval (raw, CAR, and default response) against Kubo.
- **P1 allowed-to-fail/allowed-to-skip:**
  - DHT provide/find against Kubo.
  - IPNS resolution against Kubo.
- **P1 optional/nightly:**
  - Helia Bitswap and CAR scenarios, in a separate workflow.

### 4.2 Minimum protocol coverage for v2.2

A credible v2.2 release must verify the following against Kubo:

1. **CAR exchange** — `/api/v0/dag/export` and `/api/v0/dag/import` or equivalent library paths; byte-exact comparison of CAR roots and blocks.
2. **Bitswap fetch** — `ipfs block get` and `ipfs cat` in both directions; byte-exact content comparison.
3. **Gateway retrieval** — `curl` against dart_ipfs gateway and Kubo gateway; verify `?format=raw` and `?format=car` trustless modes; correct headers and content types.

The following must be present in the test suite but are not release gates:

4. **DHT provide/find** — `ipfs dht findprovs` and `ipfs dht findpeer` in a private Docker network.
5. **IPNS resolution** — publish a signed IPNS record and resolve it from Kubo, and vice versa.
6. **Helia Bitswap/CAR** — nightly scaffolding only.

### 4.3 Allowed-to-fail and allowed-to-skip rules

| Scenario | Initial CI treatment | Rationale |
|----------|----------------------|-----------|
| DHT provide/find | `allowed-to-fail` | The DHT client is custom and single-hop (`dht_client.dart:146-194`). Iterative Kademlia queries, `DHTMode` configuration, and provider validation are still being implemented per `DHT_INTEGRATION_SPEC.md`. |
| IPNS resolution | `allowed-to-skip` or `allowed-to-fail` | IPNS resolution hardcodes `QmResolvedCid` (`ipns_handler.dart:191`) and `_publishToDHT` is stubbed (`ipns_handler.dart:194-197`). The spec also requires missing `PeerId` base36 primitives (`COUNCIL_AUDIT_NETWORKING_P2P_1.md`, section 5.4). |
| Helia Bitswap/CAR | `allowed-to-fail` in nightly job | Helia interop is valuable for v3.0 but is not a v2.2 parity prerequisite. |

**Skip condition:** A P1 scenario may be marked `skip` if a prerequisite RPC endpoint or primitive (e.g., `/api/v0/name/publish`, `/api/v0/dht/provide`, or `PeerId.toBase36`) is not yet implemented. It may be marked `allowed-to-fail` if the test can run but the protocol is unstable.

### 4.4 CI job failure behavior

- **P0 scenarios:** The CI job **must fail** the build on any P0 failure. The job blocks merging of PRs that touch protocol or service code.
- **P1 scenarios:** The CI job **must not fail** the build. P1 scenarios use `continue-on-error: true` and report results as a **separate status check** (e.g., `interop-p1 / kubo-dht-ipns`). The PR status page must show the P1 result distinctly, but a P1 failure cannot block merge.
- **Helia scenarios:** Run in a separate nightly workflow. Results are reported but never block merge or release.
- **Artifacts:** Logs and optional packet captures are retained for 7 days only, use synthetic non-sensitive data, and are purged by repository retention policy.

### 4.5 Preconditions for promotion

DHT and IPNS scenarios may be promoted to P0 release-blocking only after all of the following are complete:

1. `DHT_INTEGRATION_SPEC.md` is implemented and the DHT client supports iterative queries with request/response correlation.
2. `IPNS_SPEC.md` is implemented, the hardcoded `QmResolvedCid` fallback is removed, and `PeerId` supports base36 encode/decode.
3. The P1 scenarios pass consistently in CI for at least two consecutive release-candidate cycles.
4. The Council of Five reviews and approves the promotion in a follow-up decision document.

---

## 5. Required Amendments to INTEROP_TESTS_SPEC.md

1. Update the test matrix in `INTEROP_TESTS_SPEC.md` section 4.1 to reflect the P0/P1 split above.
2. Add the P1 `allowed-to-fail` / `allowed-to-skip` annotation and the separate status check requirement.
3. Move Helia jobs to a separate nightly workflow, not the PR workflow.
4. Cap the PR interop job at 10 minutes and tighten P1 timeouts to 60 s while stabilizing.
5. Add a packet-capture retention limit of 7 days and a synthetic-data requirement.
6. Add the promotion preconditions as a new section.

---

## 6. Council Signatures

| Member | Position |
|--------|----------|
| Coherence | Approve the split-tier scope. |
| Capability | Approve, with Kubo data-exchange tests as the v2.2 minimum. |
| Safety | Approve, because unstable DHT/IPNS must not gate the release. |
| Efficiency | Approve, subject to the 10-minute P0 job cap and nightly Helia workflow. |
| Evolution | Approve; the P1 tier creates a clear path to P0 promotion. |

**Decision:** The interop test suite is **P0 required**, but only **CAR, Bitswap, and gateway** are **P0 release-blocking**. **DHT and IPNS** are **P1 allowed-to-fail/allowed-to-skip**. **Helia** is **P1 optional/nightly**. The CI job **fails the build on P0 failures** and **reports P1 results as a separate non-blocking status**.
