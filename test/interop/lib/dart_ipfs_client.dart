// Minimal typed RPC client for the dart_ipfs /api/v0 endpoints used in interop tests.
// This is a scaffold; expand it as the scenario tests require more endpoints.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

  Future<Uint8List> dagExport(String cid) async {
    final query = {'arg': cid};
    final uri = Uri.http('$host:$port', '/api/v0/dag/export', query);
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      final response = await request.close();
      // Read raw bytes for CAR data
      final bytes = await response.fold<List<int>>(
        <int>[],
        (List<int> previous, List<int> chunk) => previous..addAll(chunk),
      );
      if (response.statusCode != 200) {
        final body = utf8.decode(bytes);
        throw HttpException(
          'dart_ipfs RPC dag/export returned ${response.statusCode}: $body',
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
          'dart_ipfs RPC dag/import returned ${response.statusCode}: $body',
        );
      }
    } finally {
      client.close();
    }
  }

  Future<String> dhtProvide(String cid) async {
    final response = await _rpc('dht/provide', arg: cid);
    return response;
  }

  Future<String> dhtFindProviders(String cid) async {
    final response = await _rpc('dht/findprovs', arg: cid);
    return response;
  }

  Future<Map<String, dynamic>> namePublish(String path) async {
    final response = await _rpc('name/publish', arg: path);
    return jsonDecode(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> nameResolve(String name) async {
    final response = await _rpc('name/resolve', arg: name);
    return jsonDecode(response) as Map<String, dynamic>;
  }

  Future<String> blockPut(List<int> data, {String? codec}) async {
    final query = <String, String>{};
    if (codec != null) {
      query['cid-codec'] = codec;
    }
    final uri = Uri.http('$host:$port', '/api/v0/block/put', query);
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.add(data);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw HttpException(
          'dart_ipfs RPC block/put returned ${response.statusCode}: $body',
        );
      }
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['Key'] as String;
    } finally {
      client.close();
    }
  }

  Future<List<int>> blockGet(String cid) async {
    final query = {'arg': cid};
    final uri = Uri.http('$host:$port', '/api/v0/block/get', query);
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      final response = await request.close();
      if (response.statusCode != 200) {
        final body = await response.transform(utf8.decoder).join();
        throw HttpException(
          'dart_ipfs RPC block/get returned ${response.statusCode}: $body',
        );
      }
      final body = await response.toList();
      return body.expand((e) => e).toList();
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
          'dart_ipfs RPC $command returned ${response.statusCode}: $body',
        );
      }
      return body;
    } finally {
      client.close();
    }
  }
}
