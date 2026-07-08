import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/platform/platform.dart';
import 'package:test/test.dart';

void main() {
  group('IPFSConfig', () {
    test('default constructor values', () {
      final config = IPFSConfig();
      expect(config.offline, isFalse);
      expect(config.debug, isTrue);
      expect(config.logLevel, equals('info'));
      expect(config.nodeId, isNotEmpty);
      expect(config.datastorePath, equals('./ipfs_data'));
      expect(config.blockStorePath, equals('blocks'));
    });

    test('withDefaults factory', () {
      final config = IPFSConfig.withDefaults();
      expect(config.nodeId, isNotEmpty);
    });

    test('toJson / fromJson roundtrip is complete', () {
      final config = IPFSConfig(
        offline: true,
        logLevel: 'debug',
        defaultBandwidthQuota: 500,
        enableRPC: true,
        gateway: GatewayConfig(enabled: true, port: 9090),
        metrics: const MetricsConfig(
          enabled: true,
          prometheusEndpoint: '/prom',
        ),
        customConfig: {
          'plugin': {'enabled': true},
        },
        ipnsCacheSize: 500,
        enableStructuredLogging: true,
        garbageCollectionInterval: const Duration(hours: 12),
        garbageCollectionEnabled: false,
        datastorePath: '/tmp/datastore',
        keystorePath: '/tmp/keystore',
        blockStorePath: '/tmp/blocks',
        dataPath: '/tmp/data',
        maxConcurrentBitswapRequests: 20,
        enableLibp2pBridge: true,
        libp2pListenAddress: '/ip4/127.0.0.1/tcp/4002',
        nodeId: 'QmNodeId',
        libp2pIdentitySeed: Uint8List.fromList([1, 2, 3]),
      );

      final json = config.toJson();
      expect(json['keystore'], isNull); // Do not serialize key material
      expect(json['gateway'], isNotNull);
      expect(json['metrics'], isNotNull);
      expect(
        json['customConfig'],
        equals({
          'plugin': {'enabled': true},
        }),
      );

      final config2 = IPFSConfig.fromJson(json);
      expect(config2.offline, isTrue);
      expect(config2.logLevel, equals('debug'));
      expect(config2.defaultBandwidthQuota, equals(500));
      expect(config2.enableRPC, isTrue);
      expect(config2.gateway.enabled, isTrue);
      expect(config2.gateway.port, equals(9090));
      expect(config2.metrics.enabled, isTrue);
      expect(config2.metrics.prometheusEndpoint, equals('/prom'));
      expect(
        config2.customConfig,
        equals({
          'plugin': {'enabled': true},
        }),
      );
      expect(config2.ipnsCacheSize, equals(500));
      expect(config2.enableStructuredLogging, isTrue);
      expect(
        config2.garbageCollectionInterval,
        equals(const Duration(hours: 12)),
      );
      expect(config2.garbageCollectionEnabled, isFalse);
      expect(config2.datastorePath, equals('/tmp/datastore'));
      expect(config2.keystorePath, equals('/tmp/keystore'));
      expect(config2.blockStorePath, equals('/tmp/blocks'));
      expect(config2.dataPath, equals('/tmp/data'));
      expect(config2.maxConcurrentBitswapRequests, equals(20));
      expect(config2.enableLibp2pBridge, isTrue);
      expect(config2.libp2pListenAddress, equals('/ip4/127.0.0.1/tcp/4002'));
      expect(config2.nodeId, equals('QmNodeId'));
      expect(config2.libp2pIdentitySeed, equals(Uint8List.fromList([1, 2, 3])));
      expect(
        config2.keystore,
        isNotNull,
      ); // Runtime keystore is loaded separately
    });

    test('fromJson with empty Map', () {
      final config = IPFSConfig.fromJson({});
      expect(config.offline, isFalse);
      expect(config.logLevel, equals('info'));
    });

    test('fromFile - YAML support', () async {
      final yamlContent = '''
offline: true
logLevel: warning
network:
  listenAddresses:
    - /ip4/127.0.0.1/tcp/4001
''';
      const testFilePath = 'test_config.yaml';
      await getPlatform().writeString(testFilePath, yamlContent);

      try {
        final config = await IPFSConfig.fromFile(testFilePath);
        expect(config.offline, isTrue);
        expect(config.logLevel, equals('warning'));
        expect(
          config.network.listenAddresses,
          contains('/ip4/127.0.0.1/tcp/4001'),
        );
      } finally {
        if (await getPlatform().exists(testFilePath)) {
          await getPlatform().delete(testFilePath);
        }
      }
    });

    test('fromFile - JSON support', () async {
      const jsonContent = '''
{
  "offline": true,
  "logLevel": "warning",
  "enableRPC": true,
  "gateway": {"enabled": true, "port": 8080}
}
''';
      const testFilePath = 'test_config.json';
      await getPlatform().writeString(testFilePath, jsonContent);

      try {
        final config = await IPFSConfig.fromFile(testFilePath);
        expect(config.offline, isTrue);
        expect(config.logLevel, equals('warning'));
        expect(config.enableRPC, isTrue);
        expect(config.gateway.enabled, isTrue);
        expect(config.gateway.port, equals(8080));
      } finally {
        if (await getPlatform().exists(testFilePath)) {
          await getPlatform().delete(testFilePath);
        }
      }
    });

    test('customConfig storage', () {
      final config = IPFSConfig(customConfig: {'key': 'value'});
      expect(config.customConfig['key'], equals('value'));
    });
  });
}
