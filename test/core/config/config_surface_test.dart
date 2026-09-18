import 'package:dart_ipfs/src/core/builders/ipfs_node_builder.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/transport/libp2p_router.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:logging/logging.dart' as logging;
import 'package:test/test.dart';

void main() {
  group('logLevel', () {
    test('setGlobalLevel applies a known level to the root logger', () {
      Logger.setGlobalLevel('error');
      expect(logging.Logger.root.level, equals(logging.Level.SEVERE));

      Logger.setGlobalLevel('debug');
      expect(logging.Logger.root.level, equals(logging.Level.FINE));

      Logger.setGlobalLevel('info');
      expect(logging.Logger.root.level, equals(logging.Level.INFO));
    });

    test('setGlobalLevel falls back to info for unknown levels', () {
      Logger.setGlobalLevel('not-a-level');
      expect(logging.Logger.root.level, equals(logging.Level.INFO));
    });
  });

  group('fromJson default parity', () {
    test('debug and verboseLogging match constructor defaults', () {
      final config = IPFSConfig.fromJson(const {});
      expect(config.debug, isTrue);
      expect(config.verboseLogging, isTrue);
    });

    test('round-trip preserves debug and verboseLogging', () {
      final config = IPFSConfig.fromJson(IPFSConfig().toJson());
      expect(config.debug, isTrue);
      expect(config.verboseLogging, isTrue);
    });
  });

  group('enableMetrics', () {
    test('record methods are inert when enableMetrics is false', () async {
      final collector = MetricsCollector(IPFSConfig(enableMetrics: false));
      collector.recordMessageSent('bitswap', 128);
      collector.recordPeerConnected();

      expect(collector.getMessagesSent('bitswap'), equals(0));
      final status = await collector.getStatus();
      expect(status['enabled'], isFalse);
    });

    test('record methods work when enableMetrics is true', () async {
      final collector = MetricsCollector(IPFSConfig(enableMetrics: true));
      collector.recordMessageSent('bitswap', 128);

      expect(collector.getMessagesSent('bitswap'), equals(1));
      final status = await collector.getStatus();
      expect(status['enabled'], isTrue);
    });
  });

  group('feature flag gating', () {
    test('disabled services are not registered on the node', () async {
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final config = IPFSConfig(
        datastorePath: './test_tmp/config_surface_ds_$stamp',
        blockStorePath: './test_tmp/config_surface_blocks_$stamp',
        keystorePath: './test_tmp/config_surface_keys_$stamp',
        enableContentRouting: false,
        enableDNSLinkResolution: false,
        enableGraphsync: false,
      );

      final node = await IPFSNodeBuilder(config).build();
      try {
        final status = await node.getHealthStatus();
        final services = status['services'] as Map<String, dynamic>;
        expect(services['routing']['status'], equals('disabled'));
        expect(services['dnslink']['status'], equals('disabled'));
        expect(services['graphsync']['status'], equals('disabled'));
      } finally {
        await node.stop();
      }
    });
  });

  group('libp2pListenAddress', () {
    test('is honored when network.listenAddresses is empty', () async {
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final router = Libp2pRouter(
        IPFSConfig(
          dataPath: './test_tmp/config_surface_router_$stamp',
          datastorePath: './test_tmp/config_surface_router_ds_$stamp',
          network: NetworkConfig(listenAddresses: const []),
          libp2pListenAddress: '/ip4/127.0.0.1/tcp/14555',
        ),
      );

      // listeningAddresses falls back to the configured listen addresses
      // before start, so the legacy single-address surface is observable
      // without opening sockets.
      expect(
        router.listeningAddresses.any((a) => a.contains('/tcp/14555')),
        isTrue,
        reason: 'router should listen on the libp2pListenAddress fallback',
      );
    });
  });
}
