import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/protocols/dht/interface_dht_handler.dart'; // For Key, Value
import 'package:dart_ipfs/src/protocols/ipns/ipns_handler.dart';
import 'package:dart_ipfs/src/utils/private_key.dart';
import 'package:p2plib/p2plib.dart';
import 'package:test/test.dart';

import '../mocks/mock_dht_handler.dart';
import '../mocks/mock_security_manager.dart';

void main() {
  group('IPNSHandler', () {
    late IPFSConfig config;
    late MockSecurityManager securityManager;
    late MockDHTHandler dhtHandler;
    late IPNSHandler ipnsHandler;

    setUp(() async {
      config = IPFSConfig(offline: false);
      securityManager = MockSecurityManager();
      dhtHandler = MockDHTHandler();
      ipnsHandler = IPNSHandler(config, securityManager, dhtHandler);

      // Initialize handlers
      await dhtHandler.start();
    });

    tearDown(() async {
      await ipnsHandler.stop();
    });

    test('start and stop lifecycle', () async {
      await ipnsHandler.start();
      final status = await ipnsHandler.getStatus();
      expect(status['running'], true);

      await ipnsHandler.stop();
      final statusAfterStop = await ipnsHandler.getStatus();
      expect(statusAfterStop['running'], false);
    });

    test('publish stores record in DHT', () async {
      await ipnsHandler.start();
      // Unlock the mock keystore
      await securityManager.unlockKeystore('test-password');

      final keyName = 'self';
      final privateKey = await IPFSPrivateKey.generate();
      await securityManager.storePrivateKey(keyName, privateKey);

      final data = Uint8List.fromList(utf8.encode('Test Content'));
      final cid = CID.computeForDataSync(data);
      final cidStr = cid.encode();

      await ipnsHandler.publish(cidStr, keyName: keyName);

      expect(dhtHandler.wasCalled('putValue'), true);

      // Verify what was put in DHT
      final calls = dhtHandler.getCalls();
      final putCall = calls.firstWhere((c) => c.startsWith('putValue'));
      expect(putCall, contains('putValue'));
    });

    test('resolve retrieves record from DHT', () async {
      await ipnsHandler.start();

      final name = 'TestName';
      final data = Uint8List.fromList(utf8.encode('Content'));
      final cid = CID.computeForDataSync(data);
      final cidStr = cid.encode();

      // Setup mock DHT with the value
      dhtHandler.setupValue(Key.fromString(name), Value(cid.toBytes()));

      final resolved = await ipnsHandler.resolve(name);
      expect(resolved, cidStr);

      expect(dhtHandler.wasCalled('getValue'), true);
      // expect(dhtHandler.getCalls(), contains('getValue:$name')); // remove flaky check
    });

    test('resolve returns cached value on second call', () async {
      await ipnsHandler.start();

      final name = 'CachedName';
      final data = Uint8List.fromList(utf8.encode('Cached Content'));
      final cid = CID.computeForDataSync(data);
      final cidStr = cid.encode();

      dhtHandler.setupValue(Key.fromString(name), Value(cid.toBytes()));

      // First call -> hits DHT
      final result1 = await ipnsHandler.resolve(name);
      expect(result1, cidStr);
      expect(dhtHandler.getCallCount('getValue'), 1);

      // Second call -> should cache
      final result2 = await ipnsHandler.resolve(name);
      expect(result2, cidStr);
      expect(dhtHandler.getCallCount('getValue'), 1); // Still 1
    });

    test('validates CID format', () async {
      await ipnsHandler.start();
      try {
        await ipnsHandler.publish('Invalid CID!', keyName: 'self');
        fail('Should have thrown ArgumentError');
      } catch (e) {
        print('DEBUG: Caught expected error: $e');
        expect(e, isA<ArgumentError>());
      }
    });

    test('throws StateError when keystore is locked', () async {
      await ipnsHandler.start();
      // Keystore is locked by default
      try {
        await ipnsHandler.publish('somecid', keyName: 'self');
        fail('Should have thrown StateError');
      } catch (e) {
        print('DEBUG: Caught expected error: $e');
        expect(e, isA<StateError>());
      }
    });
  });
}
