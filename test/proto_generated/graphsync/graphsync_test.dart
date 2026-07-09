// Auto-generated proto coverage tests. Do not hand-edit.

import 'package:test/test.dart';
import 'package:dart_ipfs/src/proto/generated/graphsync/graphsync.pbenum.dart';
import 'package:dart_ipfs/src/proto/generated/graphsync/graphsync.pb.dart';

void main() {
  group('GraphsyncMessage', () {
    test('round-trips and accessors work', () {
      final original = GraphsyncMessage(requests: [GraphsyncRequest.create()], responses: [GraphsyncResponse.create()], blocks: [Block.create()], extensions: [MapEntry('k', [0, 1])]);
      expect(original.requests.length, 1);
      expect(original.responses.length, 1);
      expect(original.blocks.length, 1);
      expect(original.extensions['k'], isNotNull);
      expect(original.extensions.length, 1);
      original.requests.clear();
      original.responses.clear();
      original.blocks.clear();
      original.extensions.clear();
      expect(GraphsyncMessage.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = GraphsyncMessage.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(GraphsyncMessage.fromJson(json), isNotNull);
    });
  });

  group('GraphsyncRequest', () {
    test('round-trips and accessors work', () {
      final original = GraphsyncRequest(id: 1, root: const [0, 1, 2], selector: const [0, 1, 2], priority: 1, extensions: [MapEntry('k', [0, 1])], cancel: true, pause: true, unpause: true);
      expect(original.id, 1);
      expect(original.root, const [0, 1, 2]);
      expect(original.selector, const [0, 1, 2]);
      expect(original.priority, 1);
      expect(original.extensions['k'], isNotNull);
      expect(original.extensions.length, 1);
      expect(original.cancel, true);
      expect(original.pause, true);
      expect(original.unpause, true);
      original.hasId();
      original.clearId();
      original.hasRoot();
      original.clearRoot();
      original.hasSelector();
      original.clearSelector();
      original.hasPriority();
      original.clearPriority();
      original.extensions.clear();
      original.hasCancel();
      original.clearCancel();
      original.hasPause();
      original.clearPause();
      original.hasUnpause();
      original.clearUnpause();
      expect(GraphsyncRequest.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = GraphsyncRequest.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(GraphsyncRequest.fromJson(json), isNotNull);
    });
  });

  group('GraphsyncResponse', () {
    test('round-trips and accessors work', () {
      final original = GraphsyncResponse(id: 1, status: ResponseStatus.values.first, extensions: [MapEntry('k', [0, 1])], metadata: [MapEntry('k', 'v')]);
      expect(original.id, 1);
      expect(original.status, isNotNull);
      expect(original.extensions['k'], isNotNull);
      expect(original.extensions.length, 1);
      expect(original.metadata['k'], isNotNull);
      expect(original.metadata.length, 1);
      original.hasId();
      original.clearId();
      original.hasStatus();
      original.clearStatus();
      original.extensions.clear();
      original.metadata.clear();
      expect(GraphsyncResponse.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = GraphsyncResponse.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(GraphsyncResponse.fromJson(json), isNotNull);
    });
  });

  group('Block', () {
    test('round-trips and accessors work', () {
      final original = Block(prefix: const [0, 1, 2], data: const [0, 1, 2]);
      expect(original.prefix, const [0, 1, 2]);
      expect(original.data, const [0, 1, 2]);
      original.hasPrefix();
      original.clearPrefix();
      original.hasData();
      original.clearData();
      expect(Block.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = Block.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(Block.fromJson(json), isNotNull);
    });
  });

}
