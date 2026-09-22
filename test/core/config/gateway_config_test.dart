import 'package:dart_ipfs/src/core/config/gateway_config.dart';
import 'package:test/test.dart';

void main() {
  group('GatewayConfig', () {
    test('default constructor', () {
      const config = GatewayConfig();
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
      const config = GatewayConfig(
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

    test('corsOrigins defaults to localhost', () {
      const config = GatewayConfig();
      expect(
        config.corsOrigins,
        equals(['http://localhost', 'http://127.0.0.1']),
      );
    });

    test('corsOrigins round-trips through json', () {
      const config = GatewayConfig(corsOrigins: ['*', 'http://example.com']);
      final json = config.toJson();
      expect(json['corsOrigins'], equals(['*', 'http://example.com']));

      final parsed = GatewayConfig.fromJson(json);
      expect(parsed.corsOrigins, equals(['*', 'http://example.com']));
    });

    test('trustForwardedHeaders defaults to false and round-trips', () {
      const config = GatewayConfig();
      expect(config.trustForwardedHeaders, isFalse);
      expect(config.toJson()['trustForwardedHeaders'], isFalse);

      final parsed = GatewayConfig.fromJson({'trustForwardedHeaders': true});
      expect(parsed.trustForwardedHeaders, isTrue);
      expect(parsed.toJson()['trustForwardedHeaders'], isTrue);
    });

    test('maxFileResponseBytes defaults to 512 MiB and round-trips', () {
      const config = GatewayConfig();
      expect(config.maxFileResponseBytes, equals(512 * 1024 * 1024));
      expect(
        config.toJson()['maxFileResponseBytes'],
        equals(512 * 1024 * 1024),
      );

      final parsed = GatewayConfig.fromJson({'maxFileResponseBytes': 4096});
      expect(parsed.maxFileResponseBytes, equals(4096));
      expect(parsed.toJson()['maxFileResponseBytes'], equals(4096));
    });
  });
}
