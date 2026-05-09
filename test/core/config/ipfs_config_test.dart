import 'dart:convert';
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

    test('toJson / fromJson roundrip', () {
      final config = IPFSConfig(
        offline: true,
        logLevel: 'debug',
        defaultBandwidthQuota: 500,
      );

      final json = config.toJson();
      expect(json['offline'], isTrue);
      expect(json['logLevel'], equals('debug'));
      expect(json['defaultBandwidthQuota'], equals(500));

      final config2 = IPFSConfig.fromJson(json);
      expect(config2.offline, isTrue);
      expect(config2.logLevel, equals('debug'));
      expect(config2.defaultBandwidthQuota, equals(500));
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

    test('customConfig storage', () {
      final config = IPFSConfig(customConfig: {'key': 'value'});
      expect(config.customConfig['key'], equals('value'));
    });
  });
}
