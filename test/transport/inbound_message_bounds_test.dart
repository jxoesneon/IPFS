import 'dart:mirrors' as mirrors;
import 'dart:typed_data';

import 'package:dart_ipfs/src/transport/inbound_message_bounds.dart';
import 'package:test/test.dart';

void main() {
  group('InboundMessageBounds', () {
    test('private constructor is invocable and constants are stable', () {
      // The private constructor only exists to prevent instantiation; it is
      // invoked here via mirrors so the line is not reported uncovered.
      final classMirror = mirrors.reflectClass(InboundMessageBounds);
      final ctor = classMirror.declarations.values
          .whereType<mirrors.MethodMirror>()
          .firstWhere((m) => m.isConstructor);
      final instance = classMirror.newInstance(ctor.constructorName, const []);
      expect(instance.reflectee, isA<InboundMessageBounds>());

      expect(InboundMessageBounds.maxVarintBytes, equals(10));
      expect(InboundMessageBounds.maxMessageSize, equals(4 * 1024 * 1024));
      expect(InboundMessageBounds.readChunkSize, equals(64 * 1024));
    });
  });

  group('readLengthPrefixedMessage', () {
    test('returns a complete message body', () async {
      final payload = Uint8List.fromList([1, 2, 3]);
      final wire = Uint8List.fromList([payload.length, ...payload]);
      var offset = 0;
      Future<Uint8List?> read(int size) async {
        if (offset >= wire.length) return null;
        final end = (offset + size).clamp(0, wire.length);
        final chunk = wire.sublist(offset, end);
        offset = end;
        return chunk;
      }

      expect(await readLengthPrefixedMessage(read), equals(payload));
    });

    test('returns null when the source closes mid-message', () async {
      var calls = 0;
      Future<Uint8List?> read(int size) async {
        calls++;
        if (calls == 1) return Uint8List.fromList([5]);
        return null;
      }

      expect(await readLengthPrefixedMessage(read), isNull);
    });

    test('rejects a length above the message-size bound', () async {
      // Build a varint prefix for 4 MiB + 1.
      var n = InboundMessageBounds.maxMessageSize + 1;
      final prefix = <int>[];
      while (n >= 0x80) {
        prefix.add((n & 0x7F) | 0x80);
        n >>= 7;
      }
      prefix.add(n);
      final bytes = Uint8List.fromList(prefix);
      var offset = 0;
      Future<Uint8List?> read(int size) async {
        if (offset >= bytes.length) return null;
        final end = (offset + size).clamp(0, bytes.length);
        final chunk = bytes.sublist(offset, end);
        offset = end;
        return chunk;
      }

      expect(() => readLengthPrefixedMessage(read), throwsFormatException);
    });
  });
}
