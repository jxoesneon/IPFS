import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:dart_ipfs/src/core/interfaces/block_data.dart';
import 'package:dart_ipfs/src/core/cid.dart';

class MockBlockData extends BlockData {
  @override
  final Uint8List data;
  @override
  final CID cid;

  MockBlockData(this.cid, this.data);
}

void main() {
  group('BlockData', () {
    test('toBytes and size', () {
      final cid = CID.decode('QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn');
      final data = Uint8List.fromList([1, 2, 3]);
      final block = MockBlockData(cid, data);

      expect(block.size, equals(3));
      final bytes = block.toBytes();
      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(3));
    });
  });
}
