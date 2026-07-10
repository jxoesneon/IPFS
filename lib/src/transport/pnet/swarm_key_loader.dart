// lib/src/transport/pnet/swarm_key_loader.dart
import 'dart:typed_data';

import 'package:convert/convert.dart' as convert;

import '../../platform/platform.dart';

/// Loads and decodes a libp2p PNET swarm key from [path].
///
/// Returns the 32-byte pre-shared key, or `null` if the file does not exist
/// or cannot be parsed. The expected file format is:
///
/// ```
/// /key/swarm/psk/1.0.0/
/// /base16/
/// <hex-encoded 32-byte key>
/// ```
///
/// Lines may contain leading or trailing whitespace and are filtered for
/// non-empty content before parsing.
Future<Uint8List?> loadSwarmKey(String path) async {
  final content = await getPlatform().readString(path);
  if (content == null) return null;
  try {
    return decodeV1Psk(Uint8List.fromList(content.codeUnits));
  } catch (_) {
    return null;
  }
}

/// Decodes a v1 swarm key from raw file bytes.
///
/// The [bytes] must contain the marker `/key/swarm/psk/1.0.0/`, followed by
/// `/base16/`, followed by a hex string representing exactly 32 bytes.
///
/// This function is exposed directly so unit tests can verify parsing
/// without touching the filesystem.
Uint8List decodeV1Psk(Uint8List bytes) {
  final text = String.fromCharCodes(bytes);
  final lines = text
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  if (lines.length < 3) {
    throw FormatException(
      'Swarm key must contain at least 3 non-empty lines, got ${lines.length}',
    );
  }
  if (lines[0] != '/key/swarm/psk/1.0.0/') {
    throw FormatException('Unexpected swarm key version marker: ${lines[0]}');
  }
  if (lines[1] != '/base16/') {
    throw FormatException('Unexpected swarm key encoding marker: ${lines[1]}');
  }

  final hex = lines[2];
  if (hex.length != 64) {
    throw FormatException(
      'Swarm key hex must be 64 characters (32 bytes), got ${hex.length}',
    );
  }

  final decoded = convert.hex.decode(hex);
  if (decoded.length != 32) {
    throw FormatException(
      'Decoded swarm key length is ${decoded.length}, expected 32',
    );
  }

  return Uint8List.fromList(decoded);
}
