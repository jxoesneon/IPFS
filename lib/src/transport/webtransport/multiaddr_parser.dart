// lib/src/transport/webtransport/multiaddr_parser.dart
import 'package:ipfs_libp2p/dart_libp2p.dart' as libp2p;

/// Helper for parsing WebTransport multiaddresses.
class WebTransportMultiaddrParser {
  /// Parses a multiaddr and extracts WebTransport specific components.
  ///
  /// Format: /ip4/1.2.3.4/udp/4001/quic-v1/webtransport/certhash/<mh1>/certhash/<mh2>
  static WebTransportInfo? parse(libp2p.MultiAddr addr) {
    final stringAddr = addr.toString();
    if (!stringAddr.contains('/webtransport')) {
      return null;
    }

    final parts = stringAddr.split('/');
    String? ip;
    int? port;
    bool isQuicV1 = false;
    final certHashes = <String>[];

    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (part == 'ip4' || part == 'ip6' || part == 'dns4' || part == 'dns6') {
        ip = parts[i + 1];
      } else if (part == 'udp') {
        port = int.tryParse(parts[i + 1]);
      } else if (part == 'quic-v1') {
        isQuicV1 = true;
      } else if (part == 'certhash') {
        if (i + 1 < parts.length) {
          certHashes.add(parts[i + 1]);
        }
      }
    }

    if (ip == null || port == null || !isQuicV1) {
      return null;
    }

    return WebTransportInfo(ip: ip, port: port, certHashes: certHashes);
  }
}

/// Container for WebTransport connection information.
class WebTransportInfo {
  final String ip;
  final int port;
  final List<String> certHashes;

  WebTransportInfo({
    required this.ip,
    required this.port,
    required this.certHashes,
  });

  @override
  String toString() =>
      'WebTransportInfo(ip: $ip, port: $port, hashes: ${certHashes.length})';
}
