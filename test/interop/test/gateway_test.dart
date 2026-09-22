@Tags(['p0'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

// ignore: avoid_relative_lib_imports
import '../lib/dart_ipfs_client.dart';
// ignore: avoid_relative_lib_imports
import '../lib/kubo_client.dart';

const kKuboApiHost = 'kubo';
const kKuboApiPort = 5001;
const kDartIpfsApiHost = 'dart_ipfs';
const kDartIpfsApiPort = 5001;
const kDartIpfsGatewayHost = 'dart_ipfs';
const kDartIpfsGatewayPort = 8080;

Future<bool> _isHostReachable(String host, int port) async {
  try {
    final socket = await Socket.connect(
      host,
      port,
      timeout: const Duration(seconds: 2),
    );
    socket.destroy();
    return true;
  } catch (_) {
    return false;
  }
}

void main() {
  group('P0 Gateway retrieval with Kubo', () {
    late DartIpfsClient dartIpfs;
    late KuboClient kubo;

    setUpAll(() async {
      // Kubo and dart_ipfs are required members of the P0 matrix. Fail
      // loudly when either is unreachable instead of silently passing.
      final unreachable = <String>[
        if (!await _isHostReachable(kDartIpfsApiHost, kDartIpfsApiPort))
          '$kDartIpfsApiHost:$kDartIpfsApiPort',
        if (!await _isHostReachable(kKuboApiHost, kKuboApiPort))
          '$kKuboApiHost:$kKuboApiPort',
      ];
      if (unreachable.isNotEmpty) {
        throw StateError(
          'P0 gateway interop requires these hosts to be reachable: '
          '${unreachable.join(', ')}. Start the interop network '
          '(test/interop/docker-compose.yml) before running this suite.',
        );
      }

      dartIpfs = DartIpfsClient(host: kDartIpfsApiHost, port: kDartIpfsApiPort);
      kubo = KuboClient(host: kKuboApiHost, port: kKuboApiPort);
    });

    test('trustless gateway returns raw block with correct headers', () async {
      // Create test data
      final testData = utf8.encode('Hello, IPFS Gateway!');

      // Add block to dart_ipfs
      final cid = await dartIpfs.blockPut(testData, codec: 'raw');

      // Fetch the block via dart_ipfs gateway using Kubo client
      final fetchedData = await kubo.gatewayGetRaw(
        kDartIpfsGatewayHost,
        kDartIpfsGatewayPort,
        cid,
      );

      // Verify the content matches
      expect(fetchedData, equals(testData));
      expect(fetchedData.length, equals(testData.length));
    });

    test('trustless gateway returns a CAR response', () async {
      // Create test data
      final testData = utf8.encode('CAR test data');

      // Add block to dart_ipfs
      final cid = await dartIpfs.blockPut(testData, codec: 'raw');

      // Fetch CAR via dart_ipfs gateway using Kubo client
      final carData = await kubo.gatewayGetCar(
        kDartIpfsGatewayHost,
        kDartIpfsGatewayPort,
        cid,
      );

      // Verify CAR is not empty and has valid structure
      expect(carData.isNotEmpty, isTrue);

      // CAR files start with a header (DAG-CBOR encoded)
      // Minimum valid CAR has at least a few bytes for header
      expect(carData.length, greaterThan(10));

      // CAR v1 starts with a varint length prefix for the header
      // The first byte should be a valid varint (not 0x00 for empty)
      expect(carData[0], isNot(equals(0)));

      // The original data should be present in the CAR (after the header)
      // CAR format: [header length][header bytes][block length][block bytes]...
      // We can verify the original data bytes are somewhere in the CAR
      final dataFound = _searchBytes(carData, testData);
      expect(dataFound, isTrue);
    });

    test('Accept header negotiates application/vnd.ipld.raw', () async {
      final testData = utf8.encode('Accept negotiation test');
      final cid = await dartIpfs.blockPut(testData, codec: 'raw');

      final result = await _gatewayRequest(
        '/ipfs/$cid',
        headers: {'accept': 'application/vnd.ipld.raw'},
      );

      expect(result.statusCode, equals(200));
      expect(
        result.headers.value('content-type'),
        equals('application/vnd.ipld.raw'),
      );
      // Spec: negotiated responses identify the selected representation.
      expect(result.headers.value('content-location'), contains('format=raw'));
      expect(result.body, equals(testData));
    });

    test('?format=dag-json returns serialized IPLD node', () async {
      final testData = utf8.encode('dag-json test');
      final cid = await dartIpfs.blockPut(testData, codec: 'raw');

      final result = await _gatewayRequest('/ipfs/$cid?format=dag-json');

      expect(result.statusCode, equals(200));
      expect(
        result.headers.value('content-type'),
        equals('application/vnd.ipld.dag-json'),
      );
      // Raw blocks serialize to {"/": {"bytes": "<base64>"}} per DAG-JSON.
      final node = jsonDecode(utf8.decode(result.body)) as Map;
      expect(node, contains('/'));
    });

    test('?format=dag-cbor returns serialized IPLD node', () async {
      final testData = utf8.encode('dag-cbor test');
      final cid = await dartIpfs.blockPut(testData, codec: 'raw');

      final result = await _gatewayRequest('/ipfs/$cid?format=dag-cbor');

      expect(result.statusCode, equals(200));
      expect(
        result.headers.value('content-type'),
        equals('application/vnd.ipld.dag-cbor'),
      );
      expect(result.body, isNotEmpty);
    });

    test('raw response carries spec Content-Disposition filename', () async {
      final testData = utf8.encode('disposition test');
      final cid = await dartIpfs.blockPut(testData, codec: 'raw');

      final result = await _gatewayRequest('/ipfs/$cid?format=raw');

      expect(result.statusCode, equals(200));
      expect(
        result.headers.value('content-disposition'),
        contains('filename="$cid.bin"'),
      );
    });

    test('unsupported format request returns 406 Not Acceptable', () async {
      final testData = utf8.encode('not acceptable test');
      final cid = await dartIpfs.blockPut(testData, codec: 'raw');

      // 'tar' is a valid path-gateway format this implementation does not
      // produce, so the trustless contract requires 406 — never HTML.
      final result = await _gatewayRequest('/ipfs/$cid?format=tar');

      expect(result.statusCode, equals(406));
      expect(
        result.headers.value('content-type') ?? '',
        isNot(contains('text/html')),
      );
    });

    test('?format=ipns-record returns a signed IPNS record', () async {
      final testData = utf8.encode('ipns record test');
      final cid = await dartIpfs.blockPut(testData, codec: 'raw');

      // Publish the CID under the node's own IPNS key.
      final published = await dartIpfs.namePublish('/ipfs/$cid');
      final name = (published['Name'] ?? published['name']) as String;

      final result = await _gatewayRequest('/ipns/$name?format=ipns-record');

      expect(result.statusCode, equals(200));
      expect(
        result.headers.value('content-type'),
        equals('application/vnd.ipfs.ipns-record'),
      );
      // Signed IpnsEntry protobuf bytes.
      expect(result.body.length, greaterThan(20));
    });

    test('default gateway response returns the original content', () async {
      // Create test data
      final testData = utf8.encode('Default gateway test content');

      // Add block to dart_ipfs
      final cid = await dartIpfs.blockPut(testData, codec: 'raw');

      // Fetch via default gateway path using Kubo client
      final fetchedData = await kubo.gatewayGetDefault(
        kDartIpfsGatewayHost,
        kDartIpfsGatewayPort,
        cid,
      );

      // Verify the content matches
      expect(fetchedData, equals(testData));
      expect(fetchedData.length, equals(testData.length));
    });
  });
}

/// A gateway HTTP response: status, headers, and body bytes.
class _GatewayResult {
  _GatewayResult(this.statusCode, this.headers, this.body);

  final int statusCode;
  final HttpHeaders headers;
  final List<int> body;
}

/// Performs a GET against the dart_ipfs trustless gateway, returning the
/// full response so tests can assert on status, headers, and body.
Future<_GatewayResult> _gatewayRequest(
  String path, {
  Map<String, String>? headers,
}) async {
  // Uri.parse keeps the ?query intact; Uri.http would percent-encode it.
  final uri = Uri.parse(
    'http://$kDartIpfsGatewayHost:$kDartIpfsGatewayPort$path',
  );
  final client = HttpClient();
  try {
    final request = await client.getUrl(uri);
    headers?.forEach(request.headers.add);
    final response = await request.close();
    final chunks = await response.toList();
    return _GatewayResult(
      response.statusCode,
      response.headers,
      chunks.expand((e) => e).toList(),
    );
  } finally {
    client.close();
  }
}

/// Helper to search for a byte sequence within a larger byte array.
bool _searchBytes(List<int> haystack, List<int> needle) {
  if (needle.isEmpty) return true;
  if (haystack.length < needle.length) return false;

  for (var i = 0; i <= haystack.length - needle.length; i++) {
    var found = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        found = false;
        break;
      }
    }
    if (found) return true;
  }
  return false;
}
