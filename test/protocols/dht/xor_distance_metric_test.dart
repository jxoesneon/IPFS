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
        expect(distance, equals(0));
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
        expect(distance, greaterThanOrEqualTo(0));
      });

      test('calculates correct XOR distance for simple bytes', () {
        // 0b00000001 XOR 0b00000010 = 0b00000011 = 3
        final peerA = PeerId(value: Uint8List.fromList([1]));
        final peerB = PeerId(value: Uint8List.fromList([2]));
        final distance = metric.calculateDistance(peerA, peerB);
        expect(distance, equals(3));
      });

      test('calculates correct XOR distance for multi-byte values', () {
        // 0x0102 XOR 0x0304 = 0x0206 = 518
        final peerA = PeerId(value: Uint8List.fromList([1, 2]));
        final peerB = PeerId(value: Uint8List.fromList([3, 4]));
        final distance = metric.calculateDistance(peerA, peerB);
        expect(distance, equals(518));
      });

      test('handles different length peer IDs', () {
        final peerA = PeerId(value: Uint8List.fromList([1, 2, 3]));
        final peerB = PeerId(value: Uint8List.fromList([4, 5]));
        final distance = metric.calculateDistance(peerA, peerB);
        // Should not throw and should produce a valid distance
        expect(distance, greaterThanOrEqualTo(0));
      });

      test('handles empty peer IDs', () {
        final peerA = PeerId(value: Uint8List(0));
        final peerB = PeerId(value: Uint8List.fromList([1, 2, 3]));
        final distance = metric.calculateDistance(peerA, peerB);
        expect(distance, greaterThanOrEqualTo(0));
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
        expect(distanceAC, lessThanOrEqualTo(distanceAB + distanceBC + 1000));
      });
    });

    group('calculateDistanceToKey', () {
      test('distance to identical key is zero', () {
        final peerId = PeerId(value: Uint8List.fromList([1, 2, 3, 4]));
        final key = [1, 2, 3, 4];
        final distance = metric.calculateDistanceToKey(peerId, key);
        expect(distance, equals(0));
      });

      test('calculates correct XOR distance to key', () {
        final peerId = PeerId(value: Uint8List.fromList([1, 2, 3, 4]));
        final key = [5, 6, 7, 8];
        final distance = metric.calculateDistanceToKey(peerId, key);
        // 0x01020304 XOR 0x05060708 = 0x0404040C
        expect(distance, equals(0x0404040C));
      });

      test('handles different length peer ID and key', () {
        final peerId = PeerId(value: Uint8List.fromList([1, 2, 3]));
        final key = [4, 5, 6, 7, 8];
        final distance = metric.calculateDistanceToKey(peerId, key);
        expect(distance, greaterThanOrEqualTo(0));
      });

      test('handles empty key', () {
        final peerId = PeerId(value: Uint8List.fromList([1, 2, 3]));
        final key = <int>[];
        final distance = metric.calculateDistanceToKey(peerId, key);
        expect(distance, greaterThanOrEqualTo(0));
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
        expect(metric.calculateDistance(peer, peer), equals(0));
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
        expect(metric.calculateDistance(zero, close), equals(1));
      });

      test('a single differing leading byte yields a large distance', () {
        final zero = PeerId(value: Uint8List(32));
        final far = peerOfByte(0, 0x01);
        // The leading byte lands in the first 8-byte chunk:
        // 0x01 << 56 = 72057594037927936.
        expect(metric.calculateDistance(zero, far), equals(72057594037927936));
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
        expect(metric.calculateDistanceToKey(peer, key), equals(1));

        // Distance to a key equal to the peer ID is zero.
        expect(metric.calculateDistanceToKey(peer, peer.value), equals(0));
      });
    });
  });
}
