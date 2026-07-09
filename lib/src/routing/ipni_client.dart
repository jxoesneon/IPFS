// lib/src/routing/ipni_client.dart
import 'dart:convert';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:http/http.dart' as http;

/// Client for the InterPlanetary Network Indexer (IPNI) protocol.
///
/// Queries known IPNI endpoints (e.g. `https://cid.contact`) to discover
/// providers that have advertised a given CID.
class IPNIClient {
  /// Creates an [IPNIClient].
  ///
  /// If [endpoints] is omitted, a single default endpoint (`https://cid.contact`)
  /// is used. A custom [httpClient] may be supplied for testing or connection
  /// reuse.
  IPNIClient({
    List<String>? endpoints,
    http.Client? httpClient,
  })  : _endpoints = List<String>.from(endpoints ?? const ['https://cid.contact']),
        _httpClient = httpClient ?? http.Client();

  final List<String> _endpoints;
  final http.Client _httpClient;
  bool _disposed = false;

  /// The currently configured IPNI endpoints.
  List<String> get endpoints => List<String>.unmodifiable(_endpoints);

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

  /// Queries all configured endpoints for providers of [cid].
  ///
  /// Results from multiple endpoints are merged and deduplicated by peer ID.
  /// A 404 response from an endpoint is treated as an empty result. Any JSON
  /// parse error or non-2xx status causes an error response to be returned.
  Future<IPNIResponse> findProviders(CID cid) async {
    if (_disposed) {
      return IPNIResponse.error('Client disposed');
    }
    if (_endpoints.isEmpty) {
      return IPNIResponse.error('No endpoints configured');
    }

    final providersById = <String, IPNIProvider>{};

    for (final endpoint in _endpoints) {
      try {
        final url = Uri.parse('$endpoint/cid/${cid.toString()}');
        final response = await _httpClient.get(url, headers: {
          'Accept': 'application/json',
        });

        if (response.statusCode == 404) {
          continue;
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return IPNIResponse.error(
            'HTTP ${response.statusCode}: ${response.body}',
          );
        }

        final json = jsonDecode(response.body) as Map<String, dynamic>?;
        if (json == null || !json.containsKey('Providers')) {
          continue;
        }

        final providerList = json['Providers'] as List<dynamic>? ?? [];
        for (final item in providerList) {
          if (item is! Map<String, dynamic>) continue;
          final peerId = (item['ID'] as String? ?? '').trim();
          if (peerId.isEmpty) continue;

          final addrs = (item['Addrs'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              <String>[];

          final metadata = (item['Metadata'] as List<dynamic>?)
                  ?.whereType<Map<String, dynamic>>()
                  .map(
                    (md) => IPNIProviderMetadata(
                      protocol: md['Protocol'] as String? ?? '',
                      manifest: md['Manifest'] as String? ?? '',
                    ),
                  )
                  .toList() ??
              <IPNIProviderMetadata>[];

          final existing = providersById[peerId];
          if (existing != null) {
            final mergedAddrs = <String>{...existing.multiaddrs, ...addrs}.toList();
            providersById[peerId] = IPNIProvider(
              peerId: peerId,
              multiaddrs: mergedAddrs,
              metadata: existing.metadata,
            );
          } else {
            providersById[peerId] = IPNIProvider(
              peerId: peerId,
              multiaddrs: addrs,
              metadata: metadata,
            );
          }
        }
      } on FormatException catch (e) {
        return IPNIResponse.error('Invalid JSON response: $e');
      } catch (e) {
        return IPNIResponse.error('Request failed: $e');
      }
    }

    return IPNIResponse.success(providersById.values.toList());
  }
}

/// A single provider entry returned from an IPNI query.
class IPNIProvider {
  /// Creates an [IPNIProvider].
  IPNIProvider({
    required this.peerId,
    List<String>? multiaddrs,
    List<IPNIProviderMetadata>? metadata,
  })  : multiaddrs = List<String>.unmodifiable(multiaddrs ?? []),
        metadata = List<IPNIProviderMetadata>.unmodifiable(metadata ?? []);

  /// The provider's peer ID.
  final String peerId;

  /// Multiaddresses advertised by this provider.
  final List<String> multiaddrs;

  /// Optional metadata entries (e.g. transport protocols supported).
  final List<IPNIProviderMetadata> metadata;

  /// Serializes this provider to the IPNI JSON representation.
  Map<String, dynamic> toJson() => {
        'ID': peerId,
        'Addrs': List<String>.from(multiaddrs),
        'Metadata': metadata.map((m) => m.toJson()).toList(),
      };
}

/// Metadata attached to an IPNI provider entry.
class IPNIProviderMetadata {
  /// Creates an [IPNIProviderMetadata].
  IPNIProviderMetadata({required this.protocol, this.manifest = ''});

  /// The protocol name (e.g. `transport-bitswap`).
  final String protocol;

  /// An optional manifest identifier.
  final String manifest;

  /// Serializes this metadata entry to the IPNI JSON representation.
  Map<String, dynamic> toJson() => {
        'Protocol': protocol,
        if (manifest.isNotEmpty) 'Manifest': manifest,
      };
}

/// The result of an IPNI provider query.
class IPNIResponse {
  IPNIResponse._({required this.providers, required this.error});

  /// Creates a successful response with the given [providers].
  factory IPNIResponse.success(List<IPNIProvider> providers) =>
      IPNIResponse._(providers: providers, error: '');

  /// Creates a failed response with the given [error] description.
  factory IPNIResponse.error(String error) =>
      IPNIResponse._(providers: [], error: error);

  /// The providers discovered for the queried CID.
  final List<IPNIProvider> providers;

  /// A non-empty error description when the query failed.
  final String error;

  /// Whether the query succeeded. A successful response may have no providers.
  bool get isSuccess => error.isEmpty;
}
