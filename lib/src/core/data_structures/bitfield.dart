// lib/src/core/data_structures/bitfield.dart
import 'dart:typed_data';

import '../../proto/generated/core/bitfield.pb.dart'; // Import the generated Dart file for BitFieldProto

/// A class representing a simple bit field, used to manage binary flags efficiently.
class BitField {
  // Using Uint8List for memory efficiency

  /// Constructs a BitField of a given size, initializing all bits to false (0).
  BitField(int size) : _bits = Uint8List((size + 7) ~/ 8);
  final Uint8List _bits; // Efficient storage

  /// Sets the bit at the specified index to true.
  void setBit(int index) {
    _validateIndex(index);
    _bits[index >> 3] |= 1 << (index & 7);
  }

  /// Clears the bit at the specified index (sets it to false).
  void clearBit(int index) {
    _validateIndex(index);
    _bits[index >> 3] &= ~(1 << (index & 7));
  }

  /// Returns whether the bit at the specified index is set (true) or cleared (false).
  bool getBit(int index) {
    _validateIndex(index);
    return (_bits[index >> 3] & (1 << (index & 7))) != 0;
  }

  /// Validates the provided index, throwing a RangeError if it is out of bounds.
  void _validateIndex(int index) {
    if (index < 0 || index >= _bits.length * 8) {
      throw RangeError('Index $index out of range (size: ${_bits.length * 8})');
    }
  }

  /// Serializes the BitField to a protobuf message for storage or transmission.
  BitFieldProto toProto() {
    final proto = BitFieldProto()
      ..size = _bits.length * 8
      ..bits = _bits; // Uint8List is directly supported
    return proto;
  }

  /// Deserializes a BitField from a protobuf message.
  static BitField fromProto(BitFieldProto proto) {
    final bitField = BitField(proto.size);
    bitField._bits.setAll(0, proto.bits); // Setting all bits from proto
    return bitField;
  }

  /// Returns the total size of the BitField in bits.
  int get size => _bits.length * 8;
}
