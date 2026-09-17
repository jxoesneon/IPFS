import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/ipfs.dart';
import 'package:test/test.dart';

void main() {
  group('IPFS facade delegates', () {
    late IPFS ipfs;

    setUp(() async {
      final config = IPFSConfig(
        datastorePath:
            './test_tmp/ipfs_delegates_${DateTime.now().millisecondsSinceEpoch}',
        blockStorePath:
            './test_tmp/ipfs_delegates_blocks_${DateTime.now().millisecondsSinceEpoch}',
        offline: true, // Run offline to make tests faster/isolated
      );
      ipfs = await IPFS.create(config: config);
    });

    tearDown(() async {
      await ipfs.stop();
    });

    test('connectedPeers returns a list (empty offline)', () async {
      await ipfs.start();
      expect(await ipfs.connectedPeers, isA<List<String>>());
      expect(await ipfs.connectedPeers, isEmpty);
    });

    test('addresses returns a list (empty offline)', () async {
      await ipfs.start();
      expect(ipfs.addresses, isA<List<String>>());
      expect(ipfs.addresses, isEmpty);
    });

    test('resolvePeerId returns a list (empty offline)', () async {
      await ipfs.start();
      expect(ipfs.resolvePeerId('QmSomePeer'), isA<List<String>>());
      expect(ipfs.resolvePeerId('QmSomePeer'), isEmpty);
    });

    test('publicKey returns a string', () async {
      await ipfs.start();
      expect(await ipfs.publicKey, isA<String>());
    });

    test('cat delegates to get and returns stored content', () async {
      await ipfs.start();
      final content = Uint8List.fromList(utf8.encode('Cat Me'));
      final cid = await ipfs.addFile(content);

      final retrieved = await ipfs.cat(cid);
      expect(retrieved, equals(content));
    });

    test('addFileStream adds streamed content', () async {
      await ipfs.start();
      final content = Uint8List.fromList(utf8.encode('Streamed Content'));
      final stream = Stream<List<int>>.fromIterable([
        content.sublist(0, 8),
        content.sublist(8),
      ]);

      final cid = await ipfs.addFileStream(stream);
      expect(cid, isNotEmpty);

      final retrieved = await ipfs.get(cid);
      expect(retrieved, equals(content));
    });

    test('pinnedCids contains a CID after pinning', () async {
      await ipfs.start();
      final content = Uint8List.fromList(utf8.encode('Pin Me Too'));
      final cid = await ipfs.addFile(content);

      await ipfs.pin(cid);
      expect(await ipfs.pinnedCids, contains(cid));
    });

    test('bandwidth counters and DHT peer count report zeros offline', () async {
      await ipfs.start();
      expect(ipfs.bandwidthIn, equals(0));
      expect(ipfs.bandwidthOut, equals(0));
      expect(ipfs.dhtPeerCount, equals(0));
    });

    test('bandwidthMetrics exposes a metrics stream', () async {
      await ipfs.start();
      expect(ipfs.bandwidthMetrics, isA<Stream<Map<String, dynamic>>>());
    });

    test('getHealthStatus returns subsystem status map', () async {
      await ipfs.start();
      final status = await ipfs.getHealthStatus();
      expect(status, isA<Map<String, dynamic>>());
      expect(
        status.keys,
        containsAll(['core', 'storage', 'network', 'services']),
      );
    });

    test('setGatewayMode accepts all modes without throwing', () async {
      await ipfs.start();
      ipfs.setGatewayMode(GatewayMode.internal);
      ipfs.setGatewayMode(GatewayMode.local);
      ipfs.setGatewayMode(GatewayMode.public);
      ipfs.setGatewayMode(GatewayMode.custom, customUrl: 'https://gw.example');
    });

    test('restart completes a stop/start cycle', () async {
      await ipfs.start();
      await ipfs.restart();
      // Successful return means stop() then start() both completed.
    });

    test('connectToPeer throws in offline mode', () async {
      await ipfs.start();
      await expectLater(
        () => ipfs.connectToPeer('/ip4/127.0.0.1/tcp/4001'),
        throwsA(anything), // ComponentError (an Error, not Exception)
      );
    });

    test('disconnectFromPeer completes in offline mode', () async {
      await ipfs.start();
      await ipfs.disconnectFromPeer('QmSomePeer');
    });

    test('provide throws in offline mode (DHT unavailable)', () async {
      await ipfs.start();
      final content = Uint8List.fromList(utf8.encode('Provide Me'));
      final cid = await ipfs.addFile(content);

      await expectLater(() => ipfs.provide(cid), throwsException);
      // Invalid CIDs also throw (offline guard trips before parsing).
      await expectLater(() => ipfs.provide('not-a-cid'), throwsException);
    });
  });
}
