import 'dart:async';
import 'dart:convert';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:http/http.dart' as http;

/// Response from a routing request.
class RoutingResponse {
  /// Creates a routing response.
  RoutingResponse({this.providers = const [], this.error});

  /// Creates a successful response with providers.
  factory RoutingResponse.success(List<String> providers) {
    return RoutingResponse(providers: providers);
  }

  /// Creates an error response.
  factory RoutingResponse.error(String message) {
    return RoutingResponse(error: message);
  }

  /// List of provider peer IDs.
  final List<String> providers;

  /// Error message if the request failed.
  final String? error;

  /// Returns true if the request succeeded.
  bool get isSuccess => error == null;
}

/// Handles delegated routing operations following the IPFS Delegated Routing V1 HTTP API spec.
class DelegatedRoutingHandler {
  /// Creates a handler with optional custom endpoint and HTTP client.
  DelegatedRoutingHandler({String? delegateEndpoint, http.Client? httpClient})
    : _delegateEndpoint = delegateEndpoint ?? _defaultDelegateEndpoint,
      _httpClient = httpClient ?? http.Client();

  static const String _defaultDelegateEndpoint = 'https://delegated-ipfs.dev';
  final String _delegateEndpoint;
  final http.Client _httpClient;

  /// Finds providers for a given CID using the delegated routing API
  Future<RoutingResponse> findProviders(CID cid) async {
    try {
      // Validate CID
      if (cid.toString().isEmpty) {
        return RoutingResponse.error('Invalid CID');
      }

      // Construct the API endpoint URL
      final url = Uri.parse('$_delegateEndpoint/routing/v1/providers/$cid');

      // Make the HTTP request
      final response = await _httpClient.get(
        url,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        // Parse the response
        final dynamic decoded;
        try {
          decoded = json.decode(response.body);
        } on FormatException catch (e) {
          return RoutingResponse.error('Invalid JSON response: $e');
        }

        if (decoded is! Map<String, dynamic>) {
          return RoutingResponse.error('Invalid response format');
        }

        final providersList = decoded['Providers'];
        if (providersList is List) {
          final providers = providersList
              .where((provider) => provider is Map<String, dynamic>)
              .map((provider) => (provider as Map<String, dynamic>)['ID'])
              .where((id) => id is String && id.isNotEmpty)
              .cast<String>()
              .toList();

          return RoutingResponse.success(providers);
        }

        return RoutingResponse.success([]);
      } else if (response.statusCode == 404) {
        // No providers found is a valid response
        return RoutingResponse.success([]);
      } else {
        return RoutingResponse.error(
          'Failed to find providers: HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      return RoutingResponse.error('Error finding providers: $e');
    }
  }

  /// Closes the HTTP client
  void dispose() {
    _httpClient.close();
  }
}
