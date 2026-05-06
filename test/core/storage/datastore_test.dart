import 'package:test/test.dart';
import 'package:dart_ipfs/src/core/storage/datastore.dart';

void main() {
  group('Key', () {
    test('cleaning', () {
      expect(Key('abc').string, equals('/abc'));
      expect(Key('/abc/').string, equals('/abc'));
      expect(Key('').string, equals('/'));
    });

    test('child and parent', () {
      final k = Key('/abc');
      final c = k.child(Key('def'));
      expect(c.string, equals('/abc/def'));

      expect(c.parent().string, equals('/abc'));
      expect(k.parent().string, equals('/'));
    });

    test('equality and toString', () {
      final k1 = Key('/abc');
      final k2 = Key('abc');
      expect(k1, equals(k2));
      expect(k1.toString(), equals('/abc'));
      expect(k1.hashCode, equals(k2.hashCode));
    });
  });

  group('DatastoreError', () {
    test('toString', () {
      expect(DatastoreError('msg').toString(), contains('DatastoreError: msg'));
    });
  });

  group('Query', () {
    test('instantiation', () {
      final q = Query(prefix: '/a', limit: 10);
      expect(q.prefix, equals('/a'));
      expect(q.limit, equals(10));
      expect(q.keysOnly, isFalse);
    });
  });
}
