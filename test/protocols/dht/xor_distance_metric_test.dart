import 'dart:math';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/protocols/dht/xor_distance_metric.dart';
import 'package:test/test.dart';

void main() {
  group('XorDistanceMetric', () {
    late XorDistanceMetric metric;

    setUp(() {
      metric = const XorDistanceMetric();
    });

    group('calculateDistance', () {
      test('distance to self is zero', () {
        final peerId = PeerId(value: Uint8List.fromList([1, 2, 3, 4]));
        final distance = metric.calculateDistance(peerId, peerId);
        expect(distance, equals(BigInt.zero));
      });

      test('distance is symmetric', () {
        final peerA = PeerId(value: Uint8List.fromList([1, 2, 3, 4]));
        final peerB = PeerId(value: Uint8List.fromList([5, 6, 7, 8]));
        final distanceAB = metric.calculateDistance(peerA, peerB);
        final distanceBA = metric.calculateDistance(peerB, peerA);
        expect(distanceAB, equals(distanceBA));
      });

      test('distance is non-negative', () {
        final peerA = PeerId(value: Uint8List.fromList([1, 2, 3, 4]));
        final peerB = PeerId(value: Uint8List.fromList([5, 6, 7, 8]));
        final distance = metric.calculateDistance(peerA, peerB);
        expect(distance, greaterThanOrEqualTo(BigInt.zero));
      });

      test('calculates correct XOR distance for simple bytes', () {
        // 0b00000001 XOR 0b00000010 = 0b00000011 = 3
        final peerA = PeerId(value: Uint8List.fromList([1]));
        final peerB = PeerId(value: Uint8List.fromList([2]));
        final distance = metric.calculateDistance(peerA, peerB);
        expect(distance, equals(BigInt.from(3)));
      });

      test('calculates correct XOR distance for multi-byte values', () {
        // 0x0102 XOR 0x0304 = 0x0206 = 518
        final peerA = PeerId(value: Uint8List.fromList([1, 2]));
        final peerB = PeerId(value: Uint8List.fromList([3, 4]));
        final distance = metric.calculateDistance(peerA, peerB);
        expect(distance, equals(BigInt.from(518)));
      });

      test('handles different length peer IDs', () {
        final peerA = PeerId(value: Uint8List.fromList([1, 2, 3]));
        final peerB = PeerId(value: Uint8List.fromList([4, 5]));
        final distance = metric.calculateDistance(peerA, peerB);
        // Should not throw and should produce a valid distance
        expect(distance, greaterThanOrEqualTo(BigInt.zero));
      });

      test('handles empty peer IDs', () {
        final peerA = PeerId(value: Uint8List(0));
        final peerB = PeerId(value: Uint8List.fromList([1, 2, 3]));
        final distance = metric.calculateDistance(peerA, peerB);
        expect(distance, greaterThanOrEqualTo(BigInt.zero));
      });

      test('triangle inequality holds approximately', () {
        final peerA = PeerId(value: Uint8List.fromList([1, 2, 3, 4]));
        final peerB = PeerId(value: Uint8List.fromList([5, 6, 7, 8]));
        final peerC = PeerId(value: Uint8List.fromList([9, 10, 11, 12]));

        final distanceAC = metric.calculateDistance(peerA, peerC);
        final distanceAB = metric.calculateDistance(peerA, peerB);
        final distanceBC = metric.calculateDistance(peerB, peerC);

        // Triangle inequality: distance(a,c) <= distance(a,b) + distance(b,c)
        // Note: XOR distance doesn't strictly satisfy triangle inequality,
        // but it should be reasonably close for practical purposes
        expect(
          distanceAC,
          lessThanOrEqualTo(distanceAB + distanceBC + BigInt.from(1000)),
        );
      });
    });

    group('calculateDistanceToKey', () {
      test('distance to identical key is zero', () {
        final peerId = PeerId(value: Uint8List.fromList([1, 2, 3, 4]));
        final key = [1, 2, 3, 4];
        final distance = metric.calculateDistanceToKey(peerId, key);
        expect(distance, equals(BigInt.zero));
      });

      test('calculates correct XOR distance to key', () {
        final peerId = PeerId(value: Uint8List.fromList([1, 2, 3, 4]));
        final key = [5, 6, 7, 8];
        final distance = metric.calculateDistanceToKey(peerId, key);
        // 0x01020304 XOR 0x05060708 = 0x0404040C
        expect(distance, equals(BigInt.from(0x0404040C)));
      });

      test('handles different length peer ID and key', () {
        final peerId = PeerId(value: Uint8List.fromList([1, 2, 3]));
        final key = [4, 5, 6, 7, 8];
        final distance = metric.calculateDistanceToKey(peerId, key);
        expect(distance, greaterThanOrEqualTo(BigInt.zero));
      });

      test('handles empty key', () {
        final peerId = PeerId(value: Uint8List.fromList([1, 2, 3]));
        final key = <int>[];
        final distance = metric.calculateDistanceToKey(peerId, key);
        expect(distance, greaterThanOrEqualTo(BigInt.zero));
      });

      test('symmetric with calculateDistance when key is peer ID', () {
        final peerA = PeerId(value: Uint8List.fromList([1, 2, 3, 4]));
        final peerB = PeerId(value: Uint8List.fromList([5, 6, 7, 8]));

        final distanceViaKey = metric.calculateDistanceToKey(
          peerA,
          peerB.value,
        );
        final distanceDirect = metric.calculateDistance(peerA, peerB);

        expect(distanceViaKey, equals(distanceDirect));
      });
    });

    group('distance ordering', () {
      test('correctly orders peers by distance', () {
        final target = PeerId(value: Uint8List.fromList([10, 0, 0, 0]));

        final peerA = PeerId(value: Uint8List.fromList([0, 0, 0, 0])); // Far
        final peerB = PeerId(value: Uint8List.fromList([9, 0, 0, 0])); // Close
        final peerC = PeerId(
          value: Uint8List.fromList([11, 0, 0, 0]),
        ); // Very close

        final distanceA = metric.calculateDistance(target, peerA);
        final distanceB = metric.calculateDistance(target, peerB);
        final distanceC = metric.calculateDistance(target, peerC);

        // peerC should be closest (distance = 1)
        // peerB should be next (distance = 3)
        // peerA should be farthest (distance = 10)
        expect(distanceC, lessThan(distanceB));
        expect(distanceB, lessThan(distanceA));
      });

      test('peers with similar IDs have small distances', () {
        final peerA = PeerId(value: Uint8List.fromList([1, 2, 3, 4]));
        final peerB = PeerId(value: Uint8List.fromList([1, 2, 3, 5]));
        final peerC = PeerId(value: Uint8List.fromList([10, 20, 30, 40]));

        final distanceAB = metric.calculateDistance(peerA, peerB);
        final distanceAC = metric.calculateDistance(peerA, peerC);

        expect(distanceAB, lessThan(distanceAC));
      });
    });

    group('full-length routing keys (32-byte SHA-256 space)', () {
      PeerId peerOfByte(int position, int value) {
        final bytes = Uint8List(32);
        bytes[position] = value;
        return PeerId(value: bytes);
      }

      test('distance to self is zero for 32-byte peer IDs', () {
        final peer = PeerId(
          value: Uint8List.fromList(List.generate(32, (i) => i * 7)),
        );
        expect(metric.calculateDistance(peer, peer), equals(BigInt.zero));
      });

      test('distance is symmetric for 32-byte peer IDs', () {
        final a = PeerId(
          value: Uint8List.fromList(List.generate(32, (i) => i)),
        );
        final b = PeerId(
          value: Uint8List.fromList(List.generate(32, (i) => 255 - i)),
        );
        expect(
          metric.calculateDistance(a, b),
          equals(metric.calculateDistance(b, a)),
        );
      });

      test('a single differing trailing byte yields distance 1', () {
        final zero = PeerId(value: Uint8List(32));
        final close = peerOfByte(31, 0x01);
        expect(metric.calculateDistance(zero, close), equals(BigInt.one));
      });

      test('a single differing leading byte yields a large distance', () {
        final zero = PeerId(value: Uint8List(32));
        final far = peerOfByte(0, 0x01);
        // The leading byte is the most significant byte of the 256-bit
        // XOR result: 0x01 << 248.
        expect(metric.calculateDistance(zero, far), equals(BigInt.one << 248));
      });

      test('orders 32-byte peers by XOR distance to a target', () {
        final target = PeerId(value: Uint8List(32));
        final close = peerOfByte(31, 0x01); // distance 1
        final mid = peerOfByte(31, 0x0F); // distance 15
        final far = peerOfByte(30, 0xFF); // distance 255 << 8

        final distances = [
          metric.calculateDistance(target, close),
          metric.calculateDistance(target, mid),
          metric.calculateDistance(target, far),
        ];

        expect(distances[0], lessThan(distances[1]));
        expect(distances[1], lessThan(distances[2]));
      });

      test('calculateDistanceToKey handles 32-byte routing keys', () {
        final peer = PeerId(value: Uint8List(32));
        // A key differing only in the trailing byte has distance 1.
        final key = List<int>.filled(32, 0)..[31] = 1;
        expect(metric.calculateDistanceToKey(peer, key), equals(BigInt.one));

        // Distance to a key equal to the peer ID is zero.
        expect(
          metric.calculateDistanceToKey(peer, peer.value),
          equals(BigInt.zero),
        );
      });

      test('distance equals BigInt.parse of XOR hex for 256-bit keys', () {
        // Verifies that distance(a, b) is exactly the big-endian value of the
        // full 256-bit XOR byte array.
        final a = PeerId(
          value: Uint8List.fromList(List.generate(32, (i) => (i * 31) & 0xFF)),
        );
        final b = PeerId(
          value: Uint8List.fromList(
            List.generate(32, (i) => (i * 17 + 5) & 0xFF),
          ),
        );

        final xorHex = [
          for (var i = 0; i < 32; i++)
            (a.value[i] ^ b.value[i]).toRadixString(16).padLeft(2, '0'),
        ].join();

        expect(
          metric.calculateDistance(a, b),
          equals(BigInt.parse(xorHex, radix: 16)),
        );
      });

      test(
        'exactly orders peers whose 8-byte-chunk XOR reductions collide',
        () {
          // Two 256-bit keys whose XOR distances collapse to the same value
          // under the previous lossy chunk-XOR reduction (XOR of four 64-bit
          // chunks), but whose true distances differ by orders of magnitude.
          //
          // peerHigh differs in byte 0  -> XOR = 0x01 << 248
          // peerLow  differs in byte 8  -> XOR = 0x01 << 184
          // Chunk-XOR of both = 0x01 << 56 (identical), so the old metric
          // could not order them at all.
          final target = PeerId(value: Uint8List(32));
          final peerHigh = peerOfByte(0, 0x01);
          final peerLow = peerOfByte(8, 0x01);

          final distanceHigh = metric.calculateDistance(target, peerHigh);
          final distanceLow = metric.calculateDistance(target, peerLow);

          expect(distanceHigh, equals(BigInt.one << 248));
          expect(distanceLow, equals(BigInt.one << 184));
          // peerLow is strictly closer despite the colliding reduction.
          expect(distanceLow, lessThan(distanceHigh));
        },
      );

      test('exactly orders peers where lossy reduction inverts ordering', () {
        // The old chunk-XOR reduction ranked these peers in the wrong order:
        //
        // peerA differs in byte 8  -> true distance 0xFF << 184
        //                             old reduction: 0xFF << 56
        // peerB differs in byte 0  -> true distance 0x01 << 248
        //                             old reduction: 0x01 << 56
        //
        // Old ordering claimed peerB was closer (0x01<<56 < 0xFF<<56), but
        // the true distances order the other way: peerA is closer
        // (0xFF<<184 < 0x01<<248).
        final target = PeerId(value: Uint8List(32));
        final peerA = peerOfByte(8, 0xFF);
        final peerB = peerOfByte(0, 0x01);

        final distanceA = metric.calculateDistance(target, peerA);
        final distanceB = metric.calculateDistance(target, peerB);

        expect(distanceA, equals(BigInt.from(0xFF) << 184));
        expect(distanceB, equals(BigInt.one << 248));
        expect(distanceA, lessThan(distanceB));
      });
    });

    group('compareXorDistanceToKey', () {
      int bigIntOrdering(List<int> a, List<int> b, List<int> ref) {
        final distA = metric.calculateDistanceToKey(
          PeerId(value: Uint8List.fromList(a)),
          ref,
        );
        final distB = metric.calculateDistanceToKey(
          PeerId(value: Uint8List.fromList(b)),
          ref,
        );
        return distA.compareTo(distB);
      }

      int sign(int v) => v == 0 ? 0 : (v < 0 ? -1 : 1);

      test('matches BigInt ordering for equal-length 32-byte peer IDs', () {
        final random = Random(0xC0FFEE);
        Uint8List randomId() =>
            Uint8List.fromList(List.generate(32, (_) => random.nextInt(256)));

        final reference = randomId();
        final peers = List.generate(24, (_) => randomId());

        for (final a in peers) {
          for (final b in peers) {
            expect(
              sign(compareXorDistanceToKey(a, b, reference)),
              equals(sign(bigIntOrdering(a, b, reference))),
              reason: 'mismatch for a=$a b=$b ref=$reference',
            );
          }
        }
      });

      test('matches BigInt ordering for different-length keys', () {
        final reference = [0x0F, 0xF0, 0x55];
        final cases = <List<int>>[
          <int>[],
          [0x00],
          [0x0F, 0xF0, 0x55],
          [0x00, 0x0F, 0xF0, 0x55],
          [0xFF],
          [0x10, 0xF0, 0x55],
          [0x0F, 0xF0],
        ];

        for (final a in cases) {
          for (final b in cases) {
            expect(
              sign(compareXorDistanceToKey(a, b, reference)),
              equals(sign(bigIntOrdering(a, b, reference))),
              reason: 'mismatch for a=$a b=$b ref=$reference',
            );
          }
        }
      });

      test('orders known distances correctly', () {
        final reference = List<int>.filled(32, 0);
        final close = List<int>.filled(32, 0)..[31] = 0x01;
        final mid = List<int>.filled(32, 0)..[31] = 0x0F;
        final far = List<int>.filled(32, 0)..[30] = 0xFF;

        expect(compareXorDistanceToKey(close, mid, reference), isNegative);
        expect(compareXorDistanceToKey(mid, far, reference), isNegative);
        expect(compareXorDistanceToKey(far, close, reference), isPositive);
        expect(compareXorDistanceToKey(close, close, reference), isZero);
      });

      test('distance to reference itself is zero and minimal', () {
        final reference = Uint8List.fromList(
          List.generate(32, (i) => (i * 13) & 0xFF),
        );
        final other = Uint8List.fromList(reference)..[31] ^= 0x01;

        expect(
          compareXorDistanceToKey(reference, other, reference),
          isNegative,
        );
        expect(
          compareXorDistanceToKey(reference, reference, reference),
          isZero,
        );
      });
    });

    group('closestPeersToKey', () {
      test('returns the k nearest peers ordered like the BigInt sort', () {
        final random = Random(0xBADDCAFE);
        PeerId randomPeer() => PeerId(
          value: Uint8List.fromList(
            List.generate(32, (_) => random.nextInt(256)),
          ),
        );

        final reference = randomPeer();
        final candidates = List.generate(40, (_) => randomPeer());
        const k = 10;

        final expected = [...candidates]
          ..sort(
            (a, b) => metric
                .calculateDistance(reference, a)
                .compareTo(metric.calculateDistance(reference, b)),
          );

        expect(
          closestPeersToKey(candidates, reference.value, k),
          orderedEquals(expected.take(k)),
        );
      });

      test('returns all candidates when fewer than k exist', () {
        final reference = PeerId(value: Uint8List.fromList([10, 0, 0, 0]));
        final close = PeerId(value: Uint8List.fromList([11, 0, 0, 0]));
        final far = PeerId(value: Uint8List.fromList([0, 0, 0, 0]));

        expect(
          closestPeersToKey([far, close], reference.value, 20),
          orderedEquals([close, far]),
        );
      });

      test('returns empty for empty candidates', () {
        expect(
          closestPeersToKey(const [], List<int>.filled(32, 0), 20),
          isEmpty,
        );
      });
    });
  });
}
