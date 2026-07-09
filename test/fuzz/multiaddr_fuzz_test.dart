// Fuzz tests for the multiaddr parser.
//
// These tests feed random bytes, corrupt protocol codes, and truncated
// sequences to [multiaddrFromBytes] and [parseMultiaddrString], verifying
// that the parsers either produce a valid result or return null / throw a
// known exception type — they must never crash.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/data_structures/peer.dart';
import 'package:test/test.dart';

import '_fuzz_helpers.dart';

void main() {
  group('Multiaddr fuzz', () {
    final rng = makeRandom();

    test('random bytes fed to multiaddrFromBytes do not crash', () {
      for (var i = 0; i < 5000; i++) {
        final data = randomBytesRange(rng, 1, 200);
        // multiaddrFromBytes returns null on invalid input — must not throw.
        final result = multiaddrFromBytes(data);
        expect(result, anyOf(isNull, isA<FullAddress>()));
      }
    });

    test('empty bytes are handled gracefully', () {
      final result = multiaddrFromBytes(Uint8List(0));
      expect(result, isNull);
    });

    test('valid multiaddr with corrupted protocol codes', () {
      final validMultiaddrs = _generateValidMultiaddrBytes();
      for (final maBytes in validMultiaddrs) {
        // Corrupt the first protocol code byte.
        for (var code = 0; code < 256; code++) {
          final corrupted = withByte(maBytes, 0, code);
          final result = multiaddrFromBytes(corrupted);
          expect(result, anyOf(isNull, isA<FullAddress>()));
        }
      }
    });

    test('truncated multiaddr bytes are handled gracefully', () {
      final validMultiaddrs = _generateValidMultiaddrBytes();
      for (final maBytes in validMultiaddrs) {
        for (var cut = 0; cut < maBytes.length; cut++) {
          final truncatedMa = truncated(maBytes, cut);
          final result = multiaddrFromBytes(truncatedMa);
          expect(result, anyOf(isNull, isA<FullAddress>()));
        }
      }
    });

    test('corrupted valid multiaddr with flipped bytes', () {
      final validMultiaddrs = _generateValidMultiaddrBytes();
      for (final maBytes in validMultiaddrs) {
        for (var trial = 0; trial < 100; trial++) {
          final corrupted = withFlippedBytes(rng, maBytes, 1 + rng.nextInt(3));
          final result = multiaddrFromBytes(corrupted);
          expect(result, anyOf(isNull, isA<FullAddress>()));
        }
      }
    });

    test('random strings fed to parseMultiaddrString do not crash', () {
      for (var i = 0; i < 3000; i++) {
        final str = _randomAddrString(rng, 1 + rng.nextInt(100));
        final result = parseMultiaddrString(str);
        expect(result, anyOf(isNull, isA<FullAddress>()));
      }
    });

    test('valid multiaddr strings with corrupted protocol codes', () {
      final validStrings = _generateValidMultiaddrStrings();
      for (final str in validStrings) {
        // Replace the protocol component with random strings.
        final parts = str.split('/');
        if (parts.length > 1) {
          for (var proto in ['ip4', 'ip6', 'tcp', 'udp', 'p2p', 'dns']) {
            parts[1] = proto;
            final corrupted = parts.join('/');
            final result = parseMultiaddrString(corrupted);
            expect(result, anyOf(isNull, isA<FullAddress>()));
          }
        }
      }
    });

    test('truncated multiaddr strings are handled gracefully', () {
      final validStrings = _generateValidMultiaddrStrings();
      for (final str in validStrings) {
        for (var cut = 0; cut < str.length; cut++) {
          final truncatedStr = str.substring(0, cut);
          final result = parseMultiaddrString(truncatedStr);
          expect(result, anyOf(isNull, isA<FullAddress>()));
        }
      }
    });

    test(
      'Peer.fromMultiaddr with random strings is handled gracefully',
      () async {
        for (var i = 0; i < 500; i++) {
          final str = '/ip4/127.0.0.1/tcp/4001/p2p/${_randomString(rng, 20)}';
          try {
            await Peer.fromMultiaddr(str);
          } on FormatException {
            // Expected — invalid multiaddr rejected.
          } on ArgumentError {
            // Expected — invalid peer ID rejected.
          } on Exception {
            // Expected — any typed exception.
          }
        }
      },
    );
  });
}

/// Generates valid binary multiaddr byte sequences.
List<Uint8List> _generateValidMultiaddrBytes() {
  final sequences = <Uint8List>[];
  // /ip4/127.0.0.1/tcp/4001
  sequences.add(
    multiaddrToBytes(const FullAddress(address: '127.0.0.1', port: 4001)),
  );
  // /ip4/192.168.1.1/tcp/8080
  sequences.add(
    multiaddrToBytes(const FullAddress(address: '192.168.1.1', port: 8080)),
  );
  // /ip6/::1/tcp/4001
  sequences.add(
    multiaddrToBytes(const FullAddress(address: '::1', port: 4001)),
  );
  return sequences;
}

/// Generates valid multiaddr string sequences.
List<String> _generateValidMultiaddrStrings() {
  return [
    '/ip4/127.0.0.1/tcp/4001',
    '/ip4/192.168.1.1/tcp/8080',
    '/ip6/::1/tcp/4001',
    '/ip4/10.0.0.1/udp/1234',
  ];
}

/// Generates a random string that looks like a multiaddr fragment.
String _randomAddrString(math.Random rng, int length) {
  const alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789/.:';
  final buffer = StringBuffer();
  for (var i = 0; i < length; i++) {
    buffer.write(alphabet[rng.nextInt(alphabet.length)]);
  }
  return buffer.toString();
}

/// Generates a random alphanumeric string of [length] characters.
String _randomString(math.Random rng, int length) {
  const alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  final buffer = StringBuffer();
  for (var i = 0; i < length; i++) {
    buffer.write(alphabet[rng.nextInt(alphabet.length)]);
  }
  return buffer.toString();
}
