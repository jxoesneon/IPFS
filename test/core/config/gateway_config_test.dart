import 'package:test/test.dart';
import 'package:dart_ipfs/src/core/config/gateway_config.dart';

void main() {
  group('GatewayConfig', () {
    test('default constructor', () {
      final config = GatewayConfig();
      expect(config.enabled, isFalse);
      expect(config.port, equals(8080));
      expect(config.address, equals('0.0.0.0'));
      expect(config.writable, isFalse);
      expect(config.enableCache, isTrue);
      expect(config.cacheSize, equals(104857600));
    });

    test('fromJson', () {
      final json = {
        'enabled': true,
        'port': 9090,
        'address': '127.0.0.1',
        'writable': true,
        'enableCache': false,
        'cacheSize': 1000,
      };
      final config = GatewayConfig.fromJson(json);
      expect(config.enabled, isTrue);
      expect(config.port, equals(9090));
      expect(config.address, equals('127.0.0.1'));
      expect(config.writable, isTrue);
      expect(config.enableCache, isFalse);
      expect(config.cacheSize, equals(1000));
    });

    test('toJson', () {
      final config = GatewayConfig(
        enabled: true,
        port: 9090,
        address: '127.0.0.1',
        writable: true,
        enableCache: false,
        cacheSize: 1000,
      );
      final json = config.toJson();
      expect(json['enabled'], isTrue);
      expect(json['port'], equals(9090));
      expect(json['address'], equals('127.0.0.1'));
      expect(json['writable'], isTrue);
      expect(json['enableCache'], isFalse);
      expect(json['cacheSize'], equals(1000));
    });
  });
}
