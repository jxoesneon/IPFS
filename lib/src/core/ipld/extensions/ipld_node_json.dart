// src/core/ipld/extensions/ipld_node_json.dart
import 'dart:convert';

import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';

extension IPLDNodeJson on IPLDNode {
  String toJson() {
    final Map<String, dynamic> json = {};

    switch (kind) {
      case Kind.NULL:
        json['value'] = null;
        break;
      case Kind.BOOL:
        json['value'] = boolValue;
        break;
      case Kind.INTEGER:
        json['value'] = intValue.toInt();
        break;
      case Kind.FLOAT:
        json['value'] = floatValue;
        break;
      case Kind.STRING:
        json['value'] = stringValue;
        break;
      case Kind.BYTES:
        json['value'] = base64.encode(bytesValue);
        break;
      case Kind.LIST:
        json['value'] = listValue.values.map((node) => node.toJson()).toList();
        break;
      case Kind.MAP:
        final map = {};
        for (final entry in mapValue.entries) {
          map[entry.key] = entry.value.toJson();
        }
        json['value'] = map;
        break;
      case Kind.LINK:
        json['value'] = {
          '/': base64.encode(linkValue.multihash),
          'version': linkValue.version,
          'codec': linkValue.codec,
        };
        break;
      case Kind.BIG_INT:
        json['value'] = base64.encode(bigIntValue);
        break;
    }

    return jsonEncode(json);
  }
}
