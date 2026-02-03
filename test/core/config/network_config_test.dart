import 'package:dart_ipfs/src/core/config/network_config.dart';
import 'package:test/test.dart';

void main() {
  group('NetworkConfig', () {
    test('defaults are correct', () {
      final config = NetworkConfig();
      expect(config.listenAddresses, isNotEmpty);
      expect(config.listenAddresses.first, contains('/ip4/0.0.0.0'));
      expect(config.bootstrapPeers, isNotEmpty);
      expect(config.maxConnections, 50);
      expect(config.nodeId, isNotEmpty);
      expect(config.enableNatTraversal, false);
    });

    test('fromJson parses correctly', () {
      final json = {
        'listenAddresses': ['/ip4/127.0.0.1/tcp/5001'],
        'bootstrapPeers': ['/ip4/1.2.3.4/tcp/4001'],
        'maxConnections': 100,
        'connectionTimeoutSeconds': 60,
        'enableNatTraversal': true,
        'nodeId': 'QmUnknown',
      };

      final config = NetworkConfig.fromJson(json);
      expect(config.listenAddresses, contains('/ip4/127.0.0.1/tcp/5001'));
      expect(config.bootstrapPeers, hasLength(1));
      expect(config.maxConnections, 100);
      expect(config.connectionTimeout.inSeconds, 60);
      expect(config.enableNatTraversal, true);
      expect(config.nodeId, 'QmUnknown');
    });

    test('toJson and fromJson work correctly', () {
      final config = NetworkConfig(
        listenAddresses: ['/ip4/127.0.0.1/tcp/8080'],
        maxConnections: 100,
        enableNatTraversal: true,
      );
      final json = config.toJson();
      final fromJson = NetworkConfig.fromJson(json);

      expect(fromJson.listenAddresses, ['/ip4/127.0.0.1/tcp/8080']);
      expect(fromJson.maxConnections, 100);
      expect(fromJson.enableNatTraversal, true);
      expect(json['nodeId'], isNotNull);
    });
  });
}

