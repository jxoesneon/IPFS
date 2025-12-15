import 'dart:async';
import 'dart:convert';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:http/http.dart' as http;

/// Response from a routing request
class RoutingResponse {
  final List<String> providers;
  final String? error;

  RoutingResponse({this.providers = const [], this.error});

  factory RoutingResponse.success(List<String> providers) {
    return RoutingResponse(providers: providers);
  }

  factory RoutingResponse.error(String message) {
    return RoutingResponse(error: message);
  }

  bool get isSuccess => error == null;
}

/// Handles delegated routing operations following the IPFS Delegated Routing V1 HTTP API spec
class DelegatedRoutingHandler {
  static const String _defaultDelegateEndpoint = 'https://delegated-ipfs.dev';
  final String _delegateEndpoint;
  final http.Client _httpClient;

  DelegatedRoutingHandler({String? delegateEndpoint, http.Client? httpClient})
    : _delegateEndpoint = delegateEndpoint ?? _defaultDelegateEndpoint,
      _httpClient = httpClient ?? http.Client();

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
        final Map<String, dynamic> data = json.decode(response.body);

        if (data.containsKey('Providers')) {
          final List<dynamic> providersList = data['Providers'];
          final providers = providersList
              .map((provider) => provider['ID'] as String)
              .where((id) => id.isNotEmpty)
              .toList();

          return RoutingResponse.success(providers);
        } else {
          return RoutingResponse.success([]);
        }
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
