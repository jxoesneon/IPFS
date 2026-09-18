import 'dart:typed_data';

import 'package:dart_ipfs/src/transport/libp2p_router.dart';
import 'package:test/test.dart';

void main() {
  group('readLengthPrefixedMessage', () {
    Future<Uint8List?> Function(int) readerFrom(List<int> bytes) {
      var offset = 0;
      return (size) async {
        if (offset >= bytes.length) return null;
        final end = offset + size > bytes.length ? bytes.length : offset + size;
        final chunk = Uint8List.fromList(bytes.sublist(offset, end));
        offset = end;
        return chunk;
      };
    }

    List<int> varint(int value) {
      final out = <int>[];
      var n = value;
      while (n >= 0x80) {
        out.add((n & 0x7F) | 0x80);
        n >>= 7;
      }
      out.add(n);
      return out;
    }

    test('reads a simple length-prefixed message', () async {
      final body = [1, 2, 3, 4, 5];
      final wire = [...varint(body.length), ...body];
      final msg = await Libp2pRouter.readLengthPrefixedMessage(
        readerFrom(wire),
      );
      expect(msg, equals(body));
    });

    test('reads a multi-byte varint length', () async {
      final body = List<int>.generate(300, (i) => i & 0xFF);
      final wire = [...varint(body.length), ...body];
      final msg = await Libp2pRouter.readLengthPrefixedMessage(
        readerFrom(wire),
      );
      expect(msg, equals(body));
    });

    test('returns null when the stream closes before the prefix', () async {
      final msg = await Libp2pRouter.readLengthPrefixedMessage(readerFrom([]));
      expect(msg, isNull);
    });

    test('returns null on premature close mid-body', () async {
      final wire = [...varint(10), 1, 2, 3];
      final msg = await Libp2pRouter.readLengthPrefixedMessage(
        readerFrom(wire),
      );
      expect(msg, isNull);
    });

    test('returns empty message for zero length', () async {
      final msg = await Libp2pRouter.readLengthPrefixedMessage(
        readerFrom(varint(0)),
      );
      expect(msg, isEmpty);
    });

    test('rejects a varint prefix longer than 10 bytes', () async {
      // Eleven continuation bytes: never terminates within the bound.
      final wire = List<int>.filled(11, 0xFF);
      expect(
        () => Libp2pRouter.readLengthPrefixedMessage(readerFrom(wire)),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects an advertised length above the inbound cap', () async {
      const cap = 4 * 1024 * 1024;
      final wire = varint(cap + 1);
      expect(
        () => Libp2pRouter.readLengthPrefixedMessage(readerFrom(wire)),
        throwsA(isA<FormatException>()),
      );
    });

    test('reassembles bodies split across chunk boundaries', () async {
      final body = List<int>.generate(200000, (i) => i & 0xFF);
      final wire = [...varint(body.length), ...body];
      var offset = 0;
      Future<Uint8List?> trickle(int size) async {
        if (offset >= wire.length) return null;
        final take = size > 7 ? 7 : size; // force many small reads
        final end = offset + take > wire.length ? wire.length : offset + take;
        final chunk = Uint8List.fromList(wire.sublist(offset, end));
        offset = end;
        return chunk;
      }

      final msg = await Libp2pRouter.readLengthPrefixedMessage(trickle);
      expect(msg, equals(body));
    });
  });

  group('decodeVarint', () {
    test('decodes single and multi byte values', () {
      expect(Libp2pRouter.decodeVarint(Uint8List.fromList([0x05])), 5);
      expect(Libp2pRouter.decodeVarint(Uint8List.fromList([0xAC, 0x02])), 300);
    });

    test('throws when the encoding exceeds 64 bits', () {
      // 10 bytes all with continuation bits set pushes shift to 63, an
      // 11th byte would exceed the bound; feed 11 bytes directly.
      final bytes = Uint8List.fromList(List<int>.filled(11, 0xFF));
      expect(
        () => Libp2pRouter.decodeVarint(bytes),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
