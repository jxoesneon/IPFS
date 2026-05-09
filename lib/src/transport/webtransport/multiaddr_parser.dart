import 'dart:typed_data';

import 'package:dart_multihash/dart_multihash.dart';
import 'package:ipfs_libp2p/dart_libp2p.dart' as libp2p;
import 'package:multibase/multibase.dart';

import 'certhash.dart';

/// Information parsed from a WebTransport multiaddr.
class WebTransportMultiaddrInfo {
  /// Creates a new [WebTransportMultiaddrInfo].
  WebTransportMultiaddrInfo({
    required this.ip,
    required this.port,
    required this.certHashes,
  });

  /// The IP address.
  final String ip;

  /// The port.
  final int port;

  /// The certificate hashes.
  final List<WebTransportCertHash> certHashes;
}

/// Parser for WebTransport multiaddrs.
class WebTransportMultiaddrParser {
  /// Parses a WebTransport multiaddr.
  static WebTransportMultiaddrInfo? parse(libp2p.MultiAddr addr) {
    // addr example: /ip4/1.2.3.4/udp/443/quic-v1/webtransport/certhash/MH1/certhash/MH2
    final addrStr = addr.toString();
    final parts = addrStr.split('/');

    String? ip;
    int? port;
    final certHashes = <WebTransportCertHash>[];

    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (part == 'ip4' || part == 'ip6') {
        ip = parts[i + 1];
      } else if (part == 'udp') {
        port = int.tryParse(parts[i + 1]);
      } else if (part == 'certhash') {
        final mhStr = parts[i + 1];
        Uint8List mhBytes;
        try {
          // Try to decode as multibase. multibase package supports decoding
          // strings with valid prefixes.
          mhBytes = multibaseDecode(mhStr);
        } catch (_) {
          // Assume raw if decoding fails
          mhBytes = Uint8List.fromList(mhStr.codeUnits);
        }

        try {
          final mh = Multihash.decode(mhBytes);
          certHashes.add(
            WebTransportCertHash(
              algorithm: 'sha-256',
              value: Uint8List.fromList(mh.digest),
            ),
          );
        } catch (_) {
          // If multihash decode fails, just store the bytes as value
          certHashes.add(
            WebTransportCertHash(
              algorithm: 'sha-256',
              value: mhBytes,
            ),
          );
        }
      }
    }

    if (ip == null || port == null) return null;

    return WebTransportMultiaddrInfo(
      ip: ip,
      port: port,
      certHashes: certHashes,
    );
  }
}
