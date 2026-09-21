// lib/src/transport/dns_multiaddr_resolver_io.dart
import 'dart:io';

import 'package:meta/meta.dart';

import '../utils/logger.dart';

final _logger = Logger('DnsMultiaddrResolver');

/// Successful lookups are cached briefly so repeated dials to the same
/// bootstrap/service name do not pay a DNS round trip every connect.
final Map<String, (List<InternetAddress>, DateTime)> _lookupCache = {};
const _lookupCacheTtl = Duration(seconds: 60);

/// Maximum number of cached host lookups; mutable so tests can exercise
/// eviction without a thousand real DNS round trips.
@visibleForTesting
int dnsLookupCacheMaxEntries = 1024;

/// Overrides [InternetAddress.lookup] in tests so family-mismatch and
/// failure paths can be exercised without real DNS answers.
@visibleForTesting
Future<List<InternetAddress>> Function(String host)? dnsLookupOverride;

/// Clears the lookup cache. Intended for tests that manipulate
/// [dnsLookupOverride] or [dnsLookupCacheMaxEntries].
@visibleForTesting
void clearDnsLookupCache() => _lookupCache.clear();

Future<List<InternetAddress>> _lookup(String host) {
  final cached = _lookupCache[host];
  if (cached != null && cached.$2.isAfter(DateTime.now())) {
    return Future.value(cached.$1);
  }
  final lookup = dnsLookupOverride ?? InternetAddress.lookup;
  return lookup(host).then((results) {
    // Hosts are peer-supplied — bound the cache so a swarm feeding us
    // unique names cannot grow it forever. Insertion-ordered eviction.
    while (_lookupCache.length >= dnsLookupCacheMaxEntries) {
      _lookupCache.remove(_lookupCache.keys.first);
    }
    _lookupCache[host] = (results, DateTime.now().add(_lookupCacheTtl));
    return results;
  });
}

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
      results = await _lookup(host);
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
