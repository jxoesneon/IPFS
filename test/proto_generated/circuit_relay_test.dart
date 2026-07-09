// Auto-generated proto coverage tests. Do not hand-edit.

import 'package:test/test.dart';
import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:dart_ipfs/src/proto/generated/circuit_relay.pbenum.dart';
import 'package:dart_ipfs/src/proto/generated/circuit_relay.pb.dart';

void main() {
  group('HopMessage', () {
    test('round-trips and accessors work', () {
      final original = HopMessage(type: HopMessage_Type.values.first, peer: Peer.create(), reservation: Reservation.create(), limit: Limit.create(), status: Status.values.first);
      expect(original.type, isNotNull);
      expect(original.peer, isNotNull);
      expect(original.reservation, isNotNull);
      expect(original.limit, isNotNull);
      expect(original.status, isNotNull);
      original.hasType();
      original.clearType();
      original.hasPeer();
      original.clearPeer();
      original.hasReservation();
      original.clearReservation();
      original.hasLimit();
      original.clearLimit();
      original.hasStatus();
      original.clearStatus();
      original.ensureReservation();
      original.ensureLimit();
      original.ensurePeer();
      expect(HopMessage.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = HopMessage.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(HopMessage.fromJson(json), isNotNull);
    });
  });

  group('StopMessage', () {
    test('round-trips and accessors work', () {
      final original = StopMessage(type: StopMessage_Type.values.first, peer: Peer.create(), limit: Limit.create(), status: Status.values.first);
      expect(original.type, isNotNull);
      expect(original.peer, isNotNull);
      expect(original.limit, isNotNull);
      expect(original.status, isNotNull);
      original.hasType();
      original.clearType();
      original.hasPeer();
      original.clearPeer();
      original.hasLimit();
      original.clearLimit();
      original.hasStatus();
      original.clearStatus();
      original.ensureLimit();
      original.ensurePeer();
      expect(StopMessage.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = StopMessage.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(StopMessage.fromJson(json), isNotNull);
    });
  });

  group('Peer', () {
    test('round-trips and accessors work', () {
      final original = Peer(id: const [0, 1, 2], addrs: [[0, 1]]);
      expect(original.id, const [0, 1, 2]);
      expect(original.addrs, [[0, 1]]);
      original.hasId();
      original.clearId();
      original.addrs.clear();
      expect(Peer.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = Peer.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(Peer.fromJson(json), isNotNull);
    });
  });

  group('Reservation', () {
    test('round-trips and accessors work', () {
      final original = Reservation(expire: $fixnum.Int64(1), limitDuration: $fixnum.Int64(1), limitData: $fixnum.Int64(1), addrs: [[0, 1]]);
      expect(original.expire, $fixnum.Int64(1));
      expect(original.limitDuration, $fixnum.Int64(1));
      expect(original.limitData, $fixnum.Int64(1));
      expect(original.addrs, [[0, 1]]);
      original.hasExpire();
      original.clearExpire();
      original.hasLimitDuration();
      original.clearLimitDuration();
      original.hasLimitData();
      original.clearLimitData();
      original.addrs.clear();
      expect(Reservation.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = Reservation.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(Reservation.fromJson(json), isNotNull);
    });
  });

  group('Limit', () {
    test('round-trips and accessors work', () {
      final original = Limit(duration: $fixnum.Int64(1), data: $fixnum.Int64(1));
      expect(original.duration, $fixnum.Int64(1));
      expect(original.data, $fixnum.Int64(1));
      original.hasDuration();
      original.clearDuration();
      original.hasData();
      original.clearData();
      expect(Limit.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = Limit.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(Limit.fromJson(json), isNotNull);
    });
  });

}
