// src/core/cbor/byte_reader.dart

class ByteReader {
  final List<int> _bytes;
  int _position = 0;

  ByteReader(this._bytes);

  int readByte() {
    if (_position >= _bytes.length) {
      throw StateError('End of input');
    }
    return _bytes[_position++];
  }

  List<int> readBytes(int count) {
    if (_position + count > _bytes.length) {
      throw StateError('Not enough bytes');
    }
    final result = _bytes.sublist(_position, _position + count);
    _position += count;
    return result;
  }

  bool isBreak() => _position < _bytes.length && _bytes[_position] == 0xff;

  List<int> get remaining => _bytes.sublist(_position);
  bool get hasRemaining => _position < _bytes.length;
  int get position => _position;
}
