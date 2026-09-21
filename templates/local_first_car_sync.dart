// templates/local_first_car_sync.dart
//
// Template: Local-First CAR State Sync
//
// A documented pattern for offline-first apps that keep their state on IPFS:
//
//   1. Every user mutation is appended to a local journal (here a JSONL file —
//      the pure-Dart stand-in for a Drift table or a Hive box; swap-in points
//      for both are marked in the TEMPLATE comment blocks below).
//   2. `checkpoint()` folds the journal into a canonical manifest, stores it
//      in IPFS (`addDirectory` + `pin`), and exports the resulting DAG as a
//      CAR file (`exportCAR`) persisted next to the journal.
//   3. `restore()` — cold start, reinstall, or reconnect — re-imports the CAR
//      (`importCAR`) and rehydrates state from the manifest.
//   4. `mergeRemote(carBytes)` ingests a CAR received from a peer so CRDT-style
//      conflict resolution can run over the union of both journals.
//
// Because CAR archives are content-addressed, a checkpoint doubles as a
// verifiable, portable backup: import validates every block against its CID.
//
// See doc/LOCAL_FIRST_CAR_SYNC.md for the full pattern description.
//
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/dart_ipfs.dart';

/// Local-first state store backed by a journal file and IPFS CAR checkpoints.
///
/// The journal is the source of truth; the CAR archive is a durable,
/// content-addressed snapshot of the folded state.
class LocalFirstCarSync {
  /// Creates a sync store rooted at [directory] and writing to [node].
  LocalFirstCarSync({required this.node, required this.directory});

  /// The IPFS node used for pinning and CAR export/import.
  final IPFSNode node;

  /// Directory holding the journal, checkpoint metadata, and the CAR archive.
  final Directory directory;

  File get _journalFile => File('${directory.path}/journal.jsonl');
  File get _checkpointFile => File('${directory.path}/checkpoint.json');
  File get _carFile => File('${directory.path}/state.car');

