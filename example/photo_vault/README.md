# Offline-First Mobile Photo Vault

A production-pattern sample for `dart_ipfs` demonstrating **Local-First CAR State Sync**: photos captured on a device are stored in IPFS as a UnixFS directory, pinned, and exported to a single CAR backup file. A fresh install restores the entire vault — manifest and photos — from that CAR alone, with every block hash-verified on import.

## What it demonstrates

- `IPFSNode` running fully offline (`IPFSConfig(offline: true)`) — capture works with zero connectivity.
- `addDirectory` + `pin`: one root CID covers the vault manifest and all photos.
- `exportCAR` → `dart:io` persistence: the DAG becomes a portable, self-verifying backup file.
- `importCAR` + `get(cid, path: ...)`: cold-start restore and path traversal into the restored DAG.

On a real phone, Phase 1 runs inside a Flutter app (see `example/ipfs_dashboard` for UI bindings) and the CAR file is what gets handed to a peer or pinning service on reconnect. See [`doc/LOCAL_FIRST_CAR_SYNC.md`](../../doc/LOCAL_FIRST_CAR_SYNC.md) for the full pattern and [`templates/local_first_car_sync.dart`](../../templates/local_first_car_sync.dart) for the Drift/Hive journal integration template.

## Running

```bash
cd example/photo_vault
dart pub get
dart run bin/main.dart
```

Expected output: Phase 1 writes `vault_backup.car`; Phase 2 restores and verifies all photos byte-for-byte into an independent datastore.
