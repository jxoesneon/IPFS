import 'dart:async';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:grpc/grpc.dart';
import 'package:dart_ipfs/src/services/block_store_service.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/proto/generated/core/block.pb.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';
import 'package:dart_ipfs/src/proto/generated/core/cid.pb.dart';
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart';

import 'block_store_service_test.mocks.dart';

@GenerateNiceMocks([MockSpec<BlockStore>(), MockSpec<ServiceCall>()])
void main() {
  late BlockStoreService service;
  late MockBlockStore mockBlockStore;
  late MockServiceCall mockCall;

  setUp(() {
    mockBlockStore = MockBlockStore();
    mockCall = MockServiceCall();
    service = BlockStoreService(mockBlockStore);
  });

  group('BlockStoreService', () {
    test('addBlock delegates to blockstore', () async {
      final cid = CID.decode('QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn');
      final blockProto = BlockProto()
        ..cid = cid.toProto()
        ..data = [1, 2, 3];
      final response = AddBlockResponse()..success = true;
      when(mockBlockStore.putBlock(any)).thenAnswer((_) async => response);

      final result = await service.addBlock(mockCall, blockProto);
      expect(result.success, isTrue);
    });

    test('getBlock delegates to blockstore', () async {
      final cidProto = IPFSCIDProto()..multihash = [1, 2, 3];
      final response = GetBlockResponse()
        ..found = true
        ..block = (BlockProto()..data = [4, 5, 6]);
      when(mockBlockStore.getBlock(any)).thenAnswer((_) async => response);

      final result = await service.getBlock(mockCall, cidProto);
      expect(result.found, isTrue);
      expect(result.block.data, equals([4, 5, 6]));
    });

    test('removeBlock delegates to blockstore', () async {
      final cidProto = IPFSCIDProto()..multihash = [1, 2, 3];
      final response = RemoveBlockResponse()..success = true;
      when(mockBlockStore.removeBlock(any)).thenAnswer((_) async => response);

      final result = await service.removeBlock(mockCall, cidProto);
      expect(result.success, isTrue);
    });

    test('getAllBlocks delegates to blockstore', () async {
      final cid = CID.decode('QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn');
      final block = Block(cid: cid, data: Uint8List.fromList([1, 2, 3]));
      when(mockBlockStore.getAllBlocks()).thenAnswer((_) async => [block]);

      final stream = service.getAllBlocks(mockCall, Empty());
      final result = await stream.toList();
      expect(result.length, equals(1));
      expect(result.first.data, equals([1, 2, 3]));
    });
  });
}
