// lib/src/utils/dnslink_resolver.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

/// A utility class for resolving DNSLink to CID.
class DNSLinkResolver {
  static final _domainRegex = RegExp(
    r'^(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)*'
    r'[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$',
  );

  /// Default HTTPS resolver endpoint used for DNSLink TXT lookups.
  static const String defaultEndpoint = 'https://dnslink.io';

  /// Resolves a DNSLink for the given domain name.
  ///
  /// The lookup is delegated to an HTTPS resolver endpoint — by default the
  /// public `dnslink.io` service. Operators can substitute their own
  /// resolver or DNS-over-HTTPS endpoint via [endpoint] to avoid depending
  /// on a third-party service.
  ///
  /// When [client] is omitted an internal [http.Client] is created and
  /// closed before this method returns; callers that resolve many domains
  /// should pass a shared client.
  static Future<String?> resolve(
    String domainName, {
    http.Client? client,
    String endpoint = defaultEndpoint,
  }) async {
    if (domainName.length > 253 || !_domainRegex.hasMatch(domainName)) {
      return null;
    }

    final httpClient = client ?? http.Client();
    try {
      final url = Uri.parse('$endpoint/${Uri.encodeComponent(domainName)}');
      final response = await httpClient
          .get(url)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final dynamic decoded;
        try {
          decoded = jsonDecode(response.body);
        } on FormatException {
          return null;
        }
        if (decoded is Map<String, dynamic>) {
          final cid = decoded['cid'];
          if (cid is String && cid.isNotEmpty) {
            return cid;
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    } finally {
      if (client == null) httpClient.close();
    }
  }
}
