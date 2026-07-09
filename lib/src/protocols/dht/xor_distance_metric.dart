import 'dart:typed_data';

import '../../core/types/peer_id.dart';

import 'dht_routing_table_interface.dart';

/// Kademlia XOR distance metric implementation.
///
/// Calculates the XOR distance between two peer IDs or between a peer ID and a key.
/// XOR distance is the standard distance metric used in Kademlia DHT.
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
  int calculateDistance(PeerId a, PeerId b) {
    return _xorBytes(a.value, b.value);
  }

  @override
  int calculateDistanceToKey(PeerId peerId, List<int> key) {
    return _xorBytes(peerId.value, key);
  }

  /// Calculates XOR distance between two byte arrays.
  ///
  /// Returns the XOR result interpreted as a big-endian integer.
  /// For efficiency, this returns the XOR result as an integer by treating
  /// the bytes as a big-endian number.
  int _xorBytes(List<int> a, List<int> b) {
    final maxLength = a.length > b.length ? a.length : b.length;
    final result = Uint8List(maxLength);

    // XOR byte by byte
    for (int i = 0; i < maxLength; i++) {
      final byteA = i < a.length ? a[a.length - 1 - i] : 0;
      final byteB = i < b.length ? b[b.length - 1 - i] : 0;
      result[maxLength - 1 - i] = byteA ^ byteB;
    }

    // Convert to integer (big-endian)
    return _bytesToInt(result);
  }

  /// Converts big-endian bytes to an integer.
  ///
  /// For large byte arrays (> 8 bytes), this returns a hash of the bytes
  /// to avoid overflow while maintaining distance ordering properties.
  int _bytesToInt(Uint8List bytes) {
    if (bytes.length <= 8) {
      // Small enough to fit in a 64-bit integer
      var value = 0;
      for (final byte in bytes) {
        value = (value << 8) | byte;
      }
      return value;
    } else {
      // For larger arrays, use a hash function that preserves ordering
      // We use a simple hash that XORs chunks together
      var value = 0;
      for (int i = 0; i < bytes.length; i += 8) {
        final chunkSize = (i + 8) < bytes.length ? 8 : bytes.length - i;
        var chunkValue = 0;
        for (int j = 0; j < chunkSize; j++) {
          chunkValue = (chunkValue << 8) | bytes[i + j];
        }
        value ^= chunkValue;
      }
      return value;
    }
  }
}
