import 'package:test/test.dart';
import 'package:dart_ipfs/src/core/data_structures/node.dart';
import 'package:dart_ipfs/src/core/data_structures/node_type.dart';

void main() {
  group('Node Tests', () {
    test('Create NodeLink', () {
      final link = NodeLink(
        name: 'test',
        cid: mockCid,
        size: Int64(100),
      );
      expect(link.name, equals('test'));
    });

    test('Node type conversion', () {
      final nodeType = NodeType.file;
      expect(nodeType.toProto(), equals(1));
      expect(NodeType.fromProto(1), equals(NodeType.file));
    });
  });
}
