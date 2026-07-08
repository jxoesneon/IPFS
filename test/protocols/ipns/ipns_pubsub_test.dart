import 'package:cryptography/cryptography.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/pubsub_handler.dart';
import 'package:dart_ipfs/src/core/security/security_manager.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_handler.dart';
import 'package:dart_ipfs/src/protocols/ipns/ipns_handler.dart';
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

      // The legacy base64 PubSub broadcast has been removed.
      verifyNever(mockPubSubHandler.publish('/ipfs/ipns-1.0.0', any));
    });
  });
}
