// lib/src/utils/dnslink_resolver.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

/// A utility class for resolving DNSLink to CID.
class DNSLinkResolver {
  static final _domainRegex = RegExp(
    r'^(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)*'
    r'[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$',
  );

  /// Resolves a DNSLink for the given domain name.
  static Future<String?> resolve(
    String domainName, {
    http.Client? client,
  }) async {
    if (domainName.length > 253 || !_domainRegex.hasMatch(domainName)) {
      return null;
    }

    try {
      final url = Uri.parse(
        'https://dnslink.io/${Uri.encodeComponent(domainName)}',
      );
      final httpClient = client ?? http.Client();
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
    }
  }
}
