// Minimal typed RPC client for the dart_ipfs /api/v0 endpoints used in interop tests.
// This is a scaffold; expand it as the scenario tests require more endpoints.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'pubsub_rpc.dart';

class DartIpfsClient with PubsubRpc {
  DartIpfsClient({required this.host, required this.port});

  @override
  final String host;
  @override
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

  /// `POST /api/v0/swarm/peers` — the peers dart_ipfs is connected to.
  Future<List<Map<String, dynamic>>> swarmPeers() async {
    final response = await _rpc('swarm/peers');
    final json = jsonDecode(response) as Map<String, dynamic>;
    return [
      for (final p in json['Peers'] as List? ?? const [])
        (p as Map).cast<String, dynamic>(),
    ];
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

  /// Adds [data] as a UnixFS file via `POST /api/v0/add` and returns the
  /// resulting `{Name, Hash, Size}` object (the DAG root entry).
  // dart_ipfs /api/v0/add expects multipart/form-data and answers NDJSON,
  // matching the Kubo add response shape ({Name, Hash, Size}).
  Future<Map<String, dynamic>> add(List<int> data) async {
    final uri = Uri.http('$host:$port', '/api/v0/add');
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      final boundary =
          '----DartIpfsAdd${DateTime.now().millisecondsSinceEpoch}';
      request.headers.contentType = ContentType(
        'multipart',
        'form-data',
        charset: 'utf-8',
        parameters: {'boundary': boundary},
      );
      final body = BytesBuilder()
        ..add(utf8.encode('--$boundary\r\n'))
        ..add(
          utf8.encode(
            'Content-Disposition: form-data; name="file"; '
            'filename="data"\r\n',
          ),
        )
        ..add(utf8.encode('Content-Type: application/octet-stream\r\n\r\n'))
        ..add(data)
        ..add(utf8.encode('\r\n--$boundary--\r\n'));
      request.add(body.toBytes());
      final response = await request.close();
      final bodyText = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw HttpException(
          'dart_ipfs RPC add returned ${response.statusCode}: $bodyText',
        );
      }
      return _lastNdjsonObject(bodyText, 'add');
    } finally {
      client.close();
    }
  }

  /// Adds [files] (name → bytes) via `POST /api/v0/add?wrap-with-directory`
  /// and returns the wrapping directory's `{Name, Hash, Size}` entry.
  Future<Map<String, dynamic>> addWrapped(Map<String, List<int>> files) async {
    final uri = Uri.http('$host:$port', '/api/v0/add', {
      'wrap-with-directory': 'true',
    });
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      final boundary =
          '----DartIpfsAddDir${DateTime.now().millisecondsSinceEpoch}';
      request.headers.contentType = ContentType(
        'multipart',
        'form-data',
        charset: 'utf-8',
        parameters: {'boundary': boundary},
      );
      final body = BytesBuilder();
      for (final entry in files.entries) {
        body
          ..add(utf8.encode('--$boundary\r\n'))
          ..add(
            utf8.encode(
              'Content-Disposition: form-data; name="file"; '
              'filename="${entry.key}"\r\n',
            ),
          )
          ..add(utf8.encode('Content-Type: application/octet-stream\r\n\r\n'))
          ..add(entry.value)
          ..add(utf8.encode('\r\n'));
      }
      body.add(utf8.encode('--$boundary--\r\n'));
      request.add(body.toBytes());
      final response = await request.close();
      final bodyText = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw HttpException(
          'dart_ipfs RPC add returned ${response.statusCode}: $bodyText',
        );
      }
      return _lastNdjsonObject(bodyText, 'add');
    } finally {
      client.close();
    }
  }

  /// Returns the content addressed by [cid] via `POST /api/v0/cat`,
  /// resolving UnixFS DAGs to their file payload.
  Future<Uint8List> cat(String cid) async {
    final query = {'arg': cid};
    final uri = Uri.http('$host:$port', '/api/v0/cat', query);
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      final response = await request.close();
      final bytes = await response.fold<List<int>>(
        <int>[],
        (List<int> previous, List<int> chunk) => previous..addAll(chunk),
      );
      if (response.statusCode != 200) {
        final body = utf8.decode(bytes);
        throw HttpException(
          'dart_ipfs RPC cat returned ${response.statusCode}: $body',
        );
      }
      return Uint8List.fromList(bytes);
    } finally {
      client.close();
    }
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

  // Parses the last non-empty NDJSON line of an add-style response. When a
  // request produces multiple entries (e.g. wrap-with-directory) the final
  // object is the DAG root, matching Kubo's response ordering.
  Map<String, dynamic> _lastNdjsonObject(String body, String command) {
    final lines = body
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      throw HttpException(
        'dart_ipfs RPC $command returned an empty response body',
      );
    }
    return jsonDecode(lines.last) as Map<String, dynamic>;
  }

  Future<String> _rpc(String command, {String? arg}) async {
    final query = arg != null ? {'arg': arg} : null;
    final uri = Uri.http('$host:$port', '/api/v0/$command', query);
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.postUrl(uri);
      final response = await request.close().timeout(
        const Duration(seconds: 60),
      );
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
