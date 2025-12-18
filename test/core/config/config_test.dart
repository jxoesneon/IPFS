import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/config/metrics_config.dart';
import 'package:dart_ipfs/src/core/config/storage_config.dart';
// import 'package:dart_ipfs/src/core/config/dht_config.dart';
// import 'package:dart_ipfs/src/core/config/security_config.dart';
import 'package:test/test.dart';

void main() {
  group('MetricsConfig', () {
    test('defaults', () {
      final config = const MetricsConfig();
      expect(config.enabled, isTrue);
      expect(config.collectionIntervalSeconds, 60);
      expect(config.prometheusEndpoint, '/metrics');
    });

    test('fromJson/toJson', () {
      final json = {
        'enabled': false,
        'collectionIntervalSeconds': 30,
        'collectSystemMetrics': false,
        'collectNetworkMetrics': false,
        'collectStorageMetrics': false,
        'enablePrometheusExport': true,
        'prometheusEndpoint': '/custom',
      };
      final config = MetricsConfig.fromJson(json);
      expect(config.enabled, isFalse);
      expect(config.collectionIntervalSeconds, 30);
      expect(config.prometheusEndpoint, '/custom');
      expect(config.toJson(), json);
    });
  });

  group('StorageConfig', () {
    test('defaults', () {
      final config = const StorageConfig();
      expect(config.baseDir, '.ipfs');
      expect(config.maxBlockSize, 1024 * 1024 * 2);
    });

    test('helpers', () {
      final config = const StorageConfig(baseDir: '/tmp');
      expect(config.blockPath, '/tmp/blocks');
      expect(config.datastorePath, '/tmp/datastore');
      expect(config.keysPath, '/tmp/keys');
    });

    test('fromJson/toJson', () {
      final json = {
        'baseDir': '/data',
        'maxStorageSize': 100,
        'blocksDir': 'b',
        'datastoreDir': 'd',
        'keysDir': 'k',
        'enableGC': false,
        'gcIntervalSeconds': 60,
        'maxBlockSize': 512,
      };
      final config = StorageConfig.fromJson(json);
      expect(config.baseDir, '/data');
      expect(config.gcInterval.inSeconds, 60);
      expect(config.toJson(), json);
    });
  });

  group('NetworkConfig', () {
    test('defaults', () {
      final config = const NetworkConfig();
      expect(config.maxConnections, 50);
      expect(config.listenAddresses, contains('/ip4/0.0.0.0/tcp/4001'));
    });

    test('fromJson/toJson', () {
      final json = {
        'listenAddresses': ['/ip4/127.0.0.1/tcp/4001'],
        'bootstrapPeers': ['/ip4/1.2.3.4/tcp/4001/p2p/QmPeer'],
        'maxConnections': 100,
        'connectionTimeoutSeconds': 10,
        'delegatedRoutingEndpoint': 'https://example.com',
      };
      final config = NetworkConfig.fromJson(json);
      expect(config.maxConnections, 100);
      expect(config.bootstrapPeers, hasLength(1));
      expect(config.toJson(), json);
    });
  });

  group('IPFSConfig', () {
    test('defaults', () {
      final config = IPFSConfig();
      expect(config.offline, isFalse);
      expect(config.debug, isTrue); // Default in ctor
      expect(config.nodeId, isNotEmpty);
    });

    test('withDefaults factory', () {
      final config = IPFSConfig.withDefaults();
      expect(config.nodeId, isNotEmpty);
    });

    test('fromJson/toJson', () {
      final json = {
        'offline': true,
        'debug': false,
        'verboseLogging': true,
        'enablePubSub': false,
        'enableDHT': false,
        'enableCircuitRelay': false,
        'enableContentRouting': false,
        'enableDNSLinkResolution': false,
        'enableIPLD': false,
        'enableGraphsync': false,
        'enableMetrics': false,
        'enableLogging': false,
        'logLevel': 'debug',
        'enableQuotaManagement': false,
        'defaultBandwidthQuota': 500,
        // nested configs
        'network': <String, dynamic>{},
        'dht': <String, dynamic>{},
        'storage': <String, dynamic>{},
        'security': <String, dynamic>{},
      };

      // Note: toJson doesn't include potentially everything or key order might differ.
      // We check specific fields.
      final config = IPFSConfig.fromJson(json);
      expect(config.offline, isTrue);
      expect(config.debug, isFalse);
      expect(
        config.metrics.enabled,
        isTrue,
      ); // Default of nested if empty map passed

      final output = config.toJson();
      expect(output['offline'], isTrue);
      expect(output['network'], isNotNull);
    });
  });
}
