// lib/src/transport/dns_multiaddr_resolver_io.dart
import 'dart:io';

import '../utils/logger.dart';

final _logger = Logger('DnsMultiaddrResolver');

/// Resolves DNS components in a transport multiaddr so transports that only
/// understand /ip4/ and /ip6/ can dial it.
///
/// Handles /dns4/, /dns6/ and /dnsaddr/ components. dart:io cannot perform
/// TXT lookups, so /dnsaddr/ degrades to a plain A/AAAA resolution of the
/// host — correct for domains whose A records point at the dialable node
/// (e.g. bootstrap.libp2p.io and Docker service names).
///
/// Returns the input unchanged when no DNS component is present. Throws
/// [ArgumentError] when resolution yields no address of the required family.
Future<String> resolveDnsMultiAddr(String transportAddr) async {
  final parts = transportAddr.split('/').where((p) => p.isNotEmpty).toList();
  var changed = false;

  for (var i = 0; i < parts.length - 1; i++) {
    final proto = parts[i];
    if (proto != 'dns4' && proto != 'dns6' && proto != 'dnsaddr') continue;

    final host = parts[i + 1];
    final List<InternetAddress> results;
    try {
      results = await InternetAddress.lookup(host);
    } on SocketException catch (e) {
      throw ArgumentError.value(
        transportAddr,
        'transportAddr',
        'DNS resolution failed for "$host": ${e.message}',
      );
    }

    InternetAddress? pick(InternetAddressType type) {
      for (final r in results) {
        if (r.type == type) return r;
      }
      return null;
    }

    final resolved = switch (proto) {
      'dns4' => pick(InternetAddressType.IPv4),
      'dns6' => pick(InternetAddressType.IPv6),
      _ => pick(InternetAddressType.IPv4) ?? pick(InternetAddressType.IPv6),
    };
    if (resolved == null) {
      throw ArgumentError.value(
        transportAddr,
        'transportAddr',
        'DNS resolution for "$host" returned no '
            '${proto == 'dns6' ? 'IPv6' : 'IPv4'} address',
      );
    }

    if (proto == 'dnsaddr') {
      _logger.debug(
        'Treating /dnsaddr/$host as plain DNS lookup '
        '(TXT-based dnsaddr resolution unsupported)',
      );
    }

    parts[i] = resolved.type == InternetAddressType.IPv4 ? 'ip4' : 'ip6';
    parts[i + 1] = resolved.address;
    changed = true;
  }

  return changed ? '/${parts.join('/')}' : transportAddr;
}
