// lib/src/data_structures/immutable_bytes.dart
import 'dart:typed_data';

/// An immutable wrapper around a [Uint8List] with value-based equality.
///
/// Useful for passing byte arrays through maps, sets, and other collections
/// without accidental mutation.
class ImmutableBytes {
  /// Creates an immutable wrapper around the given [bytes].
  ///
  /// The bytes are copied to prevent external mutation.
  ImmutableBytes(Uint8List bytes) : _bytes = Uint8List.fromList(bytes);

  final Uint8List _bytes;

  /// Returns a copy of the underlying bytes.
  Uint8List toBytes() => Uint8List.fromList(_bytes);

  /// The length of the byte array.
  int get length => _bytes.length;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImmutableBytes &&
          runtimeType == other.runtimeType &&
          _bytesEqual(_bytes, other._bytes);

  @override
  int get hashCode => _bytes.hashCode;

  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
