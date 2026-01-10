// lib/src/utils/dnslink_resolver.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

/// A utility class for resolving DNSLink to CID.
class DNSLinkResolver {
  /// Resolves a DNSLink for the given domain name.
  static Future<String?> resolve(String domainName, {http.Client? client}) async {
    try {
      final url = Uri.parse('https://dnslink.io/$domainName');
      final httpClient = client ?? http.Client();
      final response = await httpClient.get(url);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        return jsonResponse['cid'] as String?; // Adjust based on actual response structure
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
}
