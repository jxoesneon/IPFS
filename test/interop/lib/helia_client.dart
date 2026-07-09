// Minimal typed RPC client for the Helia interop server endpoints.
// This client provides compatibility with the Kubo-like API exposed by the Helia server.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class HeliaClient {
  HeliaClient({required this.host, required this.port});

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

  Future<Map<String, dynamic>> add(String data) async {
    final uri = Uri.http('$host:$port', '/api/v0/add');
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType('application', 'octet-stream');
      request.add(utf8.encode(data));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw HttpException(
          'Helia RPC add returned ${response.statusCode}: $body',
        );
      }
      return jsonDecode(body) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  Future<Uint8List> dagExport(String cid) async {
    final query = {'arg': cid};
    final uri = Uri.http('$host:$port', '/api/v0/dag/export', query);
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      final bytes = await response.fold<List<int>>(
        <int>[],
        (List<int> previous, List<int> chunk) => previous..addAll(chunk),
      );
      if (response.statusCode != 200) {
        final body = utf8.decode(bytes);
        throw HttpException(
          'Helia RPC dag/export returned ${response.statusCode}: $body',
        );
      }
      return Uint8List.fromList(bytes);
    } finally {
      client.close();
    }
  }

  Future<void> dagImport(Uint8List carData) async {
    final uri = Uri.http('$host:$port', '/api/v0/dag/import');
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType('application', 'vnd.ipld.car');
      request.add(carData);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw HttpException(
          'Helia RPC dag/import returned ${response.statusCode}: $body',
        );
      }
    } finally {
      client.close();
    }
  }

  Future<String> cat(String cid) async {
    final query = {'arg': cid};
    final uri = Uri.http('$host:$port', '/api/v0/cat', query);
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw HttpException(
          'Helia RPC cat returned ${response.statusCode}: $body',
        );
      }
      return body;
    } finally {
      client.close();
    }
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
          'Helia RPC $command returned ${response.statusCode}: $body',
        );
      }
      return body;
    } finally {
      client.close();
    }
  }
}
