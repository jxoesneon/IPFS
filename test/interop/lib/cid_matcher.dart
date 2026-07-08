// Helpers for deterministic CID comparison across IPFS implementations.
// This is a scaffold; expand with real multibase / multihash parsing as needed.

import 'package:dart_ipfs/src/core/cid.dart';

/// Compare two CIDs by their canonical byte representation, ignoring encoding
/// differences such as CIDv0 base32 vs CIDv1 base36.
bool cidEquals(CID a, CID b) {
  // TODO: Replace with a robust comparison that handles multibase prefixes.
  return a.toString() == b.toString();
}

/// Compare two byte payloads for exact equality.
bool bytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
