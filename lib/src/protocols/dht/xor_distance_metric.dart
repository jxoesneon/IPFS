import 'dart:math' as math;

import 'package:collection/collection.dart';

import '../../core/types/peer_id.dart';

import 'dht_routing_table_interface.dart';

/// Kademlia XOR distance metric implementation.
///
/// Calculates the XOR distance between two peer IDs or between a peer ID and a
/// key. XOR distance is the standard distance metric used in Kademlia DHT.
///
/// Distances are returned as full-precision [BigInt] values equal to the XOR
/// of the two byte strings interpreted as a big-endian unsigned integer. This
/// keeps ordering exact for arbitrarily long IDs (e.g., 256-bit SHA-256
/// multihashes/peer IDs), where reducing the XOR result to a 64-bit [int]
/// would collapse distinct distances and corrupt peer ordering.
///
/// Properties:
/// - Symmetric: distance(a, b) == distance(b, a)
/// - Non-negative: distance(a, b) >= 0
/// - Identity: distance(a, a) == 0
/// - Triangle inequality: distance(a, c) <= distance(a, b) + distance(b, c)
class XorDistanceMetric implements DistanceMetric {
  /// Creates a new XOR distance metric instance.
  const XorDistanceMetric();

  @override
  BigInt calculateDistance(PeerId a, PeerId b) {
    return _xorBytes(a.value, b.value);
  }

  @override
  BigInt calculateDistanceToKey(PeerId peerId, List<int> key) {
    return _xorBytes(peerId.value, key);
  }

  /// Calculates XOR distance between two byte arrays.
  ///
  /// Returns the XOR result interpreted as a big-endian unsigned integer.
  /// Byte arrays of different lengths are right-aligned (the shorter input is
  /// treated as if padded with leading zero bytes), matching big-endian
  /// integer semantics.
  BigInt _xorBytes(List<int> a, List<int> b) {
    final maxLength = a.length > b.length ? a.length : b.length;
    var result = BigInt.zero;

    // Fold the XOR bytes most-significant-first into a big-endian integer.
    for (int i = 0; i < maxLength; i++) {
      final indexA = a.length - maxLength + i;
      final indexB = b.length - maxLength + i;
      final byteA = indexA >= 0 ? a[indexA] : 0;
      final byteB = indexB >= 0 ? b[indexB] : 0;
      result = (result << 8) | BigInt.from(byteA ^ byteB);
    }

    return result;
  }
}

/// Compares the XOR distances of [aKey] and [bKey] to [reference] without
/// allocating any [BigInt]s.
///
/// XOR distance ordering is exactly the lexicographic ordering of the XOR'd
/// bytes read most-significant-first: the first byte where
/// `aKey ^ reference` differs from `bKey ^ reference` decides which key is
/// closer. Inputs of different lengths are right-aligned (the shorter input
/// is treated as padded with leading zero bytes), matching the big-endian
/// semantics of [XorDistanceMetric.calculateDistance].
///
/// Returns a negative value when [aKey] is closer to [reference] than
/// [bKey], zero when the distances are equal, and a positive value when
/// [bKey] is closer. Use this in comparators and hot lookup paths; keep
/// [XorDistanceMetric.calculateDistance] when the distance value itself is
/// needed.
int compareXorDistanceToKey(
  List<int> aKey,
  List<int> bKey,
  List<int> reference,
) {
  final maxLength = math.max(
    aKey.length,
    math.max(bKey.length, reference.length),
  );

  for (int i = 0; i < maxLength; i++) {
    final indexA = aKey.length - maxLength + i;
    final indexB = bKey.length - maxLength + i;
    final indexRef = reference.length - maxLength + i;
    final refByte = indexRef >= 0 ? reference[indexRef] : 0;
    final xoredA = (indexA >= 0 ? aKey[indexA] : 0) ^ refByte;
    final xoredB = (indexB >= 0 ? bKey[indexB] : 0) ^ refByte;
    if (xoredA != xoredB) {
      return xoredA < xoredB ? -1 : 1;
    }
  }

  return 0;
}

/// Returns up to [k] peers from [candidates] with the smallest XOR distance
/// to [reference], ordered nearest-first.
///
/// This is the in-memory equivalent of a closest-peers routing-table lookup:
/// the same peer set can serve every key in a batch (e.g. a reprovide sweep)
/// instead of re-walking the routing table per key. Uses
/// [compareXorDistanceToKey] for ordering, so no [BigInt]s are allocated.
List<PeerId> closestPeersToKey(
  Iterable<PeerId> candidates,
  List<int> reference,
  int k,
) {
  final queue = PriorityQueue<PeerId>(
    (a, b) => compareXorDistanceToKey(a.value, b.value, reference),
  )..addAll(candidates);

  final closest = <PeerId>[];
  for (var i = 0; i < k && queue.isNotEmpty; i++) {
    closest.add(queue.removeFirst());
  }
  return closest;
}
