// lib/src/transport/dns_multiaddr_resolver_web.dart
// coverage:ignore-file

/// Web stub: browsers resolve hostnames at connect time, so DNS multiaddrs
/// pass through unchanged. This file is never loaded by VM test runs — it is
/// only reachable through conditional import in browser builds.
Future<String> resolveDnsMultiAddr(String transportAddr) async => transportAddr;
