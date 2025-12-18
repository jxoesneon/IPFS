import 'dart:typed_data';

import 'package:dart_ipfs/src/utils/base58.dart';

/// Represents a peer identifier in the IPFS network.
class PeerId {
  /// Creates a PeerId from raw bytes.
  PeerId({required this.value});

  /// Creates a PeerId from a Base58-encoded string.
  factory PeerId.fromBase58(String base58) {
    return PeerId(value: Base58().base58Decode(base58));
  }

  /// The raw bytes of the peer ID.
  final Uint8List value;

  /// Converts the peer ID to a Base58-encoded string.
  String toBase58() {
    return Base58().encode(value);
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