  /// Prepares the on-disk layout. Safe to call on every app start.
  Future<void> init() async {
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    if (!await _journalFile.exists()) {
      await _journalFile.create();
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // TEMPLATE — Drift integration point (journal persistence)
  // ────────────────────────────────────────────────────────────────────────
  // To back the journal with Drift instead of a JSONL file, declare an
  // append-only table and replace [mutate] / [_foldJournal]:
  //
  //   class JournalEntries extends Table {
  //     IntColumn get seq => integer().autoIncrement()();
  //     TextColumn get op => text()();
  //     TextColumn get payload => text()(); // JSON-encoded mutation
  //     DateTimeColumn get at => dateTime()();
  //   }
  //
  //   // inside mutate():
  //   await db.into(db.journalEntries).insert(
  //         JournalEntriesCompanion.insert(
  //           op: op,
  //           payload: jsonEncode(payload),
  //           at: DateTime.now().toUtc(),
  //         ),
  //       );
  //
  //   // inside _foldJournal():
  //   final rows = await db.select(db.journalEntries).get();
  //
  // ────────────────────────────────────────────────────────────────────────
  // TEMPLATE — Hive integration point (journal persistence)
  // ────────────────────────────────────────────────────────────────────────
  // To back the journal with Hive instead:
  //
  //   final box = await Hive.openBox<String>('journal');
  //
  //   // inside mutate():
  //   await box.add(jsonEncode({'op': op, 'payload': payload, 'at': ...}));
  //
  //   // inside _foldJournal():
  //   final rows = box.values.map((e) => jsonDecode(e) as Map<String, dynamic>);
  // ────────────────────────────────────────────────────────────────────────

  /// Appends a mutation to the local journal.
  ///
  /// [op] is a reducer-style operation name (`'set'`, `'delete'`, `'add'`…)
  /// and [payload] is the operation's JSON-encodable arguments.
  Future<void> mutate(String op, Map<String, Object?> payload) async {
    final record = <String, Object?>{
      'op': op,
      'payload': payload,
      'at': DateTime.now().toUtc().toIso8601String(),
    };
    await _journalFile.writeAsString(
      '${jsonEncode(record)}\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  /// Folds the journal into the canonical state map.
  ///
  /// Supported ops: `set` (`{key, value}`) and `delete` (`{key}`).
  /// Extend this reducer — or swap in a Drift query / Hive fold — for your
  /// app's domain operations.
  Future<Map<String, Object?>> _foldJournal() async {
    final state = <String, Object?>{};
    final lines = await _journalFile.readAsLines();
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final record = jsonDecode(line) as Map<String, dynamic>;
      final op = record['op'] as String;
      final payload = (record['payload'] as Map).cast<String, Object?>();
      switch (op) {
        case 'set':
          state[payload['key'] as String] = payload['value'];
        case 'delete':
          state.remove(payload['key']);
        default:
          // Unknown ops are ignored so older app versions can read newer
          // journals without crashing (forward compatibility).
          break;
      }
    }
    return state;
  }

  /// Writes a content-addressed checkpoint and returns its root CID.
  ///
  /// The manifest plus the raw journal are bundled into a UnixFS directory so
  /// a single root CID captures the full recoverable state. The DAG is then
  /// exported verbatim as a CAR archive beside the journal.
  Future<String> checkpoint() async {
    final state = await _foldJournal();
    final manifest = Uint8List.fromList(
      utf8.encode(
        jsonEncode(<String, Object?>{
          'version': 1,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'state': state,
        }),
      ),
    );
    final journalBytes = Uint8List.fromList(await _journalFile.readAsBytes());

    final rootCid = await node.addDirectory(<String, dynamic>{
      'manifest.json': manifest,
      'journal.jsonl': journalBytes,
    });
    await node.pin(rootCid);

    final carBytes = await node.exportCAR(rootCid);
    await _carFile.writeAsBytes(carBytes, flush: true);
    await _checkpointFile.writeAsString(
      jsonEncode(<String, Object?>{
        'rootCid': rootCid,
        'carBytes': carBytes.length,
        'checkpointedAt': DateTime.now().toUtc().toIso8601String(),
      }),
      flush: true,
    );
    return rootCid;
  }

  /// Re-imports the last checkpoint CAR and returns the restored state map.
  ///
  /// Returns `null` when no checkpoint exists yet (first launch). Every block
  /// is hash-verified during [IPFSNode.importCAR]; a corrupt archive throws a
  /// [CarException] rather than poisoning the store.
  Future<Map<String, Object?>?> restore() async {
    if (!await _carFile.exists() || !await _checkpointFile.exists()) {
      return null;
    }
    final checkpoint =
        jsonDecode(await _checkpointFile.readAsString())
            as Map<String, dynamic>;
    final rootCid = checkpoint['rootCid'] as String;

    final carBytes = await _carFile.readAsBytes();
    await node.importCAR(Uint8List.fromList(carBytes));

    final manifestBytes = await node.get(rootCid, path: 'manifest.json');
    if (manifestBytes == null) {
      throw StateError('CAR restored but manifest.json is missing');
    }
    final manifest =
        jsonDecode(utf8.decode(manifestBytes)) as Map<String, dynamic>;
    return (manifest['state'] as Map).cast<String, Object?>();
  }

  /// Imports a CAR archive received from a peer and returns its journal lines.
  ///
  /// Use this on reconnect to merge remote mutations into the local journal —
  /// e.g. last-writer-wins per key, or a CRDT reducer in [_foldJournal].
  Future<List<String>> mergeRemote(Uint8List carBytes, String rootCid) async {
    await node.importCAR(carBytes);
    final journalBytes = await node.get(rootCid, path: 'journal.jsonl');
    if (journalBytes == null) return const <String>[];
    return utf8.decode(journalBytes).split('\n').where((l) {
      return l.trim().isNotEmpty;
    }).toList();
  }
}

/// Demonstrates the full offline → checkpoint → wipe → restore loop.
void main() async {
  final workDir = Directory('${Directory.systemTemp.path}/car_sync_demo');

  // 1. Offline node: all state stays local until connectivity returns.
  final node = await IPFSNode.create(
    IPFSConfig(
      offline: true,
      dataPath: '${workDir.path}/ipfs',
      datastorePath: '${workDir.path}/ipfs/datastore',
      keystorePath: '${workDir.path}/ipfs/keystore',
      debug: false,
      enableMetrics: false,
    ),
  );
  await node.start();

  final sync = LocalFirstCarSync(
    node: node,
    directory: Directory('${workDir.path}/app_state'),
  );
  await sync.init();

  // 2. Offline mutations accumulate in the journal.
  await sync.mutate('set', {'key': 'profile.name', 'value': 'ada'});
  await sync.mutate('set', {'key': 'settings.theme', 'value': 'dark'});
  await sync.mutate('set', {'key': 'draft.body', 'value': 'wip'});
  await sync.mutate('delete', {'key': 'draft.body'});

  // 3. Checkpoint: the journal folds into a manifest exported as a CAR.
  final rootCid = await sync.checkpoint();
  print('Checkpoint CAR written. Root CID: $rootCid');

  // 4. Restore: simulate a reinstall/reconnect — the CAR alone rebuilds state.
  final restored = await sync.restore();
  print('Restored state: ${jsonEncode(restored)}');

  // 5. On reconnect, mergeRemote() ingests a peer's checkpoint CAR for
  //    CRDT/LWW reconciliation before the next local checkpoint.
  await node.stop();
}
