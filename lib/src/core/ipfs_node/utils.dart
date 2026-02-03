// lib/src/core/ipfs_node/utils.dart

import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../utils/encoding.dart';

/// Utility class for common IPFS operations.
class IPFSUtils {
  /// Validates if a given string is a valid CID.
  static bool isValidCID(String cid) {
    try {
      final bytes = EncodingUtils.fromBase58(cid);
      return bytes.length > 2 && EncodingUtils.isValidCIDBytes(bytes);
    } catch (e) {
      return false;
    }
  }

  /// Validates if a given string is a valid peer ID.
  static bool isValidPeerID(String peerId) {
    try {
      final bytes = EncodingUtils.fromBase58(peerId);
      return bytes.length == 32; // Expected length for peer ID
    } catch (e) {
      return false;
    }
  }

  /// Encodes a message using Base64 encoding.
  static String encodeBase64(String message) {
    final bytes = utf8.encode(message);
    return base64.encode(bytes);
  }

  /// Decodes a Base64 encoded message.
  static String decodeBase64(String encodedMessage) {
    final bytes = base64.decode(encodedMessage);
    return utf8.decode(bytes);
  }

  /// Hashes data using SHA-256 and returns the digest.
  static List<int> hashSHA256(List<int> data) {
    final digest = sha256.convert(data);
    return digest.bytes;
  }

  /// Extracts a CID from an HTTP response body.
  static String? extractCIDFromResponse(String responseBody) {
    final match = RegExp(
      r'Qm[1-9A-HJ-NP-Za-km-z]{44}',
    ).firstMatch(responseBody);
    final cid = match?.group(0);
    return cid != null && isValidCID(cid) ? cid : null;
  }
}

