import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:dart_ipfs/src/utils/base58.dart';

/// Represents a peer identifier in the IPFS network.
class PeerId {
  /// Creates a PeerId from raw bytes.
  PeerId({required this.value});

  /// Creates a PeerId from a Base58-encoded string.
  factory PeerId.fromBase58(String base58) {
    return PeerId(value: Base58().base58Decode(base58));
  }

  /// Creates a PeerId from a base36-encoded string.
  ///
  /// Accepts both the bare base36 string and the multibase-prefixed form
  /// starting with `k` (the base36 multibase prefix).
  factory PeerId.fromBase36(String base36) {
    if (base36.isEmpty) {
      throw ArgumentError('Empty base36 string');
    }
    var encoded = base36;
    if (encoded[0] == 'k') {
      encoded = encoded.substring(1);
    }
    return PeerId(value: _decodeBase36(encoded));
  }

  /// Creates a PeerId from a public key.
  ///
  /// [type] must be `'Ed25519'` for this simplified implementation. The peer
  /// ID is derived as the SHA-256 digest of the raw public key bytes. A full
  /// libp2p implementation would use the protobuf-encoded public key and the
  /// identity multihash for Ed25519 keys.
  factory PeerId.fromPublicKey(Uint8List publicKey, {required String type}) {
    if (type != 'Ed25519') {
      throw UnsupportedError('Only Ed25519 public keys are supported');
    }
    if (publicKey.length != 32) {
      throw ArgumentError(
        'Ed25519 public key must be 32 bytes, got ${publicKey.length}',
      );
    }
    return PeerId(value: _sha256(publicKey));
  }

  /// The raw bytes of the peer ID.
  final Uint8List value;

  /// Converts the peer ID to a Base58-encoded string.
  String toBase58() {
    return Base58().encode(value);
  }

  /// Converts the peer ID to a multibase-prefixed base36-encoded string.
  ///
  /// The returned string starts with `k`, the base36 multibase prefix, e.g.
  /// `k51qzi5uqu5...`.
  String toBase36() {
    return 'k${_encodeBase36(value)}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PeerId &&
          runtimeType == other.runtimeType &&
          _listsEqual(value, other.value);

  @override
  int get hashCode => _listHashCode(value);

  @override
  String toString() => toBase58();

  /// Checks if this PeerId satisfies a static Proof-of-Work condition (SEC-005).
  ///
  /// The condition is that the SHA-256 hash of the PeerId must have at least
  /// [difficulty] leading zero bits.
  bool verifyPoW({int difficulty = 8}) {
    if (difficulty <= 0) return true;

    // Hash the PeerId bytes
    final hash = _sha256(value);

    // Check leading zero bits
    int leadingZeros = 0;
    for (final byte in hash) {
      if (byte == 0) {
        leadingZeros += 8;
      } else {
        // Count bits in the first non-zero byte
        var b = byte;
        for (int i = 7; i >= 0; i--) {
          if ((b & (1 << i)) == 0) {
            leadingZeros++;
          } else {
            break;
          }
        }
        break;
      }
      if (leadingZeros >= difficulty) break;
    }

    return leadingZeros >= difficulty;
  }

  static Uint8List _sha256(Uint8List data) {
    return Uint8List.fromList(crypto.sha256.convert(data).bytes);
  }
}

bool _listsEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

int _listHashCode(List<int> list) {
  return list.fold(0, (prev, element) => prev ^ element.hashCode);
}

const _base36Alphabet = '0123456789abcdefghijklmnopqrstuvwxyz';

/// Encodes a non-negative big integer, represented as big-endian bytes, to a
/// base36 string using the lowercase alphabet `0-9a-z`.
String _encodeBase36(Uint8List data) {
  if (data.isEmpty) return '0';
  var value = BigInt.zero;
  for (final byte in data) {
    value = (value << 8) | BigInt.from(byte);
  }
  if (value == BigInt.zero) return '0';
  final buffer = StringBuffer();
  final base = BigInt.from(36);
  while (value > BigInt.zero) {
    final remainder = value % base;
    buffer.write(_base36Alphabet[remainder.toInt()]);
    value = value ~/ base;
  }
  return buffer.toString().split('').reversed.join();
}

/// Decodes a base36 string (lowercase `0-9a-z`) to big-endian bytes.
Uint8List _decodeBase36(String encoded) {
  if (encoded.isEmpty) {
    throw ArgumentError('Empty base36 string');
  }
  var value = BigInt.zero;
  final base = BigInt.from(36);
  for (final ch in encoded.toLowerCase().split('')) {
    final index = _base36Alphabet.indexOf(ch);
    if (index == -1) {
      throw ArgumentError('Invalid base36 character: $ch');
    }
    value = value * base + BigInt.from(index);
  }
  if (value == BigInt.zero) {
    return Uint8List(0);
  }
  final bytes = <int>[];
  while (value > BigInt.zero) {
    bytes.add((value & BigInt.from(0xff)).toInt());
    value = value >> 8;
  }
  return Uint8List.fromList(bytes.reversed.toList());
}
