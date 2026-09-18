// lib/src/cid/multibase.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:multibase/multibase.dart' as mb;

/// Helpers for multibase encoding/decoding used by CID and other multiformats.
///
/// `package:multibase` encodes base16/base32/base64 through a big-integer
/// base-x codec, which is only correct for base58btc. The RFC 4648 bases are
/// implemented here directly so that CID strings interoperate with the rest of
/// the IPFS ecosystem; base58btc still delegates to the package.
class MultibaseUtils {
  // Private constructor to prevent instantiation.
  MultibaseUtils._();

  static const String _base32Alphabet = 'abcdefghijklmnopqrstuvwxyz234567';
  static const String _base32UpperAlphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  static const String _hexAlphabet = '0123456789abcdef';

  /// Decodes a multibase-encoded string into raw bytes.
  ///
  /// The input string must include the multibase prefix character.
  static Uint8List decode(String input) {
    if (input.isEmpty) {
      throw const FormatException('Empty multibase input');
    }
    final payload = input.substring(1);
    switch (input[0]) {
      case 'f':
        return _hexDecode(payload.toLowerCase());
      case 'F':
        return _hexDecode(payload.toLowerCase());
      case 'b':
        return _base32Decode(payload.toLowerCase());
      case 'B':
        return _base32Decode(payload.toLowerCase());
      case 'm':
        return _base64Decode(payload, urlSafe: false);
      case 'u':
        return _base64Decode(payload, urlSafe: true);
      case 'U':
        return _base64Decode(payload, urlSafe: true);
      case 'z':
        return Uint8List.fromList(mb.multibaseDecode(input));
      default:
        return Uint8List.fromList(mb.multibaseDecode(input));
    }
  }

  /// Encodes raw bytes using the requested [base].
  static String encode(mb.Multibase base, Uint8List bytes) {
    switch (base) {
      case mb.Multibase.base16:
        return 'f${_hexEncode(bytes, upper: false)}';
      case mb.Multibase.base16upper:
        return 'F${_hexEncode(bytes, upper: true)}';
      case mb.Multibase.base32:
        return 'b${_base32Encode(bytes, upper: false)}';
      case mb.Multibase.base32upper:
        return 'B${_base32Encode(bytes, upper: true)}';
      case mb.Multibase.base58btc:
        return mb.multibaseEncode(base, bytes);
      case mb.Multibase.base64:
        return 'm${base64Encode(bytes).replaceAll('=', '')}';
      case mb.Multibase.base64url:
        return 'u${base64UrlEncode(bytes).replaceAll('=', '')}';
      case mb.Multibase.base64urlpad:
        return 'U${base64UrlEncode(bytes)}';
    }
  }

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

  static String _hexEncode(Uint8List data, {required bool upper}) {
    final out = StringBuffer();
    for (final b in data) {
      out.write(_hexAlphabet[b >> 4]);
      out.write(_hexAlphabet[b & 0x0f]);
    }
    final s = out.toString();
    return upper ? s.toUpperCase() : s;
  }

  static Uint8List _hexDecode(String s) {
    if (s.length.isOdd) {
      throw const FormatException('Odd-length hex input');
    }
    final out = Uint8List(s.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      final hi = _hexAlphabet.indexOf(s[i * 2]);
      final lo = _hexAlphabet.indexOf(s[i * 2 + 1]);
      if (hi < 0 || lo < 0) {
        throw const FormatException('Invalid hex character');
      }
      out[i] = (hi << 4) | lo;
    }
    return out;
  }

  static String _base32Encode(Uint8List data, {required bool upper}) {
    final alphabet = upper ? _base32UpperAlphabet : _base32Alphabet;
    final out = StringBuffer();
    var buffer = 0;
    var bits = 0;
    for (final b in data) {
      buffer = (buffer << 8) | b;
      bits += 8;
      while (bits >= 5) {
        out.writeCharCode(alphabet.codeUnitAt((buffer >> (bits - 5)) & 0x1f));
        bits -= 5;
      }
    }
    if (bits > 0) {
      out.writeCharCode(alphabet.codeUnitAt((buffer << (5 - bits)) & 0x1f));
    }
    return out.toString();
  }

  static Uint8List _base32Decode(String s) {
    final out = <int>[];
    var buffer = 0;
    var bits = 0;
    for (final codeUnit in s.codeUnits) {
      final value = _base32Alphabet.indexOf(String.fromCharCode(codeUnit));
      if (value < 0) {
        throw const FormatException('Invalid base32 character');
      }
      buffer = (buffer << 5) | value;
      bits += 5;
      if (bits >= 8) {
        out.add((buffer >> (bits - 8)) & 0xff);
        bits -= 8;
      }
    }
    if (bits >= 5 || ((buffer << (8 - bits)) & 0xff) != 0) {
      throw const FormatException('Invalid base32 padding bits');
    }
    return Uint8List.fromList(out);
  }

  static Uint8List _base64Decode(String s, {required bool urlSafe}) {
    var normalized = s;
    final remainder = normalized.length % 4;
    if (remainder != 0) {
      normalized = normalized.padRight(normalized.length + 4 - remainder, '=');
    }
    if (urlSafe) {
      return Uint8List.fromList(base64Url.decode(normalized));
    }
    return Uint8List.fromList(base64Decode(normalized));
  }
}
