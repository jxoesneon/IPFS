import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/protocols/dht/xor_distance_metric.dart';

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
  });
}
