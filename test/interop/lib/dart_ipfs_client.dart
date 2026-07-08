// Minimal typed RPC client for the dart_ipfs /api/v0 endpoints used in interop tests.
// This is a scaffold; expand it as the scenario tests require more endpoints.

import 'dart:convert';
import 'dart:io';

class DartIpfsClient {
  DartIpfsClient({required this.host, required this.port});

  final String host;
  final int port;

  Future<Map<String, dynamic>> id() async {
    final response = await _rpc('id');
    return jsonDecode(response) as Map<String, dynamic>;
  }

  Future<String> version() async {
    final response = await _rpc('version');
    final json = jsonDecode(response) as Map<String, dynamic>;
    return json['Version'] as String;
  }

  Future<Map<String, dynamic>> swarmConnect(String multiaddr) async {
    final response = await _rpc('swarm/connect', arg: multiaddr);
    return jsonDecode(response) as Map<String, dynamic>;
  }

  Future<String> _rpc(String command, {String? arg}) async {
    final query = arg != null ? {'arg': arg} : null;
    final uri = Uri.http('$host:$port', '/api/v0/$command', query);
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw HttpException(
            'dart_ipfs RPC $command returned ${response.statusCode}: $body');
      }
      return body;
    } finally {
      client.close();
    }
  }
}
