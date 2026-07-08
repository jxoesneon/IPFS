// lib/src/codec/dag_json_codec.dart
import 'dart:convert';
import 'dart:typed_data';

import 'codec.dart';

/// Codec for DAG-JSON.
///
/// The DAG-JSON multicodec (`0x0129`) encodes/decodes IPLD data using JSON.
///
/// This implementation handles the standard JSON types. CID links are encoded
/// as `{'/': '<cid-string>'}` maps, matching the DAG-JSON spec.
class DagJsonCodec implements IPLDCodec {
  @override
  String get name => 'dag-json';

  @override
  int get code => 0x0129;

  @override
  Future<Uint8List> encode(dynamic value) async {
    final json = jsonEncode(_normalize(value));
    return Uint8List.fromList(utf8.encode(json));
  }

  @override
  Future<dynamic> decode(Uint8List data) async {
    final json = utf8.decode(data);
    return _denormalize(jsonDecode(json));
  }

  /// Normalizes Dart values for JSON encoding.
  dynamic _normalize(dynamic value) {
    if (value is Uint8List) {
      return {
        '/': {'bytes': base64Encode(value)},
      };
    }
    if (value is Map) {
      if (value.containsKey('/')) {
        final link = value['/'];
        if (link is String) return {'/': link};
        if (link is Map && link.containsKey('bytes')) {
          return {
            '/': {'bytes': link['bytes']},
          };
        }
      }
      return value.map((k, v) => MapEntry(k.toString(), _normalize(v)));
    }
    if (value is List) {
      return value.map(_normalize).toList();
    }
    if (value is double) {
      if (value.isNaN || value.isInfinite) {
        throw ArgumentError('DAG-JSON does not support non-finite floats');
      }
    }
    return value;
  }

  /// Denormalizes JSON-decoded values back to Dart values.
  dynamic _denormalize(dynamic value) {
    if (value is Map) {
      if (value.containsKey('/')) {
        return value;
      }
      return value.map((k, v) => MapEntry(k.toString(), _denormalize(v)));
    }
    if (value is List) {
      return value.map(_denormalize).toList();
    }
    return value;
  }
}
