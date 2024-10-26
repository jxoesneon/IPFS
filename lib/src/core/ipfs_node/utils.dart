// lib/src/core/ipfs_node/utils.dart

import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Utility class for common IPFS operations.
class IPFSUtils {
  /// Validates if a given string is a valid CID.
  static bool isValidCID(String cid) {
    // Implement actual CID validation logic
    // This is a placeholder; replace with actual CID validation logic
    return cid.isNotEmpty && RegExp(r'^[a-zA-Z0-9]+$').hasMatch(cid);
  }

  /// Validates if a given string is a valid peer ID.
  static bool isValidPeerID(String peerId) {
    // Implement actual Peer ID validation logic
    // This is a placeholder; replace with actual Peer ID validation logic
    return peerId.isNotEmpty && RegExp(r'^[a-zA-Z0-9]+$').hasMatch(peerId);
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
    // Placeholder logic to extract CID from response body
    // Implement actual extraction logic based on response format
    final match = RegExp(r'Qm[1-9A-HJ-NP-Za-km-z]{44}').firstMatch(responseBody);
    return match?.group(0);
  }
}