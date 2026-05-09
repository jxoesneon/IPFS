import 'dart:typed_data';

/// Represents a certificate hash for WebTransport.
class WebTransportCertHash {
  /// Creates a new [WebTransportCertHash].
  WebTransportCertHash({required this.algorithm, required this.value});

  /// The hash algorithm (e.g. 'sha-256').
  final String algorithm;

  /// The hash value.
  final Uint8List value;
}
