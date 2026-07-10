// lib/src/routing/reframe_routing.dart
import 'dart:convert';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:http/http.dart' as http;

/// Client for the Reframe delegated routing protocol.
///
/// Reframe exposes a simple HTTP endpoint that accepts a `FindProviders`
/// request for a CID and returns candidate providers. By default the client
/// uses the original Reframe POST request, but it can also query the newer
/// `/routing/v1/providers/{cid}` GET endpoint by setting [useGetApi].
class ReframeRoutingClient {
  /// Creates a [ReframeRoutingClient].
  ///
  /// If [endpoints] is omitted, the client has no configured endpoints and
  /// [findProviders] will return an error. A custom [httpClient] may be supplied
  /// for testing or connection reuse.
  ///
  /// When [useGetApi] is true, requests are sent as GET queries to
  /// `/routing/v1/providers/{cid}` instead of POST bodies.
  ReframeRoutingClient({
    List<String>? endpoints,
    http.Client? httpClient,
    bool useGetApi = false,
  }) : _endpoints = List<String>.from(endpoints ?? const []),
       _httpClient = httpClient ?? http.Client(),
       _useGetApi = useGetApi;

  final List<String> _endpoints;
  final http.Client _httpClient;
  final bool _useGetApi;
  bool _disposed = false;

  /// The currently configured Reframe endpoints.
  List<String> get endpoints => List<String>.unmodifiable(_endpoints);

  /// Whether the client queries the GET `/routing/v1/providers/{cid}` endpoint.
  bool get useGetApi => _useGetApi;

  /// Adds a new endpoint if it is not already present.
  void addEndpoint(String endpoint) {
    if (!_endpoints.contains(endpoint)) {
      _endpoints.add(endpoint);
    }
  }

  /// Removes the given endpoint, if present.
  void removeEndpoint(String endpoint) {
    _endpoints.remove(endpoint);
  }

  /// Disposes the client and closes the underlying HTTP client.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _httpClient.close();
  }

  /// Queries all configured Reframe endpoints for providers of [cid].
  ///
  /// Results from multiple endpoints are merged (no deduplication). A 404
  /// response is treated as an empty result. Any JSON parse error or non-2xx
  /// status causes an error response to be returned.
  Future<ReframeResponse> findProviders(CID cid) async {
    if (_disposed) {
      return ReframeResponse.error('Client disposed');
    }
    if (_endpoints.isEmpty) {
      return ReframeResponse.error('No endpoints configured');
    }

    final providers = <ReframeProvider>[];

    for (final endpoint in _endpoints) {
      try {
        final response = await _queryEndpoint(endpoint, cid);

        if (response.statusCode == 404) {
          continue;
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return ReframeResponse.error(
            'HTTP ${response.statusCode}: ${response.body}',
          );
        }

        final json = jsonDecode(response.body) as Map<String, dynamic>?;
        if (json == null) {
          continue;
        }

        final parsed = _parseProviders(json);
        providers.addAll(parsed);
      } on FormatException catch (e) {
        return ReframeResponse.error('Invalid JSON response: $e');
      } catch (e) {
        return ReframeResponse.error('Request failed: $e');
      }
    }

    return ReframeResponse.success(providers);
  }

  Future<http.Response> _queryEndpoint(String endpoint, CID cid) async {
    final url = Uri.parse('$endpoint/routing/v1/providers/${cid.toString()}');
    if (_useGetApi) {
      return _httpClient.get(url, headers: {'Accept': 'application/json'});
    }

    final body = jsonEncode({
      'FindProviders': {'Key': cid.toString()},
    });
    return _httpClient.post(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: body,
    );
  }

  List<ReframeProvider> _parseProviders(Map<String, dynamic> json) {
    final providers = <ReframeProvider>[];

    final List<dynamic> providerList;
    if (json.containsKey('FindProviders')) {
      final findProviders = json['FindProviders'] as Map<String, dynamic>?;
      providerList = findProviders?['Providers'] as List<dynamic>? ?? [];
    } else if (json.containsKey('Providers')) {
      providerList = json['Providers'] as List<dynamic>? ?? [];
    } else {
      return providers;
    }

    for (final item in providerList) {
      if (item is! Map<String, dynamic>) continue;
      final peerId = (item['ID'] as String? ?? '').trim();
      if (peerId.isEmpty) continue;

      final addrs =
          (item['Addrs'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[];

      final protocols =
          (item['Protocols'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[];

      providers.add(
        ReframeProvider(
          peerId: peerId,
          multiaddrs: addrs,
          protocols: protocols,
        ),
      );
    }

    return providers;
  }
}

/// A single provider entry returned from a Reframe query.
class ReframeProvider {
  /// Creates a [ReframeProvider].
  ReframeProvider({
    required this.peerId,
    List<String>? multiaddrs,
    List<String>? protocols,
  }) : multiaddrs = List<String>.unmodifiable(multiaddrs ?? []),
       protocols = List<String>.unmodifiable(protocols ?? []);

  /// The provider's peer ID.
  final String peerId;

  /// Multiaddresses advertised by this provider.
  final List<String> multiaddrs;

  /// Protocols supported by this provider (e.g. `transport-bitswap`).
  final List<String> protocols;

  /// Serializes this provider to the Reframe JSON representation.
  Map<String, dynamic> toJson() => {
    'ID': peerId,
    'Addrs': List<String>.from(multiaddrs),
    'Protocols': List<String>.from(protocols),
  };
}

/// The result of a Reframe provider query.
class ReframeResponse {
  ReframeResponse._({required this.providers, required this.error});

  /// Creates a successful response with the given [providers].
  factory ReframeResponse.success(List<ReframeProvider> providers) =>
      ReframeResponse._(providers: providers, error: '');

  /// Creates a failed response with the given [error] description.
  factory ReframeResponse.error(String error) =>
      ReframeResponse._(providers: [], error: error);

  /// The providers discovered for the queried CID.
  final List<ReframeProvider> providers;

  /// A non-empty error description when the query failed.
  final String error;

  /// Whether the query succeeded. A successful response may have no providers.
  bool get isSuccess => error.isEmpty;
}
