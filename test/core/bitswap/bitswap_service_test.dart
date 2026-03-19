import 'dart:typed_data';

import 'package:dart_ipfs/src/core/bitswap/bitswap_service.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/proto/generated/bitswap/bitswap.pb.dart' as proto;
import 'package:test/test.dart';

void main() {
  group('BitswapService', () {
    late BitswapService service;

    setUp(() {
      service = BitswapService();
    });

    test('convertToProtoBlock converts Block to proto', () async {
      final data = Uint8List.fromList([1, 2, 3, 4]);
      final block = await Block.fromData(data);

      final protoBlock = service.convertToProtoBlock(block);

      expect(protoBlock.data, equals(data));
      expect(protoBlock.prefix, equals(block.cid.toBytes()));
    });

    test('convertFromProtoBlock converts proto to Block', () async {
      final data = Uint8List.fromList([5, 6, 7, 8]);
      final protoBlock = proto.Message_Block()..data = data;

      final block = await service.convertFromProtoBlock(protoBlock);

      expect(block.data, equals(data));
      // CID should be automatically computed from data in fromBitswapProto
      expect(block.cid, isNotNull);
    });
  });
}
