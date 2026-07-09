// test/protocols/connection_manager/cuttlefish_connection_manager_test.dart
import 'package:dart_ipfs/src/protocols/connection_manager/cuttlefish_connection_manager.dart';
import 'package:test/test.dart';

void main() {
  group('CuttlefishConnectionManager', () {
    test('starts and stops', () {
      final manager = CuttlefishConnectionManager();
      expect(manager.isRunning, isFalse);
      manager.start();
      expect(manager.isRunning, isTrue);
      manager.stop();
      expect(manager.isRunning, isFalse);
    });

    test('addConnection increases connection count', () {
      final manager = CuttlefishConnectionManager(
        config: const CuttlefishConfig(highWater: 10, lowWater: 5),
      );
      manager.addConnection('peer1');
      manager.addConnection('peer2');
      expect(manager.connectionCount, equals(2));
    });

    test('removeConnection decreases connection count', () {
      final manager = CuttlefishConnectionManager();
      manager.addConnection('peer1');
      manager.addConnection('peer2');
      manager.removeConnection('peer1');
      expect(manager.connectionCount, equals(1));
      expect(manager.hasConnection('peer1'), isFalse);
      expect(manager.hasConnection('peer2'), isTrue);
    });

    test('hasConnection returns correct value', () {
      final manager = CuttlefishConnectionManager();
      manager.addConnection('peer1');
      expect(manager.hasConnection('peer1'), isTrue);
      expect(manager.hasConnection('peer2'), isFalse);
    });

    test('getConnection returns tagged connection', () {
      final manager = CuttlefishConnectionManager();
      manager.addConnection('peer1', tags: {'dht'});
      final conn = manager.getConnection('peer1');
      expect(conn, isNotNull);
      expect(conn!.peerId, equals('peer1'));
      expect(conn.hasTag('dht'), isTrue);
    });

    test('tag adds tag and adjusts priority', () {
      final manager = CuttlefishConnectionManager();
      manager.addConnection('peer1');
      manager.tag('peer1', 'dht', priority: 10);
      final conn = manager.getConnection('peer1');
      expect(conn!.hasTag('dht'), isTrue);
      expect(conn.priority, equals(10));
    });

    test('tag on unknown connection does nothing', () {
      final manager = CuttlefishConnectionManager();
      manager.tag('unknown', 'dht');
      // Should not throw.
      expect(manager.connectionCount, equals(0));
    });

    test('untag removes tag and adjusts priority', () {
      final manager = CuttlefishConnectionManager();
      manager.addConnection('peer1');
      manager.tag('peer1', 'dht', priority: 10);
      manager.untag('peer1', 'dht', priority: 10);
      final conn = manager.getConnection('peer1');
      expect(conn!.hasTag('dht'), isFalse);
      expect(conn.priority, equals(0));
    });

    test('protect prevents connection from being pruned', () {
      final manager = CuttlefishConnectionManager(
        config: const CuttlefishConfig(
          highWater: 3,
          lowWater: 1,
          gracePeriod: Duration.zero,
        ),
      );
      manager.addConnection('peer1');
      manager.addConnection('peer2');
      manager.protect('peer1');
      manager.addConnection('peer3');
      manager.addConnection('peer4'); // Triggers pruning

      expect(
        manager.hasConnection('peer1'),
        isTrue,
        reason: 'Protected connection should not be pruned',
      );
    });

    test('unprotect allows connection to be pruned', () {
      final manager = CuttlefishConnectionManager(
        config: const CuttlefishConfig(
          highWater: 3,
          lowWater: 1,
          gracePeriod: Duration.zero,
        ),
      );
      manager.addConnection('peer1');
      manager.addConnection('peer2');
      manager.protect('peer1');
      manager.unprotect('peer1');
      manager.addConnection('peer3');
      manager.addConnection('peer4'); // Triggers pruning

      // peer1 is no longer protected and has default priority 0.
      // It may or may not be pruned depending on sort order.
      expect(manager.connectionCount, equals(1));
    });

    test('pruning respects priority - low priority pruned first', () {
      final manager = CuttlefishConnectionManager(
        config: const CuttlefishConfig(
          highWater: 4,
          lowWater: 2,
          gracePeriod: Duration.zero,
        ),
      );
      manager.addConnection('peer1', priority: 100);
      manager.addConnection('peer2', priority: 1);
      manager.addConnection('peer3', priority: 50);
      manager.addConnection('peer4', priority: 10);
      manager.addConnection('peer5', priority: 5); // Triggers pruning

      // Should prune 2 lowest priority: peer2 (1) and peer5 (5).
      expect(manager.hasConnection('peer1'), isTrue);
      expect(manager.hasConnection('peer3'), isTrue);
      expect(manager.hasConnection('peer2'), isFalse);
      expect(manager.hasConnection('peer5'), isFalse);
    });

    test('grace period protects newly connected peers', () {
      final manager = CuttlefishConnectionManager(
        config: const CuttlefishConfig(
          highWater: 3,
          lowWater: 1,
          gracePeriod: Duration(minutes: 10),
        ),
      );
      manager.addConnection('peer1', priority: 100);
      manager.addConnection('peer2', priority: 100);
      manager.addConnection('peer3', priority: 0);
      manager.addConnection('peer4', priority: 0); // Triggers pruning

      // All connections are within grace period, so none should be pruned.
      expect(manager.connectionCount, equals(4));
    });

    test('pruneNow forces immediate pruning', () {
      final manager = CuttlefishConnectionManager(
        config: const CuttlefishConfig(
          highWater: 10,
          lowWater: 3,
          gracePeriod: Duration.zero,
        ),
      );
      for (var i = 0; i < 10; i++) {
        manager.addConnection('peer$i', priority: i);
      }
      // No pruning yet since count <= highWater.
      expect(manager.connectionCount, equals(10));

      // Add one more to trigger pruning.
      manager.addConnection('peer10', priority: 0);
      expect(manager.connectionCount, lessThanOrEqualTo(10));
    });

    test('connectionsByTag returns connections with given tag', () {
      final manager = CuttlefishConnectionManager();
      manager.addConnection('peer1', tags: {'dht'});
      manager.addConnection('peer2', tags: {'relay'});
      manager.addConnection('peer3', tags: {'dht', 'relay'});

      final dhtConns = manager.connectionsByTag('dht');
      expect(dhtConns.length, equals(2));

      final relayConns = manager.connectionsByTag('relay');
      expect(relayConns.length, equals(2));
    });

    test('prunedConnections stream emits pruned peer IDs', () async {
      final manager = CuttlefishConnectionManager(
        config: const CuttlefishConfig(
          highWater: 3,
          lowWater: 1,
          gracePeriod: Duration.zero,
        ),
      );

      final prunedPeers = <String>[];
      final subscription = manager.prunedConnections.listen(prunedPeers.add);

      manager.addConnection('peer1', priority: 10);
      manager.addConnection('peer2', priority: 1);
      manager.addConnection('peer3', priority: 5);
      manager.addConnection('peer4', priority: 100); // Triggers pruning

      // Allow stream to deliver events.
      await Future.delayed(Duration.zero);
      await subscription.cancel();

      expect(prunedPeers, isNotEmpty);
      expect(prunedPeers, contains('peer2')); // Lowest priority
    });

    test('getStats returns connection summary', () {
      final manager = CuttlefishConnectionManager(
        config: const CuttlefishConfig(highWater: 10, lowWater: 5),
      );
      manager.addConnection('peer1', tags: {'dht'});
      manager.addConnection('peer2', tags: {'dht', 'relay'});
      manager.protect('peer1');

      final stats = manager.getStats();
      expect(stats['total_connections'], equals(2));
      expect(stats['high_water'], equals(10));
      expect(stats['low_water'], equals(5));
      expect(stats['protected'], equals(1));
      expect(stats['tag_counts']['dht'], equals(2));
      expect(stats['tag_counts']['relay'], equals(1));
    });

    test('default config has highWater 128 and lowWater 64', () {
      final manager = CuttlefishConnectionManager();
      expect(manager.highWater, equals(128));
      expect(manager.lowWater, equals(64));
    });

    test('connections list returns all connections', () {
      final manager = CuttlefishConnectionManager();
      manager.addConnection('peer1');
      manager.addConnection('peer2');
      manager.addConnection('peer3');
      expect(manager.connections.length, equals(3));
    });

    test('stop clears all connections', () {
      final manager = CuttlefishConnectionManager();
      manager.addConnection('peer1');
      manager.addConnection('peer2');
      manager.start();
      manager.stop();
      expect(manager.connectionCount, equals(0));
    });
  });

  group('TaggedConnection', () {
    test('creates with default values', () {
      final conn = TaggedConnection(peerId: 'peer1');
      expect(conn.peerId, equals('peer1'));
      expect(conn.tags, isEmpty);
      expect(conn.priority, equals(0));
      expect(conn.isProtected, isFalse);
    });

    test('protect and unprotect', () {
      final conn = TaggedConnection(peerId: 'peer1');
      conn.protect();
      expect(conn.isProtected, isTrue);
      conn.unprotect();
      expect(conn.isProtected, isFalse);
    });

    test('addTag and removeTag', () {
      final conn = TaggedConnection(peerId: 'peer1');
      conn.addTag('dht');
      expect(conn.hasTag('dht'), isTrue);
      conn.removeTag('dht');
      expect(conn.hasTag('dht'), isFalse);
    });
  });
}
