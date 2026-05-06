import 'dart:async';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/data_structures/pin_manager.dart';
import 'package:dart_ipfs/src/core/di/service_container.dart';
import 'package:dart_ipfs/src/core/ipfs_node/content_manager.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/core/ipfs_node/datastore_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_manager.dart';
import 'package:dart_ipfs/src/core/ipfs_node/protocol_manager.dart';
import 'package:dart_ipfs/src/core/ipfs_node/pubsub_handler.dart';
import 'package:dart_ipfs/src/protocols/bitswap/bitswap_handler.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_handler.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'managers_coverage_test.mocks.dart';

import 'package:dart_ipfs/src/proto/generated/core/cid.pb.dart';
import 'package:dart_ipfs/src/proto/generated/core/pin.pb.dart';

@GenerateNiceMocks([
  MockSpec<DatastoreHandler>(),
  MockSpec<BitswapHandler>(),
  MockSpec<DHTHandler>(),
  MockSpec<BlockStore>(),
  MockSpec<PubSubHandler>(),
])
class FakePinManager extends Fake implements PinManager {
  @override
  Future<bool> pinBlock(IPFSCIDProto cidProto, PinTypeProto type) async {
    throw Exception('Pin fail');
  }

  @override
  Future<bool> unpinBlock(IPFSCIDProto cid) async {
    throw Exception('Unpin fail');
  }
}

void main() {
  late ServiceContainer container;
  late MockDatastoreHandler mockDatastore;
  late MockBitswapHandler mockBitswap;
  late MockDHTHandler mockDht;
  late MockBlockStore mockBlockStore;
  late MockPubSubHandler mockPubSub;

  setUp(() {
    container = ServiceContainer();
    mockDatastore = MockDatastoreHandler();
    mockBitswap = MockBitswapHandler();
    mockDht = MockDHTHandler();
    mockBlockStore = MockBlockStore();
    mockPubSub = MockPubSubHandler();

    when(mockBlockStore.pinManager).thenReturn(FakePinManager());

    container.registerSingleton<DatastoreHandler>(mockDatastore);
    container.registerSingleton<BitswapHandler>(mockBitswap);
    container.registerSingleton<DHTHandler>(mockDht);
    container.registerSingleton<BlockStore>(mockBlockStore);
    container.registerSingleton<PubSubHandler>(mockPubSub);
  });

  group('ContentManager', () {
    late ContentManager contentManager;
    late StreamController<String> contentController;

    setUp(() {
      contentController = StreamController<String>.broadcast();
      contentManager = ContentManager(
        datastoreHandler: mockDatastore,
        newContentController: contentController,
      );
    });

    test('addFile adds block to datastore', () async {
      final data = Uint8List.fromList([1, 2, 3]);
      final cid = await contentManager.addFile(data);

      verify(mockDatastore.putBlock(any)).called(1);
      expect(cid, isNotEmpty);
    });

    test('addFileStream handles errors', () async {
      when(mockDatastore.putBlock(any)).thenThrow(Exception('Datastore error'));
      final stream = Stream.fromIterable([
        [1, 2, 3],
      ]);
      expect(() => contentManager.addFileStream(stream), throwsException);
    });

    test('addDirectory handles nested directories', () async {
      final directoryContent = {
        'file.txt': Uint8List.fromList([1, 2, 3]),
        'subdir': {
          'subfile.txt': Uint8List.fromList([4, 5, 6]),
        },
      };

      final cid = await contentManager.addDirectory(directoryContent);
      expect(cid, isNotEmpty);
      // It should put at least 3 blocks: file.txt, subfile.txt, subdir (pb node), rootdir (pb node)
      verify(mockDatastore.putBlock(any)).called(greaterThan(1));
    });

    test('get gateway fallback and internal path resolution errors', () async {
      final cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';

      // Gateway Mode custom to trigger error path inside gateway retrieval (though HttpGatewayClient handles its own errors usually)
      final gatewayData = await contentManager.get(
        cid,
        gatewayMode: GatewayMode.custom,
        customGatewayUrl: 'http://localhost:12345/ipfs',
      );
      expect(gatewayData, isNull);

      // To hit the outer catch block of get(), we make the datastore throw an exception
      when(mockDatastore.getBlock(cid)).thenThrow(Exception('Get block fail'));

      final data = await contentManager.get(cid);
      expect(data, isNull);
    });

    test('ls handles non-directories and missing blocks', () async {
      final cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';

      when(mockDatastore.getBlock(cid)).thenAnswer((_) async => null);
      when(mockBitswap.wantBlock(cid)).thenAnswer((_) async => null);

      final result1 = await contentManager.ls(cid);
      expect(result1, isEmpty); // Returns empty list on error

      final rawBlock = Block(
        cid: CID.decode(cid),
        data: Uint8List.fromList([1, 2, 3]),
      );
      when(mockDatastore.getBlock(cid)).thenAnswer((_) async => rawBlock);

      final result2 = await contentManager.ls(cid);
      expect(
        result2,
        isEmpty,
      ); // Block is not a valid MerkleDAGNode / directory
    });

    test('pin errors', () async {
      final cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      // Mocking blockstore for pin failure
      when(mockBlockStore.hasBlock(any)).thenThrow(Exception('Pin fail'));
      expect(() => contentManager.pin(cid), throwsA(anything));
    });

    test('unpin errors', () async {
      final cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      when(mockBlockStore.hasBlock(any)).thenThrow(Exception('Unpin fail'));
      final success = await contentManager.unpin(cid);
      expect(success, isFalse);
    });

    test('importCAR and exportCAR errors', () async {
      final cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      when(mockDatastore.importCAR(any)).thenThrow(Exception('import fail'));
      when(mockDatastore.exportCAR(any)).thenThrow(Exception('export fail'));

      expect(() => contentManager.importCAR(Uint8List(0)), throwsException);
      expect(() => contentManager.exportCAR(cid), throwsException);
    });
    // ...
  });

  group('NetworkManager', () {
    late NetworkManager networkManager;

    setUp(() {
      networkManager = NetworkManager();
    });
    // ...
  });

  group('ProtocolManager', () {
    late ProtocolManager protocolManager;

    setUp(() {
      protocolManager = ProtocolManager();
    });
    // ...
  });
}
