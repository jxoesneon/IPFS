// lib/src/codec/dag_json_codec.dart
import 'dart:convert';
import 'dart:typed_data';

import '../cid/cid.dart';
import 'codec.dart';

/// Codec for DAG-JSON.
///
/// The DAG-JSON multicodec (`0x0129`) encodes/decodes IPLD data using JSON.
///
/// This implementation handles the standard JSON types. CID links are encoded
/// as `{'/': '<cid-string>'}` single-key maps and byte strings as
/// `{'/': {'bytes': '<base64>'}}`, matching the DAG-JSON spec. Map keys must
/// be strings, and non-finite floats are rejected.
class DagJsonCodec implements IPLDCodec {
  /// Creates a new [DagJsonCodec] instance.
  DagJsonCodec();

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
      // The '/' sentinel only applies when it is the map's sole key; a map
      // carrying '/' alongside other keys is a regular map and must not
      // silently drop its sibling entries.
      if (value.length == 1 && value.containsKey('/')) {
        final link = value['/'];
        if (link is String) {
          _validateCidString(link);
          return {'/': link};
        }
        if (link is Map && link.containsKey('bytes')) {
          return {
            '/': {'bytes': link['bytes']},
          };
        }
      }
      return value.map((k, v) {
        if (k is! String) {
          throw ArgumentError(
            'DAG-JSON map keys must be strings, got ${k.runtimeType}',
          );
        }
        return MapEntry(k, _normalize(v));
      });
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
      if (value.length == 1 && value.containsKey('/')) {
        final link = value['/'];
        if (link is String) {
          try {
            _validateCidString(link);
          } on ArgumentError catch (e) {
            throw FormatException('Invalid DAG-JSON link: ${e.message}');
          }
        }
        return value;
      }
      return value.map((k, v) => MapEntry(k.toString(), _denormalize(v)));
    }
    if (value is List) {
      return value.map(_denormalize).toList();
    }
    return value;
  }

  /// Ensures a `{'/': ...}` link string is a parseable CID.
  static void _validateCidString(String link) {
    try {
      CID.decode(link);
    } catch (e) {
      throw ArgumentError('Invalid CID in DAG-JSON link: $link ($e)');
    }
  }
}
