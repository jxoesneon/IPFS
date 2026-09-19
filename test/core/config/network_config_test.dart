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

    test('withGeneratedId factory creates config with generated ID', () {
      final config = NetworkConfig.withGeneratedId(
        listenAddresses: ['/ip4/127.0.0.1/tcp/9000'],
        maxConnections: 75,
      );
      expect(config.nodeId, isNotEmpty);
      expect(config.nodeId.length, greaterThan(10));
      expect(config.listenAddresses, ['/ip4/127.0.0.1/tcp/9000']);
      expect(config.maxConnections, 75);
    });

    test('fromJson with enableMDNS and delegatedRoutingEndpoint', () {
      final json = {
        'listenAddresses': ['/ip4/0.0.0.0/tcp/4001'],
        'bootstrapPeers': <String>[],
        'maxConnections': 50,
        'enableMDNS': false,
        'delegatedRoutingEndpoint': 'https://example.com/routing',
      };

      final config = NetworkConfig.fromJson(json);
      expect(config.enableMDNS, isFalse);
      expect(config.delegatedRoutingEndpoint, 'https://example.com/routing');
    });

    test('toJson includes all fields', () {
      final config = NetworkConfig(
        listenAddresses: ['/ip4/0.0.0.0/tcp/4001'],
        bootstrapPeers: ['/ip4/1.2.3.4/tcp/4001'],
        maxConnections: 100,
        enableNatTraversal: true,
        enableMDNS: false,
        delegatedRoutingEndpoint: 'https://example.com/routing',
      );

      final json = config.toJson();
      expect(json['listenAddresses'], isNotEmpty);
      expect(json['bootstrapPeers'], isNotEmpty);
      expect(json['maxConnections'], 100);
      expect(json['enableNatTraversal'], true);
      expect(json['enableMDNS'], false);
      expect(json['delegatedRoutingEndpoint'], 'https://example.com/routing');
    });

    test('fromJson keeps constructor defaults for absent keys', () {
      final config = NetworkConfig.fromJson(const {});

      // Absent keys must fall back to the constructor defaults; a partial
      // JSON config previously dropped all bootstrap peers and listen
      // addresses.
      expect(config.listenAddresses, NetworkConfig.defaultListenAddresses);
      expect(config.bootstrapPeers, NetworkConfig.defaultBootstrapPeers);
    });

    test('fromJson preserves explicitly empty lists', () {
      final config = NetworkConfig.fromJson(const {
        'listenAddresses': <String>[],
        'bootstrapPeers': <String>[],
      });

      expect(config.listenAddresses, isEmpty);
      expect(config.bootstrapPeers, isEmpty);
    });
  });
}
