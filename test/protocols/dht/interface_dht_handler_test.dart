import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:dart_ipfs/src/protocols/dht/interface_dht_handler.dart';

void main() {
  group('Key', () {
    test('constructor creates key from bytes', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final key = Key(bytes);
      expect(key.bytes, equals(bytes));
    });

    test('fromString creates key from string', () {
      final key = Key.fromString('hello');
      expect(key.bytes, isNotEmpty);
    });

    test('fromBytes creates key from bytes', () {
      final bytes = Uint8List.fromList([4, 5, 6]);
      final key = Key.fromBytes(bytes);
      expect(key.bytes, equals(bytes));
    });

    test('toString returns base58 encoded string', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final key = Key(bytes);
      final str = key.toString();
      expect(str, isNotEmpty);
      expect(str, isA<String>());
    });
  });

  group('Value', () {
    test('constructor creates value from bytes', () {
      final bytes = Uint8List.fromList([7, 8, 9]);
      final value = Value(bytes);
      expect(value.bytes, equals(bytes));
    });

    test('fromString creates value from string', () {
      final value = Value.fromString('world');
      expect(value.bytes, isNotEmpty);
    });

    test('fromBytes creates value from bytes', () {
      final bytes = Uint8List.fromList([10, 11, 12]);
      final value = Value.fromBytes(bytes);
      expect(value.bytes, equals(bytes));
    });

    test('toString returns decoded string', () {
      final value = Value.fromString('test');
      final str = value.toString();
      expect(str, equals('test'));
    });
  });
}
