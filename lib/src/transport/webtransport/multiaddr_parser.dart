import 'dart:typed_data';

import 'package:ipfs_libp2p/dart_libp2p.dart' as libp2p;
import 'package:multiformats/multiformats.dart';

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
        final mh = Multihash.decode(Uint8List.fromList(mhStr.codeUnits));
        certHashes.add(
          WebTransportCertHash(algorithm: 'sha-256', value: mh.digest),
        );
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
