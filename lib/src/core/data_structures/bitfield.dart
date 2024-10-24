import 'dart:typed_data';
import 'package:protobuf/protobuf.dart';
import 'bitfield.pb.dart'; // Import the generated Dart file for BitField

class BitField {
  final List<bool> _bits;

  BitField(int size) : _bits = List<bool>.filled(size, false);

  // Sets a bit at the specified index
  void setBit(int index) {
    if (index < 0 || index >= _bits.length) {
      throw RangeError('Index out of range');
    }
    _bits[index] = true;
  }

  // Clears a bit at the specified index
  void clearBit(int index) {
    if (index < 0 || index >= _bits.length) {
      throw RangeError('Index out of range');
    }
    _bits[index] = false;
  }

  // Gets the value of a bit at the specified index
  bool getBit(int index) {
    if (index < 0 || index >= _bits.length) {
      throw RangeError('Index out of range');
    }
    return _bits[index];
  }

  // Serializes the BitField to a protobuf message
  BitFieldProto toProto() {
    final bitFieldProto = BitFieldProto()
      ..size = _bits.length
      ..bits.addAll(_bits);
    return bitFieldProto;
  }

  // Deserialize a BitField from a protobuf message
  static BitField fromProto(BitFieldProto proto) {
    final bitField = BitField(proto.size);
    for (int i = 0; i < proto.bits.length; i++) {
      bitField._bits[i] = proto.bits[i];
    }
    return bitField;
  }
}
