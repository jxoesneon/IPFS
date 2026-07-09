// WASM entry point for dart_ipfs.
//
// This file is the dart2wasm compilation target. It exercises the
// browser-facing IPFSWebNode (offline block storage via IndexedDB,
// Bitswap, PubSub, IPNS) using only WASM-compatible dependencies
// (package:web, dart:js_interop, idb_shim, pure-Dart crypto).
//
// Build:
//   dart compile wasm example/wasm_main.dart -o build/dart_ipfs.wasm
//
// The produced pair (dart_ipfs.wasm + dart_ipfs.mjs) is loaded from HTML
// via the generated JS shim. WebAssembly GC and exception handling must be
// enabled in the target browser (all modern evergreen browsers as of 2025).

import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/dart_ipfs.dart';

/// Entry point for the WASM build.
///
/// Instantiates [IPFSWebNode], starts it, round-trips a block through the
/// offline store (add -> get), and leaves the node running so the host page
/// can drive further operations. All work is guarded so a failure never
/// crashes the WASM module silently — diagnostics are printed to the console.
Future<void> main() async {
  final node = IPFSWebNode();

  try {
    await node.start();

    // Round-trip a small block through the offline store to verify that the
    // IndexedDB-backed WebBlockStore works end-to-end under dart2wasm.
    final payload = Uint8List.fromList(utf8.encode('hello wasm ipfs'));
    final cid = await node.add(payload);

    final retrieved = await node.get(cid.encode());
    if (retrieved == null) {
      print('WASM smoke test FAILED: block not found after add.');
      return;
    }

    final text = String.fromCharCodes(retrieved);
    if (text != 'hello wasm ipfs') {
      print('WASM smoke test FAILED: round-trip mismatch ($text).');
      return;
    }

    print('WASM smoke test OK: cid=${cid.encode()}, bytes=${retrieved.length}');
  } catch (e, st) {
    // Never let an unexpected error kill the module without a trace.
    print('WASM entry point error: $e');
    print(st);
  }
}
