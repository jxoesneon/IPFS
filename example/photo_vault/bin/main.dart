// Offline-First Mobile Photo Vault — dart_ipfs sample.
//
// Demonstrates the Local-First CAR State Sync pattern end to end:
//   Phase 1 (device, offline): photos are added as a UnixFS directory,
//           pinned, and the whole DAG is exported to a single CAR backup file.
//   Phase 2 (restore):         a fresh node (new install / new device) imports
//           the CAR and rehydrates the vault manifest and every photo.
//
// On a real mobile app the "capture" phase runs in the background under
// IPFSConfig(offline: true) and the CAR backup doubles as the payload a peer
// or pinning service receives on reconnect.
//
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dart_ipfs/dart_ipfs.dart';

const _workRoot = '.photo_vault';
const _carPath = '$_workRoot/vault_backup.car';
const _checkpointPath = '$_workRoot/checkpoint.json';

/// Simulates a captured photo: JPEG magic bytes + deterministic payload.
Uint8List _fakePhoto(int seed) {
  final random = Random(seed);
  final bytes = Uint8List(2048);
  bytes[0] = 0xFF;
  bytes[1] = 0xD8; // JPEG SOI
  for (var i = 2; i < bytes.length; i++) {
    bytes[i] = random.nextInt(256);
  }
  return bytes;
}

IPFSConfig _offlineConfig(String root) => IPFSConfig(
  offline: true,
  dataPath: '$root/ipfs',
  datastorePath: '$root/ipfs/datastore',
  keystorePath: '$root/ipfs/keystore',
  debug: false,
  enableMetrics: false,
);

Future<void> main() async {
  // ── Phase 1: capture & checkpoint (the "device" node) ────────────────────
  print('== Phase 1: offline capture ==');
  var node = await IPFSNode.create(_offlineConfig('$_workRoot/device'));
  await node.start();

  final photos = <String, Uint8List>{
    for (var i = 0; i < 3; i++) 'photo_$i.jpg': _fakePhoto(i),
  };
  final manifest = Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'app': 'photo_vault',
        'version': 1,
        'photos': photos.keys.toList(),
        'capturedAt': DateTime.now().toUtc().toIso8601String(),
      }),
    ),
  );

  // One root CID pins the manifest plus every photo.
  final vaultCid = await node.addDirectory(<String, dynamic>{
    'manifest.json': manifest,
    'photos': photos,
  });
  await node.pin(vaultCid);
  print('Vault stored. Root CID: $vaultCid');

  // Export the entire vault DAG as a single CAR backup file.
  final carBytes = await node.exportCAR(vaultCid);
  await File(_carPath).writeAsBytes(carBytes, flush: true);
  await File(
    _checkpointPath,
  ).writeAsString(jsonEncode({'rootCid': vaultCid}), flush: true);
  print('CAR backup written: $_carPath (${carBytes.length} bytes)');
  await node.stop();

  // ── Phase 2: reinstall / reconnect — restore purely from the CAR ──────────
  print('\n== Phase 2: restore from CAR ==');
  node = await IPFSNode.create(_offlineConfig('$_workRoot/restore'));
  await node.start();

  final checkpoint =
      jsonDecode(await File(_checkpointPath).readAsString())
          as Map<String, dynamic>;
  final rootCid = checkpoint['rootCid'] as String;

  // Every block is hash-verified against its CID during import.
  await node.importCAR(Uint8List.fromList(await File(_carPath).readAsBytes()));
  print('CAR imported. Restoring vault rooted at $rootCid');

  final manifestBytes = await node.get(rootCid, path: 'manifest.json');
  if (manifestBytes == null) {
    throw StateError('manifest.json missing after CAR restore');
  }
  final restoredManifest =
      jsonDecode(utf8.decode(manifestBytes)) as Map<String, dynamic>;
  print('Manifest: ${restoredManifest['photos']}');

  var verified = 0;
  for (final name in photos.keys) {
    final bytes = await node.get(rootCid, path: 'photos/$name');
    final original = photos[name]!;
    if (bytes != null && _bytesEqual(bytes, original)) {
      verified++;
      print('  verified $name (${bytes.length} bytes)');
    } else {
      print('  FAILED $name');
    }
  }
  print('\nRestored $verified/${photos.length} photos from CAR backup.');

  await node.stop();
}

bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
