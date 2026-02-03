import 'package:dart_ipfs/src/utils/generate_message_id.dart';
import 'package:test/test.dart';

void main() {
  group('MessageId Generator', () {
    test('generateMessageId returns non-empty string', () {
      final id = generateMessageId();
      expect(id, isNotEmpty);
      expect(id, isA<String>());
    });

    test('generateMessageId returns unique IDs', () {
      final id1 = generateMessageId();
      final id2 = generateMessageId();

      expect(id1, isNot(equals(id2)));
    });

    test('generateMessageId returns UUID v4 format', () {
      final id = generateMessageId();

      // UUID v4 format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
      final uuidV4Pattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        caseSensitive: false,
      );

      expect(id, matches(uuidV4Pattern));
    });

    test('multiple calls generate different IDs', () {
      final ids = List.generate(10, (_) => generateMessageId());
      final uniqueIds = ids.toSet();

      expect(uniqueIds.length, equals(10));
    });
  });
}

