// lib/src/cid/multibase.dart
import 'dart:typed_data';

import 'package:multibase/multibase.dart' as mb;

/// Helpers for multibase encoding/decoding used by CID and other multiformats.
///
/// This class is a thin, stable wrapper around `package:multibase` that exposes
/// only the bases used by dart_ipfs_core.
class MultibaseUtils {
  // Private constructor to prevent instantiation.
  MultibaseUtils._();

  /// Decodes a multibase-encoded string into raw bytes.
  ///
  /// The input string must include the multibase prefix character.
  static Uint8List decode(String input) =>
      Uint8List.fromList(mb.multibaseDecode(input));

  /// Encodes raw bytes using the requested [base].
  static String encode(mb.Multibase base, Uint8List bytes) =>
      mb.multibaseEncode(base, bytes);

  /// Encodes raw bytes using the requested base name.
  ///
  /// Falls back to base32 if the name is unknown.
  static String encodeWithName(String name, Uint8List bytes) {
    final base = _baseFromName(name);
    return encode(base, bytes);
  }

  /// Parses a base name into a [mb.Multibase] enum value.
  static mb.Multibase _baseFromName(String name) {
    switch (name.toLowerCase()) {
      case 'base16':
      case 'base16lower':
        return mb.Multibase.base16;
      case 'base16upper':
        return mb.Multibase.base16upper;
      case 'base32':
      case 'base32lower':
        return mb.Multibase.base32;
      case 'base32upper':
        return mb.Multibase.base32upper;
      case 'base58':
      case 'base58btc':
        return mb.Multibase.base58btc;
      case 'base64':
        return mb.Multibase.base64;
      case 'base64url':
        return mb.Multibase.base64url;
      case 'base64urlpad':
        return mb.Multibase.base64urlpad;
      default:
        return mb.Multibase.base32;
    }
  }
}
