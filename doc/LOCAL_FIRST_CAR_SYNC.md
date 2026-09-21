# Local-First CAR State Sync

An offline-first state synchronization pattern for `dart_ipfs` apps. Local mutations are journaled on-device, periodically folded into a canonical manifest, and snapshotted to disk as a **CAR (Content Addressable aRchive)** file. On cold start, reinstall, or reconnect, the CAR is re-imported and state is rehydrated — with every block hash-verified against its CID.

This document is the pattern companion to the reactive bindings defined in [FLUTTER_REACTIVE_BINDINGS_SPEC](specs/features/FLUTTER_REACTIVE_BINDINGS_SPEC.md) and the CAR wire format in [CAR_FORMAT_SPEC](specs/features/CAR_FORMAT_SPEC.md).

## Why CAR for state sync

- **Content-addressed**: the CAR header's root CIDs uniquely identify a checkpoint. Two devices holding the same root CID hold the same state — no ambiguity, no vector clocks needed for equality checks.
- **Self-verifying**: `IPFSNode.importCAR` validates every block against its CID before it reaches the datastore, so a truncated or tampered archive fails loudly instead of corrupting app state.
- **Portable**: a CAR is a single flat file — easy to persist to app storage, hand to a peer over Bitswap/PubSub, or pin to a remote pinning service.
- **Already in the API**: `node.exportCAR(rootCid)` / `node.importCAR(bytes)` are first-class public methods; `CarReader` / `CarWriter` are exported for custom pipelines.

## The pattern

```
        ┌────────────────────── LOCAL DEVICE ──────────────────────┐
        │                                                        │
  user  │   ┌──────────┐    fold     ┌────────────┐               │
 edits ─┼──▶│ journal  │────────────▶│ manifest   │               │
        │   │ (Drift / │             │  (JSON)    │               │
        │   │  Hive /  │             └─────┬──────┘               │
        │   │  JSONL)  │                   │ addDirectory + pin   │
        │   └──────────┘                   ▼                       │
        │                          ┌────────────┐   exportCAR      │
        │                          │  UnixFS    │──────────▶ ┌────┐│
        │                          │    DAG     │            │CAR ││
        │                          └────────────┘            └────┘│
        └───────────────────────────────────────────────┬─────────┘
                                                        │ reconnect
                                                        ▼
                                          peer / pinning service
                                                        │
        restore:  importCAR(carBytes) → get(rootCid, path: 'manifest.json')
        merge:    importCAR(remoteCar) → fold remote journal over local state
```

### 1. Journal mutations locally

Every write goes to an append-only journal first. The journal is the source of truth; IPFS state is derived from it.

- **Pure Dart (this repo's template)**: JSON Lines file (`journal.jsonl`) via `dart:io`.
- **Drift**: an append-only `JournalEntries` table — swap-in point marked in the template.
- **Hive**: `box.add(jsonEncode(record))` — swap-in point marked in the template.

### 2. Checkpoint to CAR

Fold the journal into a canonical manifest, bundle `{manifest.json, journal.jsonl}` into a UnixFS directory (single root CID), pin it, then export:

```dart
final rootCid = await node.addDirectory({
  'manifest.json': manifestBytes,
  'journal.jsonl': journalBytes,
});
await node.pin(rootCid);
final carBytes = await node.exportCAR(rootCid);
await File('state.car').writeAsBytes(carBytes);
await File('checkpoint.json').writeAsString(jsonEncode({'rootCid': rootCid}));
```

Keep the root CID in a small sidecar (`checkpoint.json`) — or in IPNS via `node.publishIPNS(rootCid, keyName: ...)` for a mutable pointer that survives across devices.

### 3. Restore on cold start / reconnect

```dart
final carBytes = await File('state.car').readAsBytes();
await node.importCAR(carBytes);              // blocks hash-verified on import
final manifest = await node.get(rootCid, path: 'manifest.json');
```

### 4. Merge remote checkpoints

On reconnect, peers exchange checkpoint CARs. Import the remote CAR, read its `journal.jsonl`, and fold it over local state using your app's conflict-resolution policy (last-writer-wins per key is the baseline; CRDTs slot into the same fold).

## Files

| Artifact | Location |
| --- | --- |
| Runnable template (pure Dart, JSONL journal + marked Drift/Hive swap-ins) | [`templates/local_first_car_sync.dart`](../templates/local_first_car_sync.dart) |
| Production sample — Offline-First Mobile Photo Vault | [`example/photo_vault`](../example/photo_vault) |
| Production sample — Encrypted P2P PubSub Mesh | [`example/p2p_pubsub_mesh`](../example/p2p_pubsub_mesh) |

## Notes for mobile apps

- `IPFSConfig(offline: true)` keeps all work local; flip to `offline: false` when connectivity returns — the CAR checkpoint carries over unchanged.
- Combine with `MobileLifecycleAdapter` (v1.13) to flush a checkpoint when the OS pauses the app.
- CAR v2 (`CarWriter(v2: true, index: true)`) adds a multihash index for random access into large archives if your checkpoint grows beyond a few MiB.
