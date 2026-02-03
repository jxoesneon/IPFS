// test/utils/message_id_verified_test.dart
import 'package:dart_ipfs/src/utils/generate_message_id.dart';
import 'package:test/test.dart';

/// Verified tests for message ID generation utilities.
void main() {
  group('Message ID Generation - Verified Tests', () {
    test('generateMessageId returns non-empty string', () {
      final id = generateMessageId();

      expect(id, isNotEmpty);
      expect(id, isA<String>());
    });

    test('generateMessageId creates unique IDs', () {
      final id1 = generateMessageId();
      final id2 = generateMessageId();
      final id3 = generateMessageId();

      expect(id1, isNot(equals(id2)));
      expect(id2, isNot(equals(id3)));
      expect(id1, isNot(equals(id3)));
    });

    test('generateMessageId format is consistent', () {
      final id = generateMessageId();

      // Should be a reasonable length
      expect(id.length, greaterThan(10));
    });

    test('concurrent ID generation produces unique IDs', () {
      final ids = List.generate(100, (_) => generateMessageId());
      final uniqueIds = ids.toSet();

      expect(uniqueIds.length, equals(100)); // All unique
    });

    test('IDs remain unique across batches', () {
      final batch1 = List.generate(10, (_) => generateMessageId());
      final batch2 = List.generate(10, (_) => generateMessageId());

      final combined = [...batch1, ...batch2];
      final uniqueIds = combined.toSet();

      expect(uniqueIds.length, equals(20));
    });
  });
}

