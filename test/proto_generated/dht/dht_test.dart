// Auto-generated proto coverage tests. Do not hand-edit.

import 'package:test/test.dart';
import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:dart_ipfs/src/proto/generated/dht/dht.pb.dart';

void main() {
  group('DHTPeer', () {
    test('round-trips and accessors work', () {
      final original = DHTPeer(id: const [0, 1, 2], addrs: ['a']);
      expect(original.id, const [0, 1, 2]);
      expect(original.addrs, ['a']);
      original.hasId();
      original.clearId();
      original.addrs.clear();
      expect(DHTPeer.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = DHTPeer.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) {});
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(DHTPeer.fromJson(json), isNotNull);
    });
  });

  group('Record', () {
    test('round-trips and accessors work', () {
      final original = Record(
        key: const [0, 1, 2],
        value: const [0, 1, 2],
        publisher: DHTPeer.create(),
        sequence: $fixnum.Int64(1),
      );
      expect(original.key, const [0, 1, 2]);
      expect(original.value, const [0, 1, 2]);
      expect(original.publisher, isNotNull);
      expect(original.sequence, $fixnum.Int64(1));
      original.hasKey();
      original.clearKey();
      original.hasValue();
      original.clearValue();
      original.hasPublisher();
      original.clearPublisher();
      original.hasSequence();
      original.clearSequence();
      original.ensurePublisher();
      expect(Record.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = Record.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) {});
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(Record.fromJson(json), isNotNull);
    });
  });

  group('FindProvidersRequest', () {
    test('round-trips and accessors work', () {
      final original = FindProvidersRequest(key: const [0, 1, 2], count: 1);
      expect(original.key, const [0, 1, 2]);
      expect(original.count, 1);
      original.hasKey();
      original.clearKey();
      original.hasCount();
      original.clearCount();
      expect(FindProvidersRequest.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = FindProvidersRequest.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) {});
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(FindProvidersRequest.fromJson(json), isNotNull);
    });
  });

  group('FindProvidersResponse', () {
    test('round-trips and accessors work', () {
      final original = FindProvidersResponse(
        providers: [DHTPeer.create()],
        closerPeers: true,
      );
      expect(original.providers.length, 1);
      expect(original.closerPeers, true);
      original.providers.clear();
      original.hasCloserPeers();
      original.clearCloserPeers();
      expect(FindProvidersResponse.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = FindProvidersResponse.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) {});
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(FindProvidersResponse.fromJson(json), isNotNull);
    });
  });

  group('ProvideRequest', () {
    test('round-trips and accessors work', () {
      final original = ProvideRequest(
        key: const [0, 1, 2],
        provider: DHTPeer.create(),
      );
      expect(original.key, const [0, 1, 2]);
      expect(original.provider, isNotNull);
      original.hasKey();
      original.clearKey();
      original.hasProvider();
      original.clearProvider();
      original.ensureProvider();
      expect(ProvideRequest.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = ProvideRequest.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) {});
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(ProvideRequest.fromJson(json), isNotNull);
    });
  });

  group('ProvideResponse', () {
    test('round-trips and accessors work', () {
      final original = ProvideResponse(success: true);
      expect(original.success, true);
      original.hasSuccess();
      original.clearSuccess();
      expect(ProvideResponse.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = ProvideResponse.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) {});
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(ProvideResponse.fromJson(json), isNotNull);
    });
  });

  group('FindValueRequest', () {
    test('round-trips and accessors work', () {
      final original = FindValueRequest(key: const [0, 1, 2]);
      expect(original.key, const [0, 1, 2]);
      original.hasKey();
      original.clearKey();
      expect(FindValueRequest.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = FindValueRequest.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) {});
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(FindValueRequest.fromJson(json), isNotNull);
    });
  });

  group('FindValueResponse', () {
    test('round-trips and accessors work', () {
      final original = FindValueResponse(
        value: const [0, 1, 2],
        closerPeers: [DHTPeer.create()],
      );
      expect(original.value, const [0, 1, 2]);
      expect(original.closerPeers.length, 1);
      original.hasValue();
      original.clearValue();
      original.closerPeers.clear();
      expect(FindValueResponse.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = FindValueResponse.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) {});
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(FindValueResponse.fromJson(json), isNotNull);
    });
  });

  group('PutValueRequest', () {
    test('round-trips and accessors work', () {
      final original = PutValueRequest(
        key: const [0, 1, 2],
        value: const [0, 1, 2],
      );
      expect(original.key, const [0, 1, 2]);
      expect(original.value, const [0, 1, 2]);
      original.hasKey();
      original.clearKey();
      original.hasValue();
      original.clearValue();
      expect(PutValueRequest.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = PutValueRequest.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) {});
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(PutValueRequest.fromJson(json), isNotNull);
    });
  });

  group('PutValueResponse', () {
    test('round-trips and accessors work', () {
      final original = PutValueResponse(success: true);
      expect(original.success, true);
      original.hasSuccess();
      original.clearSuccess();
      expect(PutValueResponse.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = PutValueResponse.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) {});
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(PutValueResponse.fromJson(json), isNotNull);
    });
  });

  group('FindNodeRequest', () {
    test('round-trips and accessors work', () {
      final original = FindNodeRequest(peerId: const [0, 1, 2]);
      expect(original.peerId, const [0, 1, 2]);
      original.hasPeerId();
      original.clearPeerId();
      expect(FindNodeRequest.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = FindNodeRequest.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) {});
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(FindNodeRequest.fromJson(json), isNotNull);
    });
  });

  group('FindNodeResponse', () {
    test('round-trips and accessors work', () {
      final original = FindNodeResponse(closerPeers: [DHTPeer.create()]);
      expect(original.closerPeers.length, 1);
      original.closerPeers.clear();
      expect(FindNodeResponse.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = FindNodeResponse.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) {});
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(FindNodeResponse.fromJson(json), isNotNull);
    });
  });
}
