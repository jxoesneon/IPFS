import 'dart:convert';

import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';

extension IPLDNodeJson on IPLDNode {
  /// Converts this node to a clean JSON string representing the data model.
  String toJson() {
    return jsonEncode(toObject());
  }

  /// Converts the IPLDNode to a standard Dart object (Map, List, String, etc.).
  dynamic toObject() {
    switch (kind) {
      case Kind.NULL:
        return null;
      case Kind.BOOL:
        return boolValue;
      case Kind.INTEGER:
        return intValue.toInt();
      case Kind.FLOAT:
        return floatValue;
      case Kind.STRING:
        return stringValue;
      case Kind.BYTES:
        return {'/': base64Encode(bytesValue)};
      case Kind.LIST:
        return listValue.values.map((n) => n.toObject()).toList();
      case Kind.MAP:
        final map = <String, dynamic>{};
        for (final entry in mapValue.entries) {
          map[entry.key] = entry.value.toObject();
        }
        return map;
      case Kind.LINK:
        return {'/': linkValue.toString()}; // Simplified link representation
      case Kind.BIG_INT:
        return bigIntValue.toString(); // BigInt as string for JSON safety
      default:
        return null;
    }
  }
}
