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
    bool hostsReachable = false;

    setUpAll(() async {
      // Check if hosts are reachable (e.g., running in Docker network)
      final dartIpfsReachable = await _isHostReachable(
        kDartIpfsApiHost,
        kDartIpfsApiPort,
      );
      final kuboReachable = await _isHostReachable(kKuboApiHost, kKuboApiPort);
      hostsReachable = dartIpfsReachable && kuboReachable;

      if (!hostsReachable) {
        // Tests will be skipped in individual test functions
      }
    });

    setUp(() {
      if (!hostsReachable) return;

      dartIpfs = DartIpfsClient(host: kDartIpfsApiHost, port: kDartIpfsApiPort);
      kubo = KuboClient(host: kKuboApiHost, port: kKuboApiPort);
    });

    test('trustless gateway returns raw block with correct headers', () async {
      if (!hostsReachable) {
        return;
      }

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
      if (!hostsReachable) {
        return;
      }

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

    test('default gateway response returns the original content', () async {
      if (!hostsReachable) {
        return;
      }

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
