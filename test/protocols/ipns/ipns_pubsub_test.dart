import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/pubsub_handler.dart';
import 'package:dart_ipfs/src/core/security/security_manager.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_handler.dart';
import 'package:dart_ipfs/src/protocols/ipns/ipns_handler.dart';
import 'package:dart_ipfs/src/protocols/ipns/ipns_record.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

// Generate mocks
@GenerateMocks([SecurityManager, DHTHandler, PubSubHandler])
import 'ipns_pubsub_test.mocks.dart';

void main() {
  group('IPNS over PubSub', () {
    late IPNSHandler ipnsHandler;
    late MockSecurityManager mockSecurityManager;
    late MockDHTHandler mockDHTHandler;
    late MockPubSubHandler mockPubSubHandler;
    late IPFSConfig config;

    setUp(() async {
      mockSecurityManager = MockSecurityManager();
      mockDHTHandler = MockDHTHandler();
      mockPubSubHandler = MockPubSubHandler();
      config = IPFSConfig(offline: false);

      ipnsHandler = IPNSHandler(
        config,
        mockSecurityManager,
        mockDHTHandler,
        mockPubSubHandler,
      );
    });

    test('start() subscribes to PubSub topic when enabled', () async {
      ipnsHandler = IPNSHandler(
        IPFSConfig(offline: false, enableIpnsPubSub: true),
        mockSecurityManager,
        mockDHTHandler,
        mockPubSubHandler,
      );
      when(mockDHTHandler.start()).thenAnswer((_) async {});
      when(mockPubSubHandler.subscribe(any)).thenAnswer((_) async {});

      await ipnsHandler.start();

      verify(mockPubSubHandler.subscribe('/ipfs/ipns-1.0.0')).called(1);
      verify(mockPubSubHandler.onMessage('/ipfs/ipns-1.0.0', any)).called(1);
    });

    test('publish() stores signed record via DHT', () async {
      // Setup successful keystore access
      when(mockSecurityManager.isKeystoreUnlocked).thenReturn(true);

      final algorithm = Ed25519();
      final keyPair = await algorithm.newKeyPair();
      when(
        mockSecurityManager.getSecureKey(any),
      ).thenAnswer((_) async => keyPair);

      // Setup DHT put
      when(mockDHTHandler.putValue(any, any)).thenAnswer((_) async {});

      // Setup PubSub publish
      when(mockPubSubHandler.publish(any, any)).thenAnswer((_) async {});

      // Create a dummy CID
      final validCid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';

      await ipnsHandler.start();
      await ipnsHandler.publish(validCid, keyName: 'self');

      // DHT store should be invoked via the legacy putValue fallback.
      verify(mockDHTHandler.putValue(any, any)).called(1);

      // PubSub notifications are disabled by default: nothing is announced.
      verifyNever(mockPubSubHandler.publish('/ipfs/ipns-1.0.0', any));
    });

    test(
      'publish() announces the signed record over PubSub when enabled',
      () async {
        ipnsHandler = IPNSHandler(
          IPFSConfig(offline: false, enableIpnsPubSub: true),
          mockSecurityManager,
          mockDHTHandler,
          mockPubSubHandler,
        );
        when(mockSecurityManager.isKeystoreUnlocked).thenReturn(true);
        final keyPair = await Ed25519().newKeyPair();
        when(
          mockSecurityManager.getSecureKey(any),
        ).thenAnswer((_) async => keyPair);
        when(mockDHTHandler.start()).thenAnswer((_) async {});
        when(mockDHTHandler.putValue(any, any)).thenAnswer((_) async {});
        when(mockPubSubHandler.subscribe(any)).thenAnswer((_) async {});
        when(mockPubSubHandler.publish(any, any)).thenAnswer((_) async {});

        const cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
        await ipnsHandler.start();
        await ipnsHandler.publish(cid, keyName: 'self');

        final announced =
            verify(
                  mockPubSubHandler.publish(
                    IPNSHandler.ipnsPubSubTopic,
                    captureAny,
                  ),
                ).captured.single
                as String;

        // The announcement is a base64-encoded signed IPNS record.
        final record = IPNSRecord.decode(base64Decode(announced));
        expect(record.isSigned, isTrue);
        expect(record.valueCID?.encode(), cid);
      },
    );

    test('incoming PubSub record refreshes the local IPNS cache', () async {
      ipnsHandler = IPNSHandler(
        IPFSConfig(offline: false, enableIpnsPubSub: true),
        mockSecurityManager,
        mockDHTHandler,
        mockPubSubHandler,
      );
      when(mockDHTHandler.start()).thenAnswer((_) async {});
      when(mockPubSubHandler.subscribe(any)).thenAnswer((_) async {});

      await ipnsHandler.start();

      final listener =
          verify(
                mockPubSubHandler.onMessage(
                  IPNSHandler.ipnsPubSubTopic,
                  captureAny,
                ),
              ).captured.single
              as void Function(String);

      const cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      final record = await IPNSRecord.create(
        value: CID.decode(cid),
        keyPair: await Ed25519().newKeyPair(),
        sequence: 1,
      );

      // Malformed payloads are dropped without crashing the listener.
      listener('not base64 at all!!!');
      listener(base64Encode(utf8.encode('definitely not a record')));

      // A valid signed record announced by a peer updates the cache.
      listener(base64Encode(record.toCBOR()));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Resolution is served from the refreshed cache, with no DHT lookup.
      expect(await ipnsHandler.resolve(record.name), cid);
      verifyNever(mockDHTHandler.getValue(any));
    });

    test('pubsub listener drops invalid and unverifiable records', () async {
      ipnsHandler = IPNSHandler(
        IPFSConfig(offline: false, enableIpnsPubSub: true),
        mockSecurityManager,
        mockDHTHandler,
        mockPubSubHandler,
      );
      when(mockDHTHandler.start()).thenAnswer((_) async {});
      when(mockPubSubHandler.subscribe(any)).thenAnswer((_) async {});
      await ipnsHandler.start();

      final listener =
          verify(
                mockPubSubHandler.onMessage(
                  IPNSHandler.ipnsPubSubTopic,
                  captureAny,
                ),
              ).captured.single
              as void Function(String);

      final value = utf8.encode(
        '/ipfs/QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn',
      );

      // Expired record: validation rejects it before any cache update.
      final expired = IPNSRecord.internal(
        value: value,
        validity: DateTime.now().subtract(const Duration(hours: 1)),
        publicKey: Uint8List(32),
        signature: Uint8List(64),
      );
      listener(base64Encode(expired.toCBOR()));

      // Signed but undecodable key: verify() throws a non-validation
      // error which must be dropped rather than escape the listener.
      final unverifiable = IPNSRecord.internal(
        value: value,
        validity: DateTime.now().add(const Duration(hours: 1)),
        publicKey: Uint8List(10),
        signature: Uint8List(64),
      );
      listener(base64Encode(unverifiable.toCBOR()));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      verifyNever(mockDHTHandler.getValue(any));
    });

    test('pubsub listener ignores stale sequence numbers', () async {
      ipnsHandler = IPNSHandler(
        IPFSConfig(offline: false, enableIpnsPubSub: true),
        mockSecurityManager,
        mockDHTHandler,
        mockPubSubHandler,
      );
      when(mockDHTHandler.start()).thenAnswer((_) async {});
      when(mockPubSubHandler.subscribe(any)).thenAnswer((_) async {});
      await ipnsHandler.start();

      final listener =
          verify(
                mockPubSubHandler.onMessage(
                  IPNSHandler.ipnsPubSubTopic,
                  captureAny,
                ),
              ).captured.single
              as void Function(String);

      const cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      final keyPair = await Ed25519().newKeyPair();
      final fresh = await IPNSRecord.create(
        value: CID.decode(cid),
        keyPair: keyPair,
        sequence: 5,
      );
      final stale = await IPNSRecord.create(
        value: CID.decode(cid),
        keyPair: keyPair,
        sequence: 3,
      );

      listener(base64Encode(fresh.toCBOR()));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // The lower-sequence announcement must not replace the cached record.
      listener(base64Encode(stale.toCBOR()));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(await ipnsHandler.resolve(fresh.name), cid);
    });

    test('publish still succeeds when the pubsub announce fails', () async {
      ipnsHandler = IPNSHandler(
        IPFSConfig(offline: false, enableIpnsPubSub: true),
        mockSecurityManager,
        mockDHTHandler,
        mockPubSubHandler,
      );
      when(mockSecurityManager.isKeystoreUnlocked).thenReturn(true);
      final keyPair = await Ed25519().newKeyPair();
      when(
        mockSecurityManager.getSecureKey(any),
      ).thenAnswer((_) async => keyPair);
      when(mockDHTHandler.start()).thenAnswer((_) async {});
      when(mockDHTHandler.putValue(any, any)).thenAnswer((_) async {});
      when(mockPubSubHandler.subscribe(any)).thenAnswer((_) async {});
      when(
        mockPubSubHandler.publish(any, any),
      ).thenThrow(Exception('pubsub down'));

      const cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      await ipnsHandler.start();

      // The announcement failure is logged and swallowed: the record was
      // already stored in the DHT, so publish() must not rethrow.
      await ipnsHandler.publish(cid, keyName: 'self');
      verify(mockDHTHandler.putValue(any, any)).called(1);
      verify(mockPubSubHandler.publish(IPNSHandler.ipnsPubSubTopic, any));
    });
  });
}
