import 'package:dart_ipfs/src/core/data_structures/metadata.dart';
import 'package:test/test.dart';

void main() {
  group('IPLDMetadata', () {
    test('creates metadata with required size', () {
      final metadata = IPLDMetadata(size: 1024);

      expect(metadata.size, equals(1024));
      expect(metadata.properties, isEmpty);
      expect(metadata.lastModified, isNull);
      expect(metadata.contentType, isNull);
    });

    test('creates metadata with all optional fields', () {
      final now = DateTime.now();
      final metadata = IPLDMetadata(
        size: 2048,
        properties: {'author': 'test', 'version': '1.0'},
        lastModified: now,
        contentType: 'application/json',
      );

      expect(metadata.size, equals(2048));
      expect(metadata.properties['author'], equals('test'));
      expect(metadata.properties['version'], equals('1.0'));
      expect(metadata.lastModified, equals(now));
      expect(metadata.contentType, equals('application/json'));
    });

    test('toJson() converts metadata to map', () {
      final now = DateTime(2024, 1, 15, 12, 30);
      final metadata = IPLDMetadata(
        size: 512,
        properties: {'key': 'value'},
        lastModified: now,
        contentType: 'text/plain',
      );

      final json = metadata.toJson();
      expect(json['size'], equals(512));
      expect(json['properties'], equals({'key': 'value'}));
      expect(json['lastModified'], equals(now.toIso8601String()));
      expect(json['contentType'], equals('text/plain'));
    });

    test('toJson() handles null optional fields', () {
      final metadata = IPLDMetadata(size: 100);

      final json = metadata.toJson();
      expect(json['size'], equals(100));
      expect(json['lastModified'], isNull);
      expect(json['contentType'], isNull);
      expect(json['properties'], isEmpty);
    });
  });
}
