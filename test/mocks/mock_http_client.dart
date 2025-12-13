// test/mocks/mock_http_client.dart
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Builder for creating mock HTTP clients with configurable responses.
///
/// Simplifies testing of components that make HTTP requests
/// (e.g., DNSLink resolution, IPNS resolution).
class MockHTTPClientBuilder {
  final Map<Uri, http.Response> _responses = {};
  final List<http.Request> _requests = [];

  /// Set up a response for a specific URL
  void setupResponse(String url, int statusCode, String body,
      {Map<String, String>? headers}) {
    _responses[Uri.parse(url)] = http.Response(
      body,
      statusCode,
      headers: headers ?? {},
    );
  }

  /// Set up IPNS resolution response
  void setupIPNSResponse(String name, String cid) {
    setupResponse(
      'https://ipfs.io/api/v0/name/resolve?arg=$name',
      200,
      '{"Path": "/ipfs/$cid"}',
    );
  }

  /// Set up DNSLink resolution response
  void setupDNSLinkResponse(String domain, String cid) {
    setupResponse(
      'https://dns.google/resolve?name=_dnslink.$domain&type=TXT',
      200,
      '{"Answer": [{"data": "dnslink=/ipfs/$cid"}]}',
    );
  }

  /// Set up error response
  void setupError(String url, int statusCode, String message) {
    setupResponse(url, statusCode, message);
  }

  /// Build the mock client
  http.Client build() {
    return MockClient((request) async {
      _requests.add(request);

      if (_responses.containsKey(request.url)) {
        return _responses[request.url]!;
      }

      return http.Response('Not Found', 404);
    });
  }

  /// Get all recorded requests
  List<http.Request> getRequests() => List.unmodifiable(_requests);

  /// Check if a URL was requested
  bool wasRequested(String url) {
    final uri = Uri.parse(url);
    return _requests.any((r) => r.url == uri);
  }

  /// Reset all state
  void reset() {
    _responses.clear();
    _requests.clear();
  }
}
