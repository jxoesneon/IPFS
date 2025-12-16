// src/core/cbor/byte_reader.dart

/// A sequential reader for parsing bytes from a byte buffer.
///
/// This utility class provides methods to read bytes one at a time or
/// in chunks from a byte buffer, tracking the current read position.
/// It's commonly used for parsing CBOR and other binary formats.
///
/// Example:
/// ```dart
/// final reader = ByteReader([0x01, 0x02, 0x03, 0x04]);
/// final first = reader.readByte();      // 0x01
/// final next = reader.readBytes(2);     // [0x02, 0x03]
/// // print(reader.hasRemaining);           // true
/// ```
///
/// See also:
/// - [EnhancedCBORHandler] for CBOR encoding/decoding
class ByteReader {
  final List<int> _bytes;
  int _position = 0;

  /// Creates a reader for the given byte list.
  ByteReader(this._bytes);

  /// Reads and returns the next byte, advancing the position.
  ///
  /// Throws [StateError] if there are no more bytes to read.
  int readByte() {
    if (_position >= _bytes.length) {
      throw StateError('End of input');
    }
    return _bytes[_position++];
  }

  /// Reads and returns the next [count] bytes, advancing the position.
  ///
  /// Throws [StateError] if fewer than [count] bytes remain.
  List<int> readBytes(int count) {
    if (_position + count > _bytes.length) {
      throw StateError('Not enough bytes');
    }
    final result = _bytes.sublist(_position, _position + count);
    _position += count;
    return result;
  }

  /// Returns `true` if the next byte is a CBOR break marker (0xFF).
  bool isBreak() => _position < _bytes.length && _bytes[_position] == 0xff;

  /// Returns the remaining unread bytes.
  List<int> get remaining => _bytes.sublist(_position);

  /// Returns `true` if there are more bytes to read.
  bool get hasRemaining => _position < _bytes.length;

  /// The current read position in the buffer.
  int get position => _position;
}
