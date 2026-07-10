import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/protocols/dht/xor_distance_metric.dart';

void main() {
  group('DHT Routing Integration - Distance-based Peer Selection', () {
    late XorDistanceMetric metric;

    setUp(() {
      metric = const XorDistanceMetric();
    });

    test('selects closest peers by XOR distance', () {
      final targetKey = [10, 0, 0, 0];

      final peers = [
        PeerId(value: Uint8List.fromList([0, 0, 0, 0])), // Far
        PeerId(value: Uint8List.fromList([9, 0, 0, 0])), // Close
        PeerId(value: Uint8List.fromList([11, 0, 0, 0])), // Very close
        PeerId(value: Uint8List.fromList([255, 255, 255, 255])), // Very far
        PeerId(value: Uint8List.fromList([10, 0, 0, 1])), // Extremely close
      ];

      // Calculate distances
      final distances = peers
          .map((p) => metric.calculateDistanceToKey(p, targetKey))
          .toList();

      // Sort peers by distance
      final sortedPeers = List<PeerId>.from(peers);
      sortedPeers.sort(
        (a, b) => metric
            .calculateDistanceToKey(a, targetKey)
            .compareTo(metric.calculateDistanceToKey(b, targetKey)),
      );

      // Verify ordering
      expect(sortedPeers[0].value, equals([10, 0, 0, 1])); // Distance = 1
      expect(sortedPeers[1].value, equals([11, 0, 0, 0])); // Distance = 1
      expect(sortedPeers[2].value, equals([9, 0, 0, 0])); // Distance = 3
      expect(sortedPeers[3].value, equals([0, 0, 0, 0])); // Distance = 10
      expect(
        sortedPeers[4].value,
        equals([255, 255, 255, 255]),
      ); // Distance = large
    });

    test('handles K closest peers selection', () {
      final targetKey = [128, 0, 0, 0];
      final k = 3;

      final peers = List.generate(
        10,
        (i) => PeerId(value: Uint8List.fromList([i, 0, 0, 0])),
      );

      // Sort by distance and take K
      final sortedPeers = List<PeerId>.from(peers);
      sortedPeers.sort(
        (a, b) => metric
            .calculateDistanceToKey(a, targetKey)
            .compareTo(metric.calculateDistanceToKey(b, targetKey)),
      );

      final closestPeers = sortedPeers.take(k).toList();

      expect(closestPeers.length, equals(k));

      // Verify distances are in ascending order
      for (int i = 0; i < closestPeers.length - 1; i++) {
        final distI = metric.calculateDistanceToKey(closestPeers[i], targetKey);
        final distNext = metric.calculateDistanceToKey(
          closestPeers[i + 1],
          targetKey,
        );
        expect(distI, lessThanOrEqualTo(distNext));
      }
    });

    test('distance metric is consistent across multiple calls', () {
      final peerA = PeerId(value: Uint8List.fromList([1, 2, 3, 4]));
      final peerB = PeerId(value: Uint8List.fromList([5, 6, 7, 8]));

      final distance1 = metric.calculateDistance(peerA, peerB);
      final distance2 = metric.calculateDistance(peerA, peerB);
      final distance3 = metric.calculateDistance(peerA, peerB);

      expect(distance1, equals(distance2));
      expect(distance2, equals(distance3));
    });

    test('peer selection is deterministic', () {
      final targetKey = [100, 100, 100, 100];

      final peers = [
        PeerId(value: Uint8List.fromList([50, 50, 50, 50])),
        PeerId(value: Uint8List.fromList([150, 150, 150, 150])),
        PeerId(value: Uint8List.fromList([100, 100, 100, 101])),
      ];

      // Sort twice
      final sorted1 = List<PeerId>.from(peers);
      sorted1.sort(
        (a, b) => metric
            .calculateDistanceToKey(a, targetKey)
            .compareTo(metric.calculateDistanceToKey(b, targetKey)),
      );

      final sorted2 = List<PeerId>.from(peers);
      sorted2.sort(
        (a, b) => metric
            .calculateDistanceToKey(a, targetKey)
            .compareTo(metric.calculateDistanceToKey(b, targetKey)),
      );

      expect(sorted1, equals(sorted2));
    });

    test('handles edge case of identical peer IDs', () {
      final peerId = PeerId(value: Uint8List.fromList([1, 2, 3, 4]));
      final peers = [
        peerId,
        peerId,
        PeerId(value: Uint8List.fromList([5, 6, 7, 8])),
      ];

      final targetKey = [1, 2, 3, 4];

      final sortedPeers = List<PeerId>.from(peers);
      sortedPeers.sort(
        (a, b) => metric
            .calculateDistanceToKey(a, targetKey)
            .compareTo(metric.calculateDistanceToKey(b, targetKey)),
      );

      // Identical peers should have distance 0
      expect(
        metric.calculateDistanceToKey(sortedPeers[0], targetKey),
        equals(0),
      );
      expect(
        metric.calculateDistanceToKey(sortedPeers[1], targetKey),
        equals(0),
      );
    });
  });
}
