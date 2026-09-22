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
