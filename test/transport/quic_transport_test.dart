import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/transport/libp2p_router.dart';
import 'package:ipfs_libp2p/dart_libp2p.dart' as libp2p;
import 'package:ipfs_libp2p/p2p/host/resource_manager/limiter.dart';
import 'package:ipfs_libp2p/p2p/host/resource_manager/resource_manager_impl.dart';
import 'package:ipfs_libp2p/p2p/transport/tcp_transport.dart';
import 'package:logging/logging.dart' as logging;
import 'package:test/test.dart';

/// A minimal transport that advertises QUIC support for testing address
/// synthesis and [Libp2pRouter.supportsQuic] with a deterministic factory.
class _FakeQuicTransport extends TCPTransport {
  _FakeQuicTransport()
    : super(resourceManager: ResourceManagerImpl(limiter: FixedLimiter()));

  @override
  List<String> get protocols => ['/ip4/udp/quic-v1', '/ip6/udp/quic-v1'];

  @override
  bool canDial(libp2p.MultiAddr addr) => _isQuic(addr);

  @override
  bool canListen(libp2p.MultiAddr addr) => _isQuic(addr);

  static bool _isQuic(libp2p.MultiAddr addr) =>
      addr.hasProtocol('udp') && addr.hasProtocol('quic-v1');
}

void main() {
  group('QUIC transport', () {
    setUpAll(() {
      logging.hierarchicalLoggingEnabled = true;
    });

    tearDown(() {
      Libp2pRouter.setQuicTransportFactoryForTesting(null);
    });

    test('NetworkConfig QUIC defaults are correct', () {
      final config = NetworkConfig();
      expect(config.enableQuic, isFalse);
      expect(config.quicListenPort, 4002);
      expect(config.quicMaxStreams, 100);
      expect(config.preferQuic, isFalse);
    });

    test('NetworkConfig parses QUIC fields from JSON', () {
      final config = NetworkConfig.fromJson({
        'listenAddresses': ['/ip4/127.0.0.1/tcp/0'],
        'enableQuic': true,
        'quicListenPort': 5001,
        'quicMaxStreams': 200,
        'preferQuic': true,
      });

      expect(config.enableQuic, isTrue);
      expect(config.quicListenPort, 5001);
      expect(config.quicMaxStreams, 200);
      expect(config.preferQuic, isTrue);
    });

    test('NetworkConfig serializes QUIC fields to JSON', () {
      final config = NetworkConfig(
        listenAddresses: ['/ip4/127.0.0.1/tcp/0'],
        enableQuic: true,
        quicListenPort: 5001,
        quicMaxStreams: 200,
        preferQuic: true,
      );
      final json = config.toJson();

      expect(json['enableQuic'], isTrue);
      expect(json['quicListenPort'], 5001);
      expect(json['quicMaxStreams'], 200);
      expect(json['preferQuic'], isTrue);
    });

    test('supportsQuic is true when QUIC is enabled and available', () async {
      final config = IPFSConfig(
        network: NetworkConfig(
          listenAddresses: ['/ip4/127.0.0.1/tcp/0'],
          enableQuic: true,
        ),
      );
      final router = Libp2pRouter(config);
      await router.initialize();
      addTearDown(() => router.stop());

      expect(router.supportsQuic, isTrue);
    });

    test('supportsQuic is false when enableQuic is false', () async {
      final config = IPFSConfig(
        network: NetworkConfig(
          listenAddresses: ['/ip4/127.0.0.1/tcp/0'],
          enableQuic: false,
        ),
      );
      final router = Libp2pRouter(config);
      await router.initialize();
      addTearDown(() => router.stop());

      expect(router.supportsQuic, isFalse);
    });

    test(
      'does not log fallback warning when QUIC is enabled and available',
      () async {
        final logs = <String>[];
        final subscription = logging.Logger('Libp2pRouter').onRecord.listen((
          record,
        ) {
          logs.add(record.message);
        });
        addTearDown(() => subscription.cancel());

        final config = IPFSConfig(
          network: NetworkConfig(
            listenAddresses: ['/ip4/127.0.0.1/tcp/0'],
            enableQuic: true,
            bootstrapPeers: [],
          ),
        );
        final router = Libp2pRouter(config);
        await router.start();
        addTearDown(() => router.stop());

        expect(router.supportsQuic, isTrue);
        expect(
          logs.any(
            (m) => m.contains('QUIC enabled') && m.contains('falling back'),
          ),
          isFalse,
        );
      },
    );

    test('does not log fallback warning when QUIC is disabled', () async {
      final logs = <String>[];
      final subscription = logging.Logger('Libp2pRouter').onRecord.listen((
        record,
      ) {
        logs.add(record.message);
      });
      addTearDown(() => subscription.cancel());

      final config = IPFSConfig(
        network: NetworkConfig(
          listenAddresses: ['/ip4/127.0.0.1/tcp/0'],
          enableQuic: false,
          bootstrapPeers: [],
        ),
      );
      final router = Libp2pRouter(config);
      await router.start();
      addTearDown(() => router.stop());

      expect(router.supportsQuic, isFalse);
      expect(
        logs.any(
          (m) => m.contains('QUIC enabled') && m.contains('falling back'),
        ),
        isFalse,
      );
    });

    test('synthesizes QUIC listen addresses when QUIC is available', () async {
      Libp2pRouter.setQuicTransportFactoryForTesting(
        () => _FakeQuicTransport(),
      );

      final config = IPFSConfig(
        network: NetworkConfig(
          listenAddresses: ['/ip4/127.0.0.1/tcp/0'],
          enableQuic: true,
          quicListenPort: 4002,
        ),
      );
      final router = Libp2pRouter(config);
      await router.initialize();
      addTearDown(() => router.stop());

      expect(router.supportsQuic, isTrue);
      expect(
        router.listeningAddresses,
        contains('/ip4/0.0.0.0/udp/4002/quic-v1'),
      );
      expect(router.listeningAddresses, contains('/ip6/::/udp/4002/quic-v1'));
    });

    test(
      'does not synthesize QUIC listen addresses when QUIC is disabled',
      () async {
        final config = IPFSConfig(
          network: NetworkConfig(
            listenAddresses: ['/ip4/127.0.0.1/tcp/0'],
            enableQuic: false,
          ),
        );
        final router = Libp2pRouter(config);
        await router.initialize();
        addTearDown(() => router.stop());

        expect(router.supportsQuic, isFalse);
        expect(
          router.listeningAddresses,
          isNot(contains('/ip4/0.0.0.0/udp/4002/quic-v1')),
        );
        expect(
          router.listeningAddresses,
          isNot(contains('/ip6/::/udp/4002/quic-v1')),
        );
      },
    );
  });
}
