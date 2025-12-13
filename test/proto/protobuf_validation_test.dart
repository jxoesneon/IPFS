// Simplified validation tests for key protobuf classes
import 'package:test/test.dart';
import 'package:dart_ipfs/src/proto/generated/bitswap/bitswap.pb.dart'
    as bitswap;
import 'package:dart_ipfs/src/proto/generated/graphsync/graphsync.pb.dart'
    as graphsync;
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart' as unixfs;
import 'package:dart_ipfs/src/proto/generated/base_messages.pb.dart';

void main() {
  group('Protobuf Validation', () {
    test('Bitswap protobuf message exists and instantiable', () {
      final msg = bitswap.Message();
      expect(msg, isNotNull);
      expect(msg, isA<bitswap.Message>());
    });

    test('Graphsync protobuf message exists and instantiable', () {
      final msg = graphsync.GraphsyncMessage();
      expect(msg, isNotNull);
      expect(msg.requests, isEmpty);
      expect(msg.responses, isEmpty);
    });

    test('UnixFS protobuf data exists and instantiable', () {
      final data = unixfs.Data();
      expect(data, isNotNull);
      expect(data, isA<unixfs.Data>());
    });

    test('Base messages protobuf exists and instantiable', () {
      final msg = IPFSMessage();
      expect(msg, isNotNull);
      expect(msg.protocolId, isEmpty);
    });

    test('Protobuf serialization/deserialization works', () {
      final original = graphsync.GraphsyncMessage();
      final bytes = original.writeToBuffer();
      final decoded = graphsync.GraphsyncMessage.fromBuffer(bytes);

      expect(bytes, isNotEmpty);
      expect(decoded, isNotNull);
    });
  });
}
