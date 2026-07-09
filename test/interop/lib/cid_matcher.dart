// Helpers for deterministic CID comparison across IPFS implementations.
// This is a scaffold; expand with real multibase / multihash parsing as needed.

import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';

/// Compare two CIDs by their canonical byte representation, ignoring encoding
/// differences such as CIDv0 base32 vs CIDv1 base36.
///
/// This compares the underlying multihash bytes, which is the canonical
/// representation regardless of encoding (base32, base36, base58btc, etc.).
bool cidEquals(CID a, CID b) {
  // Compare canonical CID bytes directly - this is encoding-agnostic
  return bytesEqual(a.toBytes(), b.toBytes());
}

/// Compare two byte payloads for exact equality.
bool bytesEqual(dynamic a, dynamic b) {
  final listA = a is Uint8List ? a : (a as List<int>);
  final listB = b is Uint8List ? b : (b as List<int>);
  if (listA.length != listB.length) return false;
  for (var i = 0; i < listA.length; i++) {
    if (listA[i] != listB[i]) return false;
  }
  return true;
}
