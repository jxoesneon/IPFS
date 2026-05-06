import 'dart:async';
import 'dart:typed_data';

import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:http/http.dart' as http;

/// Client for interacting with public IPFS HTTP Gateways.
///
/// This allows the node to retrieve content from the public IPFS network
/// even if the P2P layer is incompatible or disconnected.
///
/// It implements a round-robin fallback mechanism across multiple public gateways.
class HttpGatewayClient {
  /// Creates a new [HttpGatewayClient].
  ///
  /// If [client] is not provided, a default [http.Client] is created.
  /// Remember to call [close] when finished to release resources.
  HttpGatewayClient({http.Client? client})
    : _client = client ?? http.Client(),
      _internalClient = client == null;

  final Logger _logger = Logger('HttpGatewayClient');
  final http.Client _client;
  final bool _internalClient;

  /// Default public gateways to use for fallback.
  final List<String> _gateways = [
    'https://ipfs.io/ipfs/',
    'https://dweb.link/ipfs/',
    'https://gateway.pinata.cloud/ipfs/',
    'https://cloudflare-ipfs.com/ipfs/',
  ];

  /// Fetches raw data for a CID from available gateways.
  ///
  /// [cid]: The Content Identifier to retrieve.
  /// [baseUrl]: Optional specific gateway URL to use (skips round-robin if provided).
  ///
  /// Tries gateways in round-robin fashion if [baseUrl] is null.
  /// Returns [Uint8List] containing the data if successful, null otherwise.
  ///
  /// Throws [TimeoutException] if all gateways time out.
  Future<Uint8List?> get(String cid, {String? baseUrl}) async {
    // If a specific base URL is provided, use only that.
    if (baseUrl != null) {
      return _fetchFromGateway(baseUrl, cid);
    }

    // Fallback: Try known public gateways
    for (final gateway in _gateways) {
      final result = await _fetchFromGateway(gateway, cid);
      if (result != null) {
        return result;
      }
    }

    _logger.warning('Failed to retrieve CID $cid from all gateways');
    return null;
  }

  /// Internal helper to fetch data from a specific gateway.
  Future<Uint8List?> _fetchFromGateway(String gateway, String cid) async {
    try {
      final cleanBase = gateway.endsWith('/') ? gateway : '$gateway/';
      final url = Uri.parse('$cleanBase$cid');
      _logger.debug('Fetching from gateway: $url');

      final response = await _client
          .get(url)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _logger.info('Successfully retrieved CID $cid from $gateway');
        return response.bodyBytes;
      } else if (response.statusCode == 404) {
        _logger.debug('CID $cid not found on gateway $gateway (404)');
      } else {
        _logger.warning(
          'Gateway $gateway returned status code ${response.statusCode} for CID $cid',
        );
      }
    } on TimeoutException {
      _logger.debug('Gateway $gateway timed out while fetching CID $cid');
    } catch (e, stackTrace) {
      _logger.error(
        'Error fetching CID $cid from gateway $gateway',
        e,
        stackTrace,
      );
    }
    return null;
  }

  /// Checks if the public network is reachable via gateways.
  ///
  /// Tests reachability by attempting a HEAD request to a known CID.
  Future<bool> isReachable() async {
    try {
      // Use the empty directory CID for a lightweight check
      const emptyDirCid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';

      final response = await _client
          .head(Uri.parse('https://ipfs.io/ipfs/$emptyDirCid'))
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      _logger.debug('Public gateway reachability check failed: $e');
      return false;
    }
  }

  /// Closes the underlying HTTP client if it was created internally.
  void close() {
    if (_internalClient) {
      _client.close();
      _logger.debug('Internal HTTP client closed.');
    }
  }
}
