# Council of Five Decision Record — Post-2.0.0 Backlog Disposition

## Case Definition

- **Subject**: Disposition of every outstanding item left after the `dart_ipfs 2.0.0` release — the unpublished `ipfs_libp2p` fork release, the umbrella's dependency floor, the long-term libp2p strategy, the four remaining hardening items in issue #118, the upstream `dart_libp2p` watch in issue #124, and repository hygiene.
- **Date**: 2026-10-24
- **Presiding Chairman**: Ciel (Master's AI Partner Intelligence)
- **Council of Five Lenses**: Coherence, Capability, Safety, Efficiency, Evolution.
- **Context**: `dart_ipfs 2.0.0`, `dart_ipfs_core 1.14.0` and `dart_ipfs_quic 0.3.0` published to pub.dev from `main` (`8ff189e4`); the `ipfs_libp2p` fork repaired and merged as `0.6.0` (`b40098f`) but **not yet on pub.dev**; upstream PR `stephanfeb/dart_libp2p#30` open.

---

## Verification Evidence

| Criterion | Result | Notes |
| --- | --- | --- |
| `dart_ipfs 2.0.0` on pub.dev | published | 2026-10-24T12:49:54Z |
| `dart_ipfs_core 1.14.0` / `dart_ipfs_quic 0.3.0` | published | satellites published before the umbrella, per the documented tag ordering |
| Consumer graph of `dart_ipfs 2.0.0` | **`dart_udx 0.3.1`** | A consumer resolving `dart_ipfs: ^2.0.0` from pub.dev resolves `dart_udx 0.3.1` — the release that `SECURITY.md` calls vulnerable. The `dart_udx ^2.0.3` pin exists **only** as a `dependency_overrides` entry, and overrides are not published. `ipfs_libp2p 0.5.11` declares `dart_udx: ^0.3.1`. |
| Consumer graph — `xml` / `port_forwarder` | `xml 7.1.0`, `port_forwarder` absent | The vendored port-forwarding copy did deliver the `xml` pin to consumers. The `xml` wording in `SECURITY.md` is now stale and should be corrected. |
| `ipfs_libp2p` fork `main` (`b40098f`) | analyze clean, 310 tests pass, 0 fail | Was 14 failing on `main`; the fork also gained CI and a publish workflow it previously lacked entirely. |
| `ipfs_libp2p` 0.6.0 publish attempt | **failed** — `Authentication failed!` | pub.dev has no trusted publisher registered for `jxoesneon/ipfs_libp2p`. The `v0.6.0` tag exists; the package is not published. |
| Fork publish workflow action pinning | **unpinned** | The fork's `publish.yml` uses `actions/checkout@v5` and `dart-lang/setup-dart@v1`; this repository pins every action by SHA. An unpinned action in a publish workflow is a live path to the pub.dev token. |
| Fork README install instructions | **wrong package name** | `README.md` says "Add `dart_libp2p` … `dart_libp2p: ^0.5.2`" and links `pub.dev/packages/dart_libp2p`, while the published package is `ipfs_libp2p`. (The fork's `pubspec.yaml` metadata is correct — `repository:` points at `jxoesneon/ipfs_libp2p`.) |
| Upstream `dart_libp2p` 4.9.1 dependency walls | `protobuf: ^3.1.0`, `dart_udx: ^4.3.0` | `dart_udx` v3 is a wire-format break against v2; `protobuf 3.x` conflicts with this project's `protobuf ^6.1.0`. A re-base onto 4.9.x is therefore resolution-incompatible today, not merely risky. |
| Upstream CI | **none** | `stephanfeb/dart_libp2p` has no `.github/workflows` at all — the direct cause of two test files being left uncompilable on Dart 3.13. |
| `CarWriter.closeStream()` | **does not stream** | `closeStream()` calls `_buildV1Payload()`, which materialises the whole archive; peak memory is ~3× the archive size. Switching `close()` for `closeStream()` would change nothing measurable. |
| Upstream PR #30 | open, clean | 3 files, +84/−7: two Dart 3.13 test-compile fixes + closed-stream writes no longer logged SEVERE. |
| Open items in issue #118 | 4 confirmed present | CAR buffering; tar symlink typeflag; `ls` on a non-directory; resolver duplication (four resolvers exist). |

---

## Council Deliberation & Voting Matrix

| Member | Lens | D1 publish 0.6.0 | D2 umbrella → ^0.6.0 | D3 libp2p strategy | D4 stream CAR | D5 symlinks | D6 `ls` parity | D7 resolver convergence | D8 typo | D9 hygiene |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **The Architect** — Coherence | architecture & standards | CONDITIONAL | CONDITIONAL | CONDITIONAL (stay) | CONDITIONAL | PASS | PASS | PASS | **VETO** | PASS |
| **The Engineer** — Capability | utility & market gap | PASS | PASS | CONDITIONAL (stay) | PASS | CONDITIONAL | PASS | PASS | CONDITIONAL | PASS |
| **The Warden** — Safety | integrity & security | PASS | CONDITIONAL | CONDITIONAL (stay) | CONDITIONAL | CONDITIONAL | PASS | CONDITIONAL | **VETO** | CONDITIONAL |
| **The Steward** — Efficiency | performance & footprint | PASS | PASS | CONDITIONAL (stay) | PASS | PASS | PASS | CONDITIONAL | PASS | CONDITIONAL |
| **The Visionary** — Evolution | roadmap & positioning | PASS | PASS | CONDITIONAL (stay, with milestones) | CONDITIONAL | PASS | PASS | PASS | **VETO** | PASS |

**Unanimous (5/5):** D1 and D2 are to be done, and they are the critical path. D3: stay on the fork's 1.0.3-based line — no re-base. D8: do not rewrite published history. D9: prune stale branches, keep the fork's CI.

**Divided, resolved by the Chairman:** D5 and D6 both turn on *what Kubo actually does*, and the Council could not settle that from the repo alone (the Engineer cited `boxo/files/tarwriter.go` and Kubo's `add.go` help text; the Visionary cited `CLI_SPEC.md` and a contrary reading of Kubo's `dagreader.go` returning `ErrCantReadSymlinks`). The Chairman rules: **capture Kubo's behaviour with the existing `test/interop` harness before writing code.** The current behaviour is wrong under every reading, so the fix direction is agreed; only the exact shape is open.

---

## Dissent & Reconciliation

1. **D6 — chunk links or an error?** The Architect, Engineer and Visionary read Kubo's `ipfs ls <file-cid>` as printing the file's chunk links; the Warden reads it as an error. **Ruling: verify against Kubo in `test/interop`, then implement to the observed behaviour.** Both readings agree that today's empty listing is wrong: it is indistinguishable from an empty directory to every consumer, and `MFSManager` already throws for the same case (`mfs_manager.dart:571`), so the two subsystems disagree today.
2. **D5 — gateway symlink behaviour.** The Architect proposed the gateway *follow* the symlink; the Engineer observed that Kubo's `dagreader` returns `ErrCantReadSymlinks` for a symlink node. **Ruling: same — measure Kubo first.** The tar side is not in doubt: Kubo's tar writer emits typeflag `'2'` with the link target, and ours emits the symlink node as a regular file.
3. **D2 — the `dart_ipfs_quic` version number.** The Architect proposed `0.3.1`; the Steward proposed `0.4.0`. **Ruling: `0.4.0`** — under 0.x semantics a change to the dependency floor and the SDK floor is breaking, and mislabelling it a patch release would repeat the mistake this release just fixed in `dart_ipfs`.
4. **D9 — how to offer CI upstream.** The Steward proposed appending the CI workflow to PR #30; the Architect proposed a separate PR. **Ruling: separate PR**, so #30 stays reviewable as a pure fix.

---

## Synthesis & Chairman's Verdict

**VERDICT: APPROVED (5/5 on the critical path, 4/5 on the backlog items, 5/5 VETO on rewriting published history).**

### Binding finding

The single most important discovery is not on any backlog list: **the `dart_udx ^2.0.3` security pin has never reached a consumer.** `SECURITY.md` states the pin protects the UDP transport; in reality it is a `dependency_overrides` entry, overrides are not published, and every pub.dev consumer of `dart_ipfs 2.0.0` resolves `dart_udx 0.3.1` — the version `SECURITY.md` itself calls vulnerable. The pin becomes real only when it is carried by a *dependency's own constraint*, which is exactly what `ipfs_libp2p 0.6.0` provides (`dart_udx: ^2.0.3`). D1 and D2 are therefore not housekeeping: they are the remediation of a live, published security gap.

### Rulings

**D1 — Publish `ipfs_libp2p 0.6.0`. APPROVED (conditional).**
Register the pub.dev trusted publisher for `jxoesneon/ipfs_libp2p` (workflow file `publish.yml`, blank environment), then re-run the failed publish job — the `v0.6.0` tag already exists and equals `main`; do **not** cut a new tag to work around a publish failure. Before publishing: **pin the fork's workflow actions by SHA** (the repository's own convention — an unpinned action in a publish workflow is a path to the pub.dev token), **correct the README install instructions** to `ipfs_libp2p: ^0.6.0` and the pub.dev link, and add a `pana` step so the next failure surfaces before publish. Record the publisher id in `doc/MAINTAINER_GUIDE.md` §1a.

**D2 — Move the umbrella to `ipfs_libp2p: ^0.6.0` in 2.0.1. APPROVED (conditional on D1).**
Two publishes, two tags: `dart_ipfs_quic 0.4.0` (with `ipfs_libp2p: ^0.6.0` and an SDK floor of `^3.13.0`) first, then the umbrella `2.0.1` (root `ipfs_libp2p: ^0.6.0`, `dart_ipfs_quic: ^0.4.0`). `dart_ipfs_core` has no libp2p dependency and needs **no** release. Wait for `ipfs_libp2p 0.6.0` to appear in pub.dev's `.versions[]` before publishing the umbrella. Then **drop the `dart_udx` overrides** from the umbrella and from `dart_ipfs_quic` — they become redundant — and correct `SECURITY.md` to state that the pin is carried by `ipfs_libp2p`'s own constraint. Note in the changelog that `dart_udx` 0.3.x → 2.x is a UDP wire-format change and re-run the interop suite before tagging. A dependency-only release has no changed `lib/` lines, so the changed-line coverage gate passes trivially — which is why this must ship alone, not bundled with D4–D7.

**D3 — libp2p strategy: stay on the fork's 1.0.3-based line, with a scheduled convergence path. APPROVED (conditional).**
A re-base onto upstream 4.9.x is resolution-incompatible today: upstream pins `protobuf ^3.1.0` (this project is on `^6.1.0`) and `dart_udx ^4.3.0`, whose wire protocol v3 does not interoperate with v2 — a hard break against both the `SECURITY.md` pin and published 2.0.0 peers. Adopt the Visionary's trajectory as the roadmap:
- **M1 (2.0.1, now)** — bridge: fork 0.6.0 published, umbrella on `^0.6.0`. Fork API frozen; fixes only.
- **M2 (2.1)** — shrink the fork to zero diff: upstream PRs for protobuf 6, for CI, plus the surviving fork deltas (null-`setDeadline` forwarding, yamux read-wait disarm, identify false NO-COMPLETER) — each a small, self-contained PR.
- **M3 (2.1)** — `rebase/4.9.x` branch in the fork: upstream 4.9.1 + surviving deltas, with `dart_udx` v3 behind a transport flag and v2 retained as default until a published-peer matrix justifies the break.
- **M4 (3.0)** — depend on upstream `dart_libp2p ^4.9+` directly; retire the fork (final release marked deprecated, repo archived).

Fix the drift bookkeeping now: `tool/upstream_dart_libp2p_version.txt` reads `1.0.3` while upstream is `4.9.1`, so `upstream_watch.yml` reopens issue #124 every Monday as noise. Split the record into a *merge-base* and an *upstream-reviewed* field, and add `doc/LIBP2P_UPSTREAM_CONVERGENCE.md` recording why 4.9.1 is not yet adoptable.

**D4 — Stream CAR output. APPROVED (conditional), and larger than it looks.**
`closeStream()` does not stream: `_buildV1Payload()` materialises the whole archive, and `close()` copies it again — peak memory is ~3× the archive, so the 1 GiB cap can mean a ~3 GiB RSS spike and an OOM kill on Android. Switching to `closeStream()` alone would change nothing measurable. Real work: emit the CAR v1 header first (roots are known up front) and yield each section as it is produced, so peak memory becomes O(one block) plus the visited set. Keep `maxCarResponseBytes`/`maxCarResponseBlocks`/`maxCarDepth` — they now bound CPU and network rather than RAM — but define the new failure semantics explicitly: once the header is sent, an over-budget or missing block must **abort the stream with an error**, never a silent EOF, and `Content-Length` must be dropped for streamed responses (kept only for the identity-root header-only CAR, whose size is known). Do the gateway first, RPC `dag/export` after. Add a test that asserts peak retained bytes, not just correctness.

**D5 — Symlink parity. APPROVED (conditional on measurement).**
Emit tar typeflag `'2'` with the link target for UnixFS symlink nodes; today `_tarAddNode` emits a symlink node as a regular file containing the target's bytes, which extracts wrong. **Security condition:** the link target is attacker-controlled DAG data — `_sanitizeTarName` cleans the *entry name* but not the *linkname* — so a `../` or absolute target would let a malicious DAG write outside the extraction root. Sanitise or refuse the target; never emit it raw. For the gateway, capture Kubo's actual response for a symlink CID and for a path traversing a symlink using the `test/interop` Kubo client, write it into `doc/specs/PROTOCOL_COMPLIANCE_SPEC.md`, and implement to that spec — the Engineer reports Kubo's `dagreader` returns `ErrCantReadSymlinks`, the Architect expects the gateway to follow the link, and the Council could not settle it from the repo.

**D6 — `ls` on a non-directory. APPROVED.**
Implement Kubo parity after measuring it in `test/interop`. Under every reading the current behaviour is wrong: `ContentManager.ls` logs a warning and returns `[]`, which `/api/v0/ls` reports as a 200 with an empty `Objects` list — indistinguishable from an empty directory — while `MFSManager` throws for the same case. Align the two, and keep the error distinct from a genuinely empty directory so clients can tell them apart.

**D7 — Resolver convergence. APPROVED, in a dedicated release (v2.1).**
There are now four path resolvers: the gateway hand-mirrors HAMT descent (`_serveHamtShard`/`_hamtLookup`), `UnixFSPathResolver` does it correctly with symlink and cycle handling, `IPLDHandler` has two flat-scan variants, and `MFSManager._resolvePath` matches flat link names only — so MFS path resolution and `ls` **cannot enter a HAMT shard at all** and silently diverge on sharded directories. That is a live correctness bug, not a tidiness concern, and it is the highest-leverage item on the list. Sequence it: gateway first (via a `_GatewayBlockStore` adapter mirroring `_RpcBlockStore`, replacing the duplicated traversal), then `IPLDHandler`; leave `MFSManager` for last, because its `..`-clamping and write semantics differ deliberately from the resolver. Keep the resolver in the umbrella, not `dart_ipfs_core` — it depends on generated protobuf, and `ENGINEERING_NOTES.md` (WP-07) requires core to stay protobuf-free. Land it with a parity matrix (plain dir, HAMT dir, symlink, symlink cycle, deep path) asserted against Kubo, and preserve the gateway's `index.html` redirect and `_maxIndexHtmlDepth` cap.

**D8 — The `chore(reps):` commit subject. VETO the rewrite (4/5 VETO, the Engineer concurs in substance).**
`08514d83` is an ancestor of the published `v2.0.0`, `core-v1.14.0` and `quic-v0.3.0` tags. Rewriting it re-points three live release tags and invalidates the git provenance pub.dev records for three published packages; `doc/MAINTAINER_GUIDE.md` forbids re-tagging a version whose CI has run. Fix forward: correct the commit-scope convention in `doc/CONTRIBUTING.md` so the next squash reads `chore(deps):`.

**D9 — Hygiene. APPROVED (conditional).**
Delete the stale `dependabot/go_modules/*` branches and `merge-upstream-1.0.3` (now an ancestor of `main`) on the fork; keep `fix/dart-3.13-test-compile-and-closed-stream-logs` while upstream PR #30 is open (it is the PR's head — deleting it orphans the PR), and delete it afterwards. Keep `jxoesneon/dart_libp2p` while #30 is open as the PR-hosting mirror; archive it once #30 lands, because two live "dart_libp2p" remotes is a namespace-confusion trap. Keep the fork's own CI — it is the fork's main differentiator today, since upstream has none. On this repository, prune the merged `chore/deps/*` branches and keep `gh-pages`. Offer upstream a CI workflow as a **separate** PR after #30 lands.

---

## Actions (sequenced)

| # | Action | Owner | Trigger / Gate |
| --- | --- | --- | --- |
| 1 | Register the pub.dev trusted publisher for `jxoesneon/ipfs_libp2p` | maintainer (pub.dev UI) | blocking for #2 |
| 2 | Pin the fork's workflow actions by SHA; fix the fork README install instructions; add a `pana` step | maintainer | before #3 |
| 3 | Re-run the failed `v0.6.0` publish job | maintainer | after #1, #2 |
| 4 | Publish `dart_ipfs_quic 0.4.0` (`ipfs_libp2p: ^0.6.0`, SDK `^3.13.0`), tag `quic-v0.4.0` | maintainer | after #3; interop green |
| 5 | Publish `dart_ipfs 2.0.1` (root `ipfs_libp2p: ^0.6.0`, `dart_ipfs_quic: ^0.4.0`), drop the `dart_udx` overrides, correct `SECURITY.md` | maintainer | after #4, and after `ipfs_libp2p 0.6.0` appears in pub.dev `.versions[]` |
| 6 | Split the upstream-watch baseline into merge-base and upstream-reviewed; add `doc/LIBP2P_UPSTREAM_CONVERGENCE.md`; close #124's drift noise | maintainer | parallel |
| 7 | Measure Kubo's `ls` and symlink behaviour in `test/interop`; write it into `PROTOCOL_COMPLIANCE_SPEC.md` | maintainer | before #8 |
| 8 | v2.1 workstream: resolver convergence (gateway → IPLDHandler → MFS), then true CAR streaming, then symlink parity | maintainer | dedicated release, 100% changed-line coverage |
| 9 | Upstream PRs: protobuf 6, CI workflow, fork deltas | maintainer | M2 |
| 10 | Prune stale branches in both repos; fix the commit-scope convention | maintainer | parallel |

---

## Scores

| Dimension | Score |
| --- | --- |
| Coherence | 8.5 |
| Capability | 8.5 |
| Safety | 8.5 |
| Efficiency | 8.0 |
| Evolution | 8.5 |

**Overall: 8.4/10 — APPROVED, with D1 → D2 as the binding critical path.**

**Date:** 2026-10-24

**Workstreams:** `dart_ipfs`, `ipfs_libp2p`, `release_management`, `security_audits`, `protocol_compliance`
