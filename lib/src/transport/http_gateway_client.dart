import 'dart:async';
import 'dart:typed_data';

import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:http/http.dart' as http;

/// Client for interacting with public IPFS HTTP Gateways.
///
/// This allows the node to retrieve content from the public IPFS network
/// even if the P2P layer is incompatible or disconnected.
class HttpGatewayClient {
  /// Creates a new [HttpGatewayClient].
  HttpGatewayClient({http.Client? client}) : _client = client ?? http.Client();

  final Logger _logger = Logger('HttpGatewayClient');
  final http.Client _client;

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
  /// Tries gateways in round-robin or race fashion if [baseUrl] is null.
  Future<Uint8List?> get(String cid, {String? baseUrl}) async {
    // If a specific base URL is provided (e.g. from GatewayMode), use only that.
    if (baseUrl != null) {
      try {
        final cleanBase = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
        final url = Uri.parse('$cleanBase$cid');
        _logger.debug('Fetching from specific gateway: $url');

        final response = await _client
            .get(url)
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          return response.bodyBytes;
        } else {
          _logger.warning('Gateway $baseUrl returned ${response.statusCode}');
          return null;
        }
      } catch (e) {
        _logger.error('Error fetching from gateway $baseUrl: $e');
        return null;
      }
    }

    // Fallback: Try known public gateways
    for (final gateway in _gateways) {
      try {
        final url = Uri.parse('$gateway$cid');
        _logger.debug('Trying gateway: $url');

        final response = await _client
            .get(url)
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          _logger.info('Successfully retrieved CID $cid from $gateway');
          return response.bodyBytes;
        } else {
          _logger.debug('Gateway $gateway returned ${response.statusCode}');
        }
      } catch (e) {
        _logger.debug('Error fetching from gateway $gateway: $e');
      }
    }

    _logger.warning('Failed to retrieve CID $cid from all gateways');
    return null;
  }

  /// Checks if the public network is reachable via gateways.
  Future<bool> isReachable() async {
    try {
      // Try to fetch a known small CID (e.g., empty directory or known file)
      // CID for "Hello World" or similar
      // Use QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn (empty dir) - might be safer

      final response = await _client
          .head(
            Uri.parse(
              'https://ipfs.io/ipfs/QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn',
            ),
          )
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
