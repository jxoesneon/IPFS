// lib/src/transport/dns_multiaddr_resolver_web.dart

/// Web stub: browsers resolve hostnames at connect time, so DNS multiaddrs
/// pass through unchanged.
Future<String> resolveDnsMultiAddr(String transportAddr) async => transportAddr;
