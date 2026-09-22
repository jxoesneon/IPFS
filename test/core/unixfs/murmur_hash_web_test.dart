@TestOn('vm')
library;

import 'dart:convert';
import 'dart:math';

import 'package:dart_ipfs/src/core/unixfs/murmur_hash.dart' as native;
import 'package:dart_ipfs/src/core/unixfs/murmur_hash_web.dart' as web;
import 'package:test/test.dart';

void main() {
  group('murmur_hash_web (BigInt implementation)', () {
    test('matches murmur3-x64-64 reference vectors in the low 32 bits', () {
      expect(web.murmur3X64Hash64(utf8.encode('')), 0x00000000);
      expect(web.murmur3X64Hash64(utf8.encode('hello')), 0x41BD9B02);
      expect(web.murmur3X64Hash64(utf8.encode('hello, world')), 0x3A5EBC8E);
      expect(
        web.murmur3X64Hash64(
          utf8.encode('The quick brown fox jumps over the lazy dog.'),
        ),
        0x9EE902C9,
      );
    });

    test('low 32 bits match the native implementation for all tail paths', () {
      final rng = Random(42);
      for (var length = 0; length <= 64; length++) {
        final bytes = List<int>.generate(length, (_) => rng.nextInt(256));
        expect(
          web.murmur3X64Hash64(bytes),
          native.murmur3X64Hash64(bytes) & 0xFFFFFFFF,
          reason: 'length $length diverged',
        );
      }
    });

    test('low 32 bits match the native implementation for seeded hashes', () {
      final input = utf8.encode('seeded-hamt-key');
      for (final seed in <int>[0, 1, 0x9747b28c, -1]) {
        expect(
          web.murmur3X64Hash64(input, seed: seed),
          native.murmur3X64Hash64(input, seed: seed) & 0xFFFFFFFF,
          reason: 'seed $seed diverged',
        );
      }
    });

    test(
      'murmur3X64Hash64Digest returns the full 64-bit digest as LE bytes',
      () {
        final rng = Random(7);
        for (var length = 0; length <= 64; length++) {
          final bytes = List<int>.generate(length, (_) => rng.nextInt(256));
          expect(
            web.murmur3X64Hash64Digest(bytes),
            equals(native.murmur3X64Hash64Digest(bytes)),
            reason: 'length $length diverged',
          );
        }
      },
    );

    test('murmur3X64Hash64Digest matches the native digest for seeds', () {
      final input = utf8.encode('hamt-digest-check');
      for (final seed in <int>[0, 1, 0x9747b28c]) {
        expect(
          web.murmur3X64Hash64Digest(input, seed: seed),
          equals(native.murmur3X64Hash64Digest(input, seed: seed)),
          reason: 'seed $seed diverged',
        );
      }
    });
  });
}
