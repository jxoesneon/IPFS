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
        'bootstrapPeers': [],
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
  });

  group('ProtocolConfig', () {
    test('constructor initializes correctly', () {
      final config = ProtocolConfig(
        protocolId: '/test/protocol',
        messageTimeout: Duration(seconds: 15),
        maxRetries: 5,
      );

      expect(config.protocolId, '/test/protocol');
      expect(config.messageTimeout.inSeconds, 15);
      expect(config.maxRetries, 5);
    });

    test('constructor uses default values', () {
      final config = ProtocolConfig(protocolId: '/test/protocol');

      expect(config.protocolId, '/test/protocol');
      expect(config.messageTimeout.inSeconds, 10);
      expect(config.maxRetries, 3);
    });

    test('constructor with only required parameters', () {
      final config = ProtocolConfig(protocolId: '/ipfs/bitswap/1.2.0');

      expect(config.protocolId, '/ipfs/bitswap/1.2.0');
      expect(config.messageTimeout, isNotNull);
      expect(config.maxRetries, isNotNull);
    });

    test('constructor with zero maxRetries', () {
      final config = ProtocolConfig(
        protocolId: '/test/protocol',
        maxRetries: 0,
      );

      expect(config.maxRetries, 0);
    });
  });
}
