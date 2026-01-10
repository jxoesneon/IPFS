import 'dart:convert';
import 'dart:typed_data';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:dart_multihash/dart_multihash.dart';
import 'package:fixnum/fixnum.dart';

/// Handles spec-compliant DAG-JSON encoding and decoding for IPLD nodes.
class DAGJsonHandler {
  /// Encodes an IPLDNode to a spec-compliant DAG-JSON string.
  static String encode(IPLDNode node) {
    return json.encode(_toPlainObject(node));
  }

  /// Decodes a DAG-JSON string into an IPLDNode.
  static IPLDNode decode(String jsonStr) {
    final decoded = json.decode(jsonStr);
    return _fromPlainObject(decoded);
  }

  static dynamic _toPlainObject(IPLDNode node) {
    switch (node.kind) {
      case Kind.NULL:
        return null;
      case Kind.BOOL:
        return node.boolValue;
      case Kind.INTEGER:
        return node.intValue.toInt();
      case Kind.FLOAT:
        return node.floatValue;
      case Kind.STRING:
        return node.stringValue;
      case Kind.BYTES:
        return {
          '/': {'bytes': base64.encode(node.bytesValue)},
        };
      case Kind.LIST:
        return node.listValue.values.map((e) => _toPlainObject(e)).toList();
      case Kind.MAP:
        final map = <String, dynamic>{};
        for (final entry in node.mapValue.entries) {
          map[entry.key] = _toPlainObject(entry.value);
        }
        return map;
      case Kind.LINK:
        final multihash = Uint8List.fromList(node.linkValue.multihash);
        // We use CID.v1 if we have enough info, or try to reconstruct
        // For DAG-JSON, we just need the string representation
        final cid = CID.v1(
          node.linkValue.codec.isEmpty ? 'dag-pb' : node.linkValue.codec,
          Multihash.decode(multihash),
        );
        return {'/': cid.toString()};
      default:
        return null;
    }
  }

  static IPLDNode _fromPlainObject(dynamic obj) {
    final node = IPLDNode();
    if (obj == null) {
      node.kind = Kind.NULL;
    } else if (obj is bool) {
      node.kind = Kind.BOOL;
      node.boolValue = obj;
    } else if (obj is num) {
      if (obj is int) {
        node.kind = Kind.INTEGER;
        node.intValue = Int64(obj);
      } else {
        node.kind = Kind.FLOAT;
        node.floatValue = obj.toDouble();
      }
    } else if (obj is String) {
      node.kind = Kind.STRING;
      node.stringValue = obj;
    } else if (obj is List) {
      node.kind = Kind.LIST;
      node.listValue = IPLDList()..values.addAll(obj.map((e) => _fromPlainObject(e)));
    } else if (obj is Map) {
      if (obj.length == 1 && obj.containsKey('/')) {
        final link = obj['/'];
        if (link is String) {
          // CID link
          final cid = CID.decode(link);
          node.kind = Kind.LINK;
          node.linkValue = IPLDLink()
            ..version = cid.version
            ..codec = cid.codec ?? ''
            ..multihash = cid.multihash.toBytes();
        } else if (link is Map && link.containsKey('bytes')) {
          // Bytes
          node.kind = Kind.BYTES;
          node.bytesValue = base64.decode(link['bytes'] as String);
        } else {
          // Literal map with key '/'
          node.kind = Kind.MAP;
          node.mapValue = IPLDMap()
            ..entries.add(
              MapEntry()
                ..key = '/'
                ..value = _fromPlainObject(link),
            );
        }
      } else {
        node.kind = Kind.MAP;
        node.mapValue = IPLDMap();
        for (final entry in obj.entries) {
          node.mapValue.entries.add(
            MapEntry()
              ..key = entry.key.toString()
              ..value = _fromPlainObject(entry.value),
          );
        }
      }
    }
    return node;
  }
}
