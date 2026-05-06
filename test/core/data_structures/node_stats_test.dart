import 'package:test/test.dart';
import 'package:dart_ipfs/src/core/data_structures/node_stats.dart';
import 'package:dart_ipfs/src/proto/generated/core/node_stats.pb.dart' as proto;
import 'package:fixnum/fixnum.dart';

void main() {
  group('NodeStats', () {
    final stats = NodeStats(
      numBlocks: 10,
      datastoreSize: 1024,
      numConnectedPeers: 5,
      bandwidthSent: 512,
      bandwidthReceived: 256,
    );

    test('toProto and fromProto', () {
      final pb = stats.toProto();
      expect(pb.numBlocks, equals(10));
      expect(pb.datastoreSize, equals(Int64(1024)));

      final fromPb = NodeStats.fromProto(pb);
      expect(fromPb.numBlocks, equals(10));
      expect(fromPb.datastoreSize, equals(1024));
    });

    test('fromJson', () {
      final json = {
        'numBlocks': 10,
        'datastoreSize': 1024,
        'numConnectedPeers': 5,
        'bandwidthSent': 512,
        'bandwidthReceived': 256,
      };
      final fromJson = NodeStats.fromJson(json);
      expect(fromJson.numBlocks, equals(10));
    });

    test('toString', () {
      expect(stats.toString(), contains('numBlocks: 10'));
    });
  });
}
