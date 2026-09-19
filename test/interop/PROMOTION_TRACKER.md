# Interop Promotion Tracker — DHT/IPNS P1 → P0

**Purpose:** Track the promotion preconditions defined in
`MAINTAINER_DECISION_INTEROP_SCOPE` §4.5 and `INTEROP_TESTS_SPEC` §8 for
promoting the DHT provide/find and IPNS resolution scenarios from
P1 allowed-to-fail to P0 release-blocking.

**Promotion rule:** A P1 scenario may be promoted to P0 only after **all** of
the following hold:

1. The underlying networking spec is implemented (`DHT_INTEGRATION_SPEC` /
   `IPNS_SPEC`), including iterative queries with request/response
   correlation for DHT, and removal of the `QmResolvedCid` fallback plus
   base36 `PeerId` support for IPNS.
2. The scenario passes consistently in CI for **at least two consecutive
   release-candidate cycles**.
3. The maintainer approves the promotion in a follow-up decision document.

---

## 1. Implementation Preconditions

Verified against `master` on **2026-09-19**.

| # | Precondition | Scenario | Status | Evidence |
|---|--------------|----------|--------|----------|
| 1a | Iterative Kademlia queries | DHT | ✅ Met | `dht_client.dart` `findProviders`/`findPeer` run alpha-batched expansion over a XOR-sorted peer queue (`_SortedPeerQueue`, ~lines 250–400) |
| 1b | Request/response correlation | DHT | ✅ Met | `dht_client.dart` `_pendingRequests` completer map keyed by `DHTEnvelope.requestId` (~lines 104, 942–1026) |
| 2a | `QmResolvedCid` fallback removed | IPNS | ✅ Met | No `QmResolvedCid` reference remains under `lib/` |
| 2b | `PeerId` base36 encode/decode | IPNS | ✅ Met | `lib/src/core/types/peer_id.dart` `PeerId.fromBase36` (line ~19) / `toBase36` (line ~75); used by `ipns_handler.dart` name validation |
| 2c | Real IPNS publish (no stub) | IPNS | ✅ Met | `ipns_handler.dart` `publish`/`publishWithKeyPair`/`_publishRecord` sign and publish records via DHT/pubsub (~lines 256–443) |

**Conclusion:** The implementation preconditions for **both** DHT and IPNS
appear met. The remaining gates are the consecutive-green-RC-cycle
requirement (§2 below) and maintainer approval (§3).

## 2. Green Release-Candidate Cycle Ledger

Append one row per release-candidate cycle. A cycle counts toward promotion
only if the `interop-p1` job for that RC tag completed **green** (the job is
`continue-on-error`, so check the step outcome, not the workflow status).

| RC cycle | Date | CI run | DHT provide/find | IPNS resolution | Counts toward promotion |
|----------|------|--------|------------------|-----------------|-------------------------|
| _(none recorded yet)_ | — | — | — | — | — |

**Consecutive green cycles:** DHT `0/2` · IPNS `0/2`

## 3. Promotion Decision Record

| Scenario | Decision | Date | Rationale |
|----------|----------|------|-----------|
| IPNS resolution | **Remains P1** | 2026-09-19 | Implementation preconditions met (real publish, base36 peer IDs, no `QmResolvedCid` fallback), but §4.5 also requires two consecutive green RC cycles (0/2 recorded) and a maintainer follow-up decision. Eligible for promotion evaluation once the ledger shows 2/2. |
| DHT provide/find | **Remains P1** | 2026-09-19 | Iterative queries with request/response correlation are implemented, but two consecutive green RC cycles (0/2) and maintainer approval are still required. |

**How to record a cycle:** after each RC tag, run or inspect the
`interop-p1` job of `.github/workflows/interop.yml` for that tag, append a
row to the ledger above, and update the consecutive-green counters. When a
scenario reaches `2/2`, file a maintainer decision document under
`doc/specs/decisions/` and flip the scenario's tag from `p1` to `p0` (and
move its step into the blocking job) in the same change.
