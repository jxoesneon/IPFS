import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';

/// Interface for IPLD codecs.
abstract class IPLDCodec {
  /// Codec name.
  String get name;

  /// Multicodec code.
  int get code;

  /// Encodes data to bytes.
  Uint8List encode(dynamic data);

  /// Decodes bytes to data.
  dynamic decode(Uint8List data);
}

/// DAG-JSON Codec implementation (0x0129)
class DagJsonCodec implements IPLDCodec {
  @override
  String get name => 'dag-json';

  @override
  int get code => 0x0129;

  @override
  Uint8List encode(dynamic data) {
    // recursively convert CIDs to {"/": "cid-string"}
    final jsonReady = _toSnapshottable(data);
    return Uint8List.fromList(utf8.encode(jsonEncode(jsonReady)));
  }

  @override
  dynamic decode(Uint8List data) {
    final json = jsonDecode(utf8.decode(data));
    // recursively convert {"/": "cid-string"} to CIDs
    return _fromSnapshottable(json);
  }

  dynamic _toSnapshottable(dynamic data) {
    if (data is CID) {
      return {'/': data.encode()};
    } else if (data is Uint8List) {
      // DAG-JSON standard for bytes is {"/": {"bytes": "base64"}}
      return {
        '/': {'bytes': base64.encode(data)},
      };
    } else if (data is Map) {
      return data.map((k, v) => MapEntry(k, _toSnapshottable(v)));
    } else if (data is List) {
      return data.map((e) => _toSnapshottable(e)).toList();
    }
    return data;
  }

  dynamic _fromSnapshottable(dynamic data) {
    if (data is Map) {
      // Check for CID link {"/": "..."}
      if (data.length == 1 && data.containsKey('/')) {
        final val = data['/'];
        if (val is String) {
          try {
            return CID.decode(val);
          } catch (_) {
            // If not a valid CID string, leave as is?
            // Or maybe it's just a map with a key "/"
            // Standard says {"/": "cid"} is reserved.
            return data;
          }
        } else if (val is Map && val.containsKey('bytes')) {
          // Bytes {"/": {"bytes": "base64"}}
          try {
            return base64.decode(val['bytes'] as String);
          } catch (_) {
            return data;
          }
        }
      }
      return data.map((k, v) => MapEntry(k, _fromSnapshottable(v)));
    } else if (data is List) {
      return data.map((e) => _fromSnapshottable(e)).toList();
    }
    return data;
  }
}

