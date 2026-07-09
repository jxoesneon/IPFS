// Minimal typed RPC client for the Kubo /api/v0 endpoints used in interop tests.
// This is a scaffold; expand it as the scenario tests require more endpoints.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class KuboClient {
  KuboClient({required this.host, required this.port});

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
          'Kubo RPC dag/export returned ${response.statusCode}: $body',
        );
      }
      return Uint8List.fromList(bytes);
    } finally {
      client.close();
    }
  }

  // Kubo /api/v0/dag/import expects multipart/form-data with a file field.
  Future<void> dagImport(Uint8List carData) async {
    final uri = Uri.http('$host:$port', '/api/v0/dag/import');
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      final boundary = '----KuboDagImport${DateTime.now().millisecondsSinceEpoch}';
      request.headers.contentType = ContentType(
        'multipart',
        'form-data',
        charset: 'utf-8',
        parameters: {'boundary': boundary},
      );
      final body = BytesBuilder()
        ..add(utf8.encode('--$boundary\r\n'))
        ..add(utf8.encode(
            'Content-Disposition: form-data; name="file"; filename="import.car"\r\n'))
        ..add(utf8.encode('Content-Type: application/vnd.ipld.car\r\n\r\n'))
        ..add(carData)
        ..add(utf8.encode('\r\n--$boundary--\r\n'));
      request.add(body.toBytes());
      final response = await request.close();
      final bodyText = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw HttpException(
          'Kubo RPC dag/import returned ${response.statusCode}: $bodyText',
        );
      }
    } finally {
      client.close();
    }
  }

  Future<Uint8List> blockGet(String cid) async {
    final query = {'arg': cid};
    final uri = Uri.http('$host:$port', '/api/v0/block/get', query);
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      final response = await request.close();
      // Read raw bytes for block data
      final bytes = await response.fold<List<int>>(
        <int>[],
        (List<int> previous, List<int> chunk) => previous..addAll(chunk),
      );
      if (response.statusCode != 200) {
        final body = utf8.decode(bytes);
        throw HttpException(
          'Kubo RPC block/get returned ${response.statusCode}: $body',
        );
      }
      return Uint8List.fromList(bytes);
    } finally {
      client.close();
    }
  }

  Future<String> blockPut(Uint8List data) async {
    final uri = Uri.http('$host:$port', '/api/v0/block/put');
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      final boundary = '----KuboBlockPut${DateTime.now().millisecondsSinceEpoch}';
      request.headers.contentType = ContentType(
        'multipart',
        'form-data',
        charset: 'utf-8',
        parameters: {'boundary': boundary},
      );
      final body = BytesBuilder()
        ..add(utf8.encode('--$boundary\r\n'))
        ..add(utf8.encode(
            'Content-Disposition: form-data; name="data"; filename="block"\r\n'))
        ..add(utf8.encode('Content-Type: application/octet-stream\r\n\r\n'))
        ..add(data)
        ..add(utf8.encode('\r\n--$boundary--\r\n'));
      request.add(body.toBytes());
      final response = await request.close();
      final bodyText = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw HttpException(
          'Kubo RPC block/put returned ${response.statusCode}: $bodyText',
        );
      }
      final json = jsonDecode(bodyText) as Map<String, dynamic>;
      return json['Key'] as String;
    } finally {
      client.close();
    }
  }

  Future<String> dhtProvide(String cid) async {
    final response = await _rpc('routing/provide', arg: cid);
    return response;
  }

  Future<String> dhtFindProviders(String cid) async {
    // Kubo v0.42 removed /api/v0/dht/* in favor of /api/v0/routing/*.
    final response = await _rpc('routing/findprovs', arg: cid);
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

  Future<List<int>> gatewayGetRaw(String gatewayHost, int gatewayPort, String cid) async {
    final uri = Uri.http('$gatewayHost:$gatewayPort', '/ipfs/$cid', {'format': 'raw'});
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != 200) {
        final body = await response.transform(utf8.decoder).join();
        throw HttpException(
          'Gateway GET raw returned ${response.statusCode}: $body',
        );
      }
      final body = await response.toList();
      return body.expand((e) => e).toList();
    } finally {
      client.close();
    }
  }

  Future<List<int>> gatewayGetCar(String gatewayHost, int gatewayPort, String cid) async {
    final uri = Uri.http('$gatewayHost:$gatewayPort', '/ipfs/$cid', {'format': 'car'});
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != 200) {
        final body = await response.transform(utf8.decoder).join();
        throw HttpException(
          'Gateway GET car returned ${response.statusCode}: $body',
        );
      }
      final body = await response.toList();
      return body.expand((e) => e).toList();
    } finally {
      client.close();
    }
  }

  Future<List<int>> gatewayGetDefault(String gatewayHost, int gatewayPort, String cid) async {
    final uri = Uri.http('$gatewayHost:$gatewayPort', '/ipfs/$cid');
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != 200) {
        final body = await response.transform(utf8.decoder).join();
        throw HttpException(
          'Gateway GET default returned ${response.statusCode}: $body',
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
          'Kubo RPC $command returned ${response.statusCode}: $body',
        );
      }
      return body;
    } finally {
      client.close();
    }
  }
}
