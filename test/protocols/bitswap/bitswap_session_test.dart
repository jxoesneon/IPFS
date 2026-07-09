// test/protocols/bitswap/bitswap_session_test.dart
import 'package:dart_ipfs/src/protocols/bitswap/bitswap_session.dart';
import 'package:test/test.dart';

void main() {
  group('BitswapSession', () {
    test('creates session with unique id', () {
      final session1 = BitswapSession(id: 1);
      final session2 = BitswapSession(id: 2);
      expect(session1.id, equals(1));
      expect(session2.id, equals(2));
      expect(session1.isActive, isTrue);
      expect(session2.isActive, isTrue);
    });

    test('addInterest and isInterestedIn', () {
      final session = BitswapSession(id: 1);
      session.addInterest('cid1');
      session.addInterest('cid2');
      expect(session.isInterestedIn('cid1'), isTrue);
      expect(session.isInterestedIn('cid2'), isTrue);
      expect(session.isInterestedIn('cid3'), isFalse);
      expect(session.interestedCids.length, equals(2));
    });

    test('removeInterest removes CID', () {
      final session = BitswapSession(id: 1);
      session.addInterest('cid1');
      session.removeInterest('cid1');
      expect(session.isInterestedIn('cid1'), isFalse);
      expect(session.interestedCids.length, equals(0));
    });

    test('addPeer and removePeer', () {
      final session = BitswapSession(id: 1);
      session.addPeer('peerA');
      session.addPeer('peerB');
      expect(session.sessionPeers.contains('peerA'), isTrue);
      expect(session.sessionPeers.contains('peerB'), isTrue);
      expect(session.sessionPeers.length, equals(2));

      session.removePeer('peerA');
      expect(session.sessionPeers.contains('peerA'), isFalse);
      expect(session.sessionPeers.length, equals(1));
    });

    test('recordHave tracks provider for CID', () {
      final session = BitswapSession(id: 1);
      session.recordHave('peerA', 'cid1');
      expect(session.isInterestedIn('cid1'), isFalse); // Not added as interest
      expect(session.sessionPeers.contains('peerA'), isTrue);
    });

    test('recordDontHave removes provider for CID', () {
      final session = BitswapSession(id: 1);
      session.recordHave('peerA', 'cid1');
      session.recordDontHave('peerA', 'cid1');
      // After DONT_HAVE, peerA should not be a known provider for cid1.
      // targetPeersForWant falls back to all session peers when no provider
      // is known, so we verify by checking that a known provider is preferred.
      session.recordHave('peerB', 'cid1');
      final targets = session.targetPeersForWant('cid1');
      expect(targets.contains('peerA'), isFalse);
      expect(targets.contains('peerB'), isTrue);
    });

    test('markPeerHasAll and haveAllPeers', () {
      final session = BitswapSession(id: 1);
      session.addPeer('peerA');
      session.markPeerHasAll('peerA');
      expect(session.haveAllPeers.contains('peerA'), isTrue);
    });

    test('unmarkPeerHasAll removes from have-all set', () {
      final session = BitswapSession(id: 1);
      session.addPeer('peerA');
      session.markPeerHasAll('peerA');
      session.unmarkPeerHasAll('peerA');
      expect(session.haveAllPeers.contains('peerA'), isFalse);
    });

    test('targetPeersForWant returns have-all peers first', () {
      final session = BitswapSession(id: 1);
      session.addPeer('peerA');
      session.addPeer('peerB');
      session.markPeerHasAll('peerA');
      session.recordHave('peerB', 'cid1');

      final targets = session.targetPeersForWant('cid1');
      expect(targets.contains('peerA'), isTrue);
      expect(targets.length, equals(1)); // Only have-all peer
    });

    test('targetPeersForWant returns known providers', () {
      final session = BitswapSession(id: 1);
      session.addPeer('peerA');
      session.addPeer('peerB');
      session.recordHave('peerA', 'cid1');

      final targets = session.targetPeersForWant('cid1');
      expect(targets.contains('peerA'), isTrue);
      expect(targets.contains('peerB'), isFalse);
    });

    test('targetPeersForWant falls back to all session peers', () {
      final session = BitswapSession(id: 1);
      session.addPeer('peerA');
      session.addPeer('peerB');

      final targets = session.targetPeersForWant('unknownCid');
      expect(targets.length, equals(2));
    });

    test('shouldBroadcast returns true when few session peers', () {
      final session = BitswapSession(id: 1, broadcastThreshold: 5);
      session.addPeer('peerA');
      expect(session.shouldBroadcast('cid1'), isTrue);
    });

    test(
      'shouldBroadcast returns false when enough peers and provider known',
      () {
        final session = BitswapSession(id: 1, broadcastThreshold: 2);
        session.addPeer('peerA');
        session.addPeer('peerB');
        session.recordHave('peerA', 'cid1');
        expect(session.shouldBroadcast('cid1'), isFalse);
      },
    );

    test('shouldBroadcast returns true when no provider known', () {
      final session = BitswapSession(id: 1, broadcastThreshold: 2);
      session.addPeer('peerA');
      session.addPeer('peerB');
      expect(session.shouldBroadcast('cid1'), isTrue);
    });

    test('updatePeerLatency and getPeerLatency', () {
      final session = BitswapSession(id: 1);
      session.addPeer('peerA', latencyMs: 100);
      expect(session.getPeerLatency('peerA'), equals(100));
      session.updatePeerLatency('peerA', 50);
      expect(session.getPeerLatency('peerA'), equals(50));
    });

    test('peersByLatency sorts by latency ascending', () {
      final session = BitswapSession(id: 1);
      session.addPeer('peerA', latencyMs: 300);
      session.addPeer('peerB', latencyMs: 50);
      session.addPeer('peerC', latencyMs: 150);

      final sorted = session.peersByLatency();
      expect(sorted, equals(['peerB', 'peerC', 'peerA']));
    });

    test('close clears all state', () {
      final session = BitswapSession(id: 1);
      session.addInterest('cid1');
      session.addPeer('peerA');
      session.markPeerHasAll('peerA');
      session.close();

      expect(session.isActive, isFalse);
      expect(session.interestedCids.length, equals(0));
      expect(session.sessionPeers.length, equals(0));
      expect(session.haveAllPeers.length, equals(0));
    });

    test('addInterest does nothing after close', () {
      final session = BitswapSession(id: 1);
      session.close();
      session.addInterest('cid1');
      expect(session.interestedCids.length, equals(0));
    });
  });

  group('BitswapSessionManager', () {
    test('createSession returns session with unique id', () {
      final manager = BitswapSessionManager();
      final session1 = manager.createSession();
      final session2 = manager.createSession();
      expect(session1.id, isNot(equals(session2.id)));
    });

    test('getSession returns session by id', () {
      final manager = BitswapSessionManager();
      final session = manager.createSession();
      expect(manager.getSession(session.id), same(session));
    });

    test('getSession returns null for unknown id', () {
      final manager = BitswapSessionManager();
      expect(manager.getSession(999), isNull);
    });

    test('closeSession removes session', () {
      final manager = BitswapSessionManager();
      final session = manager.createSession();
      manager.closeSession(session.id);
      expect(manager.getSession(session.id), isNull);
      expect(session.isActive, isFalse);
    });

    test('activeSessions returns only active sessions', () {
      final manager = BitswapSessionManager();
      final session1 = manager.createSession();
      manager.createSession();
      manager.closeSession(session1.id);
      expect(manager.activeSessions.length, equals(1));
    });

    test('activeSessionCount returns count of active sessions', () {
      final manager = BitswapSessionManager();
      manager.createSession();
      manager.createSession();
      expect(manager.activeSessionCount, equals(2));
    });

    test('start and stop', () {
      final manager = BitswapSessionManager();
      manager.start();
      expect(manager.isRunning, isTrue);
      manager.stop();
      expect(manager.isRunning, isFalse);
    });

    test('sessionsInterestedIn returns sessions interested in CID', () {
      final manager = BitswapSessionManager();
      final session1 = manager.createSession();
      final session2 = manager.createSession();
      session1.addInterest('cid1');
      session2.addInterest('cid2');

      final interested = manager.sessionsInterestedIn('cid1');
      expect(interested.length, equals(1));
      expect(interested.first, same(session1));
    });

    test('recordHave updates all interested sessions', () {
      final manager = BitswapSessionManager();
      final session = manager.createSession();
      session.addInterest('cid1');

      manager.recordHave('peerA', 'cid1');

      final targets = session.targetPeersForWant('cid1');
      expect(targets.contains('peerA'), isTrue);
    });

    test('recordDontHave updates all interested sessions', () {
      final manager = BitswapSessionManager();
      final session = manager.createSession();
      session.addInterest('cid1');
      manager.recordHave('peerA', 'cid1');
      manager.recordHave('peerB', 'cid1');
      manager.recordDontHave('peerA', 'cid1');

      final targets = session.targetPeersForWant('cid1');
      expect(targets.contains('peerA'), isFalse);
      expect(targets.contains('peerB'), isTrue);
    });

    test('markPeerHasAll updates session', () {
      final manager = BitswapSessionManager();
      final session = manager.createSession();
      session.addPeer('peerA');

      manager.markPeerHasAll(session.id, 'peerA');

      expect(session.haveAllPeers.contains('peerA'), isTrue);
    });

    test('stop closes all sessions', () {
      final manager = BitswapSessionManager();
      final session = manager.createSession();
      manager.start();
      manager.stop();
      expect(session.isActive, isFalse);
      expect(manager.activeSessionCount, equals(0));
    });
  });
}
