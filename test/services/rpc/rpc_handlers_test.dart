import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:mirrors' as mirrors;
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/data_structures/car.dart' show CarReader;
import 'package:dart_ipfs/src/core/data_structures/link.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/core/ipld/codecs/standard_codecs.dart';
import 'package:dart_ipfs/src/core/storage/memory_datastore.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart' as dag_pb;
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart'
    as unixfs_pb;
import 'package:dart_ipfs/src/protocols/bitswap/bitswap_handler.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_client.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_handler.dart';
import 'package:dart_ipfs/src/protocols/dht/provide_result.dart';
import 'package:dart_ipfs/src/protocols/pubsub/pubsub_message.dart';
import 'package:dart_ipfs/src/services/rpc/rpc_handlers.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:dart_ipfs/src/utils/base58.dart';
import 'package:dart_ipfs/src/utils/car_writer.dart';
import 'package:dart_ipfs_core/dart_ipfs_core.dart' as core;
import 'package:fixnum/fixnum.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../../fakes/fake_router.dart';
import 'rpc_handlers_test.mocks.dart';

core.CID coreCid(CID cid) => cid;

/// A [DHTHandler] whose on-demand provide surface always reports a saturated
/// queue and a failing engine, for exercising the RPC error branches.
class _UnhappyDHTHandler extends DHTHandler {
  // DHTHandler's router parameter is a private field formal and cannot be a
  // super-parameter, so this constructor forwards explicitly.
  // ignore: use_super_parameters
  _UnhappyDHTHandler(
    IPFSConfig config,
    RouterInterface router,
    NetworkHandler networkHandler, {
    MemoryDatastore? storage,
  }) : super(config, router, networkHandler, storage: storage);

  @override
  int? enqueueProvide(
    CID cid, {
    bool recursive = false,
    Duration? timeout,
    BlockStore? blockStore,
    bool recordMetrics = true,
  }) => null;

  @override
  Future<ProvideResult> provideDetailed(
    CID cid, {
    bool recursive = false,
    Duration? timeout,
    BlockStore? blockStore,
    bool recordMetrics = true,
  }) {
    throw StateError('simulated provide failure');
  }
}

@GenerateNiceMocks([
  MockSpec<IPFSNode>(),
  MockSpec<BlockStore>(),
  MockSpec<DHTClient>(),
])
void main() {
  late RPCHandlers handlers;
  late MockIPFSNode mockNode;
  late MockBlockStore mockBlockStore;
  late MockDHTClient mockDHTClient;

  setUp(() {
    mockNode = MockIPFSNode();
    mockBlockStore = MockBlockStore();
    mockDHTClient = MockDHTClient();

    when(mockNode.blockStore).thenReturn(mockBlockStore);
    when(mockNode.dhtClient).thenReturn(mockDHTClient);
    when(mockNode.peerId).thenReturn('QmPeer');

    handlers = RPCHandlers(mockNode);
  });

  group('RPCHandlers', () {
    test('handleVersion', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v0/version'),
      );
      final response = await handlers.handleVersion(request);
      expect(response.statusCode, equals(200));
      final body = json.decode(await response.readAsString());
      expect(body['Version'], contains('dart_ipfs'));
    });

    test('handleId', () async {
      when(mockNode.publicKey).thenAnswer((_) async => 'key');
      when(mockNode.addresses).thenReturn(['addr']);

      final request = Request('POST', Uri.parse('http://localhost/api/v0/id'));
      final response = await handlers.handleId(request);
      expect(response.statusCode, equals(200));
    });

    test('handleCat', () async {
      final cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      when(
        mockNode.get(cid, path: ''),
      ).thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));

      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/cat?arg=$cid'),
      );
      final response = await handlers.handleCat(request);
      expect(response.statusCode, equals(200));
      expect(
        await response.read().expand((i) => i).toList(),
        equals([1, 2, 3]),
      );
    });

    test('handleCat resolves cid/path sub-paths like Kubo', () async {
      final cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      when(
        mockNode.get(cid, path: 'dir/file.txt'),
      ).thenAnswer((_) async => Uint8List.fromList([9, 9]));

      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/cat?arg=$cid/dir/file.txt'),
      );
      final response = await handlers.handleCat(request);
      expect(response.statusCode, equals(200));
      expect(await response.read().expand((i) => i).toList(), equals([9, 9]));
    });

    test('handleCat normalizes /ipfs/ prefixed paths', () async {
      final cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      when(
        mockNode.get(cid, path: 'a.txt'),
      ).thenAnswer((_) async => Uint8List.fromList([7]));

      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/cat?arg=/ipfs/$cid/a.txt'),
      );
      final response = await handlers.handleCat(request);
      expect(response.statusCode, equals(200));
    });

    test('handleCat normalizes ipfs/ prefixed paths without leading slash',
        () async {
      final cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      when(
        mockNode.get(cid, path: 'a.txt'),
      ).thenAnswer((_) async => Uint8List.fromList([8]));

      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/cat?arg=ipfs/$cid/a.txt'),
      );
      final response = await handlers.handleCat(request);
      expect(response.statusCode, equals(200));
    });

    test('handleCat normalizes bare leading-slash paths', () async {
      final cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      when(
        mockNode.get(cid, path: 'a.txt'),
      ).thenAnswer((_) async => Uint8List.fromList([8]));

      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/cat?arg=/$cid/a.txt'),
      );
      final response = await handlers.handleCat(request);
      expect(response.statusCode, equals(200));
    });

    test('handleCat returns 404 when the path does not resolve', () async {
      final cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      when(mockNode.get(cid, path: 'missing')).thenAnswer((_) async => null);

      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/cat?arg=$cid/missing'),
      );
      final response = await handlers.handleCat(request);
      expect(response.statusCode, equals(404));
    });

    test('handleSwarmPeers', () async {
      when(mockNode.connectedPeers).thenAnswer((_) async => ['p1']);
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/swarm/peers'),
      );
      final response = await handlers.handleSwarmPeers(request);
      expect(response.statusCode, equals(200));
    });

    test('handleBlockGet success', () async {
      final cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      final block = Block(cid: CID.decode(cid), data: Uint8List.fromList([1]));

      final pbResp = GetBlockResponse()
        ..found = true
        ..block = block.toProto();
      when(mockBlockStore.getBlock(cid)).thenAnswer((_) async => pbResp);

      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/block/get?arg=$cid'),
      );
      final response = await handlers.handleBlockGet(request);
      expect(response.statusCode, equals(200));
    });

    test('handleDhtProvide', () async {
      final cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/dht/provide?arg=$cid'),
      );
      final response = await handlers.handleDhtProvide(request);
      expect(response.statusCode, equals(200));
      final body = json.decode(await response.readAsString());
      // Detailed response shape (REPROVIDE_SPEC §4.6.1).
      expect(body['ID'], equals('QmPeer'));
      expect(body['CID'], equals(cid));
      expect(body['Success'], isTrue);
      expect(body['Queued'], isFalse);
      expect(body['Errors'], isA<List<dynamic>>());
      verify(mockDHTClient.addProvider(cid, 'QmPeer')).called(1);
    });

    test('handleDhtProvide rejects invalid CID', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/dht/provide?arg=not-a-cid'),
      );
      final response = await handlers.handleDhtProvide(request);
      expect(response.statusCode, equals(400));
    });

    group('handleDhtProvide with a concrete DHTHandler', () {
      late DHTHandler realHandler;

      setUp(() async {
        final router = FakeRouter();
        final nodeConfig = IPFSConfig(
          dht: const DHTConfig(requestTimeout: Duration(milliseconds: 100)),
        );
        final networkHandler = NetworkHandler(nodeConfig, router: router);
        final storage = MemoryDatastore();
        await storage.init();
        realHandler = DHTHandler(
          nodeConfig,
          router,
          networkHandler,
          storage: storage,
        );
        await realHandler.dhtClient.initialize();
        when(mockNode.dhtHandler).thenReturn(realHandler);
      });

      tearDown(() async {
        await realHandler.stop();
      });

      test('returns detailed success/failure counts', () async {
        final peer = PeerId(
          value: Uint8List.fromList(List.generate(32, (i) => i + 1)),
        );
        await realHandler.dhtClient.kademliaRoutingTable.addPeer(peer, peer);

        final cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/v0/dht/provide?arg=$cid'),
        );
        final response = await handlers.handleDhtProvide(request);
        expect(response.statusCode, equals(200));

        final body = json.decode(await response.readAsString());
        expect(body['ID'], equals('QmPeer'));
        expect(body['CID'], equals(cid));
        expect(body['Success'], isTrue);
        expect(body['Attempts'], greaterThan(0));
        expect(body['Successes'], equals(body['Attempts']));
        expect(body['Failures'], equals(0));
        expect(body['Queued'], isFalse);
      });

      test('queue=true returns 202 Accepted with a queue position', () async {
        final cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/v0/dht/provide?arg=$cid&queue=true'),
        );
        final response = await handlers.handleDhtProvide(request);
        expect(response.statusCode, equals(202));

        final body = json.decode(await response.readAsString());
        expect(body['CID'], equals(cid));
        expect(body['Queued'], isTrue);
        expect(body['QueuePosition'], equals(1));
      });

      test('once=false behaves like queue=true', () async {
        final cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/v0/dht/provide?arg=$cid&once=false'),
        );
        final response = await handlers.handleDhtProvide(request);
        expect(response.statusCode, equals(202));

        final body = json.decode(await response.readAsString());
        expect(body['Queued'], isTrue);
      });

      test('timeout aborts remaining peer attempts', () async {
        final peer = PeerId(
          value: Uint8List.fromList(List.generate(32, (i) => i + 2)),
        );
        await realHandler.dhtClient.kademliaRoutingTable.addPeer(peer, peer);

        final cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/v0/dht/provide?arg=$cid&timeout=0s'),
        );
        final response = await handlers.handleDhtProvide(request);
        expect(response.statusCode, equals(200));

        final body = json.decode(await response.readAsString());
        expect(body['Attempts'], equals(0));
        expect((body['Errors'] as List).join(' '), contains('timeout'));
      });

      test('recursive provides all local DAG blocks', () async {
        final peer = PeerId(
          value: Uint8List.fromList(List.generate(32, (i) => i + 3)),
        );
        await realHandler.dhtClient.kademliaRoutingTable.addPeer(peer, peer);

        // Build a small dag-pb DAG in a real blockstore.
        final tempDir = await Directory.systemTemp.createTemp(
          'dht_provide_rpc_test_',
        );
        final realBlockStore = BlockStore(path: tempDir.path);
        await realBlockStore.start();
        addTearDown(() async {
          await realBlockStore.stop();
          await tempDir.delete(recursive: true);
        });
        when(mockNode.blockStore).thenReturn(realBlockStore);

        final childBlock = await Block.fromData(Uint8List.fromList([9, 8, 7]));
        await realBlockStore.putBlock(childBlock);
        final pbNode = dag_pb.PBNode(
          links: [
            dag_pb.PBLink(
              name: 'child',
              hash: childBlock.cid.toBytes(),
              size: Int64(childBlock.data.length),
            ),
          ],
        );
        final rootData = pbNode.writeToBuffer();
        final rootCid = await CID.fromContent(rootData, codec: 'dag-pb');
        await realBlockStore.putBlock(
          Block(cid: rootCid, data: rootData, format: 'dag-pb'),
        );

        final cid = rootCid.encode();
        final request = Request(
          'POST',
          Uri.parse(
            'http://localhost/api/v0/dht/provide?arg=$cid&recursive=true',
          ),
        );
        final response = await handlers.handleDhtProvide(request);
        expect(response.statusCode, equals(200));

        final body = json.decode(await response.readAsString());
        expect(body['Success'], isTrue);
        // Both the root and the linked child were announced.
        expect(body['Attempts'], equals(2));
        expect(
          realHandler.getLocalProvidersForCid(childBlock.cid.toString()),
          isNotEmpty,
        );
      });

      test('queue=true returns 503 when the provide queue is full', () async {
        final router = FakeRouter();
        final nodeConfig = IPFSConfig(
          dht: const DHTConfig(requestTimeout: Duration(milliseconds: 100)),
        );
        final storage = MemoryDatastore();
        await storage.init();
        final unhappy = _UnhappyDHTHandler(
          nodeConfig,
          router,
          NetworkHandler(nodeConfig, router: router),
          storage: storage,
        );
        addTearDown(() async {
          await unhappy.stop();
          await storage.close();
        });
        when(mockNode.dhtHandler).thenReturn(unhappy);

        final cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/v0/dht/provide?arg=$cid&queue=true'),
        );
        final response = await handlers.handleDhtProvide(request);
        expect(response.statusCode, equals(503));
      });

      test('returns 500 when the provide engine throws', () async {
        final router = FakeRouter();
        final nodeConfig = IPFSConfig(
          dht: const DHTConfig(requestTimeout: Duration(milliseconds: 100)),
        );
        final storage = MemoryDatastore();
        await storage.init();
        final unhappy = _UnhappyDHTHandler(
          nodeConfig,
          router,
          NetworkHandler(nodeConfig, router: router),
          storage: storage,
        );
        addTearDown(() async {
          await unhappy.stop();
          await storage.close();
        });
        when(mockNode.dhtHandler).thenReturn(unhappy);

        final cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/v0/dht/provide?arg=$cid'),
        );
        final response = await handlers.handleDhtProvide(request);
        expect(response.statusCode, equals(500));
        final body = json.decode(await response.readAsString());
        expect(body['Message'], equals('DHT provide failed'));
      });

      test('timeout parameter accepts all Kubo duration units', () async {
        final cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
        for (final timeout in ['5', '500ms', '5m', '1h']) {
          final request = Request(
            'POST',
            Uri.parse(
              'http://localhost/api/v0/dht/provide?arg=$cid&timeout=$timeout',
            ),
          );
          final response = await handlers.handleDhtProvide(request);
          expect(
            response.statusCode,
            equals(200),
            reason: 'timeout=$timeout was not accepted',
          );
        }
      });
    });

    test('handleAdd success', () async {
      final boundary = 'boundary';
      final content = 'hello world';
      final body =
          '--$boundary\r\n'
          'Content-Disposition: form-data; name="file"; filename="test.txt"\r\n'
          'Content-Type: text/plain\r\n'
          '\r\n'
          '$content\r\n'
          '--$boundary--\r\n';

      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/add'),
        headers: {'content-type': 'multipart/form-data; boundary=$boundary'},
        body: body,
      );

      when(mockNode.addFile(any)).thenAnswer((_) async => 'QmHash');

      final response = await handlers.handleAdd(request);
      expect(response.statusCode, equals(200));
      final respBody = await response.readAsString();
      expect(respBody, contains('"Name":"test.txt"'));
      expect(respBody, contains('"Hash":"QmHash"'));
    });

    test('handleAdd multiple files', () async {
      final boundary = 'boundary';
      final body =
          '--$boundary\r\n'
          'Content-Disposition: form-data; name="file1"; filename="test1.txt"\r\n'
          'Content-Type: text/plain\r\n'
          '\r\n'
          'content1\r\n'
          '--$boundary\r\n'
          'Content-Disposition: form-data; name="file2"; filename="test2.txt"\r\n'
          'Content-Type: text/plain\r\n'
          '\r\n'
          'content2\r\n'
          '--$boundary--\r\n';

      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/add'),
        headers: {'content-type': 'multipart/form-data; boundary=$boundary'},
        body: body,
      );

      when(mockNode.addFile(any)).thenAnswer((realInvocation) async {
        final data = realInvocation.positionalArguments[0] as Uint8List;
        if (utf8.decode(data) == 'content1') return 'QmHash1';
        return 'QmHash2';
      });

      final response = await handlers.handleAdd(request);
      expect(response.statusCode, equals(200));
      final respBody = await response.readAsString();
      expect(respBody, contains('"Name":"test1.txt"'));
      expect(respBody, contains('"Hash":"QmHash1"'));
      expect(respBody, contains('"Name":"test2.txt"'));
      expect(respBody, contains('"Hash":"QmHash2"'));
    });

    test('handleAdd no files', () async {
      final boundary = 'boundary';
      final body = '--$boundary--\r\n';

      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/add'),
        headers: {'content-type': 'multipart/form-data; boundary=$boundary'},
        body: body,
      );

      final response = await handlers.handleAdd(request);
      expect(response.statusCode, equals(500));
      final respBody = json.decode(await response.readAsString());
      expect(respBody['Message'], contains('No files found'));
    });

    test('handleAdd no filename', () async {
      final boundary = 'boundary';
      final body =
          '--$boundary\r\n'
          'Content-Disposition: form-data; name="file1"\r\n'
          'Content-Type: text/plain\r\n'
          '\r\n'
          'content1\r\n'
          '--$boundary--\r\n';

      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/add'),
        headers: {'content-type': 'multipart/form-data; boundary=$boundary'},
        body: body,
      );

      when(mockNode.addFile(any)).thenAnswer((_) async => 'QmHash1');

      final response = await handlers.handleAdd(request);
      expect(response.statusCode, equals(200));
      final respBody = await response.readAsString();
      expect(respBody, contains('"Name":"QmHash1"'));
    });

    test('handleLs success', () async {
      final cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      final fileCid = 'QmZ4tDuYkmpZzbeSthMBG8eW9Jre7iE6L4v8eY5QZkYJmC';
      final mockLinks = [
        Link(name: 'file.txt', cid: CID.decode(fileCid), size: 100),
      ];
      when(mockNode.ls(cid)).thenAnswer((_) async => mockLinks);

      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/ls?arg=$cid'),
      );
      final response = await handlers.handleLs(request);
      expect(response.statusCode, equals(200));
      final body = json.decode(await response.readAsString());
      expect(body['Objects'][0]['Links'][0]['Name'], equals('file.txt'));
      // Kubo parity: Type is the numeric UnixFS DataType enum, not a
      // string. The mock link target cannot be resolved, so it reports
      // the zero value (Raw).
      expect(body['Objects'][0]['Links'][0]['Type'], isA<int>());
    });

    test('handleLs missing arg', () async {
      final request = Request('POST', Uri.parse('http://localhost/api/v0/ls'));
      final response = await handlers.handleLs(request);
      expect(response.statusCode, equals(500));
    });

    test('handleDagGet returns DAG-JSON like Kubo', () async {
      // Kubo parity: dag/get returns the node re-encoded as DAG-JSON, not
      // the raw stored block bytes.
      final block = await Block.fromData(
        Uint8List.fromList([1, 2, 3]),
        format: 'raw',
      );
      final cid = block.cid.encode();
      final pbResp = GetBlockResponse()
        ..found = true
        ..block = block.toProto();

      when(mockBlockStore.getBlock(cid)).thenAnswer((_) async => pbResp);

      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/dag/get?arg=$cid'),
      );
      final response = await handlers.handleDagGet(request);
      expect(response.statusCode, equals(200));
      final body = await response.readAsString();
      // DAG-JSON encodes a raw block as a {"/":{"bytes":...}} link.
      expect(json.decode(body), isA<Map<String, dynamic>>());
    });

    test('handleDagGet not found', () async {
      final cid = 'QmHash';
      final pbResp = GetBlockResponse()..found = false;
      when(mockBlockStore.getBlock(cid)).thenAnswer((_) async => pbResp);

      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/dag/get?arg=$cid'),
      );
      final response = await handlers.handleDagGet(request);
      expect(response.statusCode, equals(404));
    });

    test('handleDhtFindProviders', () async {
      final cid = 'QmHash';
      final peerId = PeerId(value: Uint8List.fromList([1, 2, 3]));
      when(mockDHTClient.findProviders(cid)).thenAnswer((_) async => [peerId]);
      when(
        mockNode.resolvePeerId(peerId.toString()),
      ).thenReturn(['/ip4/127.0.0.1/tcp/4001']);

      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/dht/findprovs?arg=$cid'),
      );
      final response = await handlers.handleDhtFindProviders(request);
      expect(response.statusCode, equals(200));
      final respBody = await response.readAsString();
      expect(respBody, contains(peerId.toString()));
    });

    test('handleDhtFindPeer success', () async {
      final peerIdStr = 'QmP53fV995Dq65yX7E69m6jUeP5jA58X4vUf5Q5u5W5v';
      final peerId = PeerId(value: Base58().base58Decode(peerIdStr));
      when(mockDHTClient.findPeer(any)).thenAnswer((_) async => peerId);
      when(
        mockNode.resolvePeerId(peerIdStr),
      ).thenReturn(['/ip4/127.0.0.1/tcp/4001']);

      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/dht/findpeer?arg=$peerIdStr'),
      );
      final response = await handlers.handleDhtFindPeer(request);
      expect(response.statusCode, equals(200));
      final body = json.decode(await response.readAsString());
      expect(body['Responses'][0]['ID'], equals(peerIdStr));
    });

    test('handleNamePublish', () async {
      final path = '/ipfs/QmHash';
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/name/publish?arg=$path'),
      );
      final response = await handlers.handleNamePublish(request);
      expect(response.statusCode, equals(200));
      verify(mockNode.publishIPNS('QmHash', keyName: 'self')).called(1);
    });

    test('handleNameResolve', () async {
      final name = 'QmName';
      when(mockNode.resolveIPNS(name)).thenAnswer((_) async => '/ipfs/QmHash');

      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/name/resolve?arg=$name'),
      );
      final response = await handlers.handleNameResolve(request);
      expect(response.statusCode, equals(200));
      final body = json.decode(await response.readAsString());
      expect(body['Path'], equals('/ipfs/QmHash'));
    });

    test('handleSwarmConnect', () async {
      final addr = '/ip4/1.2.3.4/tcp/4001/p2p/QmPeer';
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/swarm/connect?arg=$addr'),
      );
      final response = await handlers.handleSwarmConnect(request);
      expect(response.statusCode, equals(200));
      verify(mockNode.connectToPeer(addr)).called(1);
    });

    test('handleBlockPut', () async {
      final data = [1, 2, 3, 4];
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/block/put'),
        body: data,
      );

      final response = await handlers.handleBlockPut(request);
      expect(response.statusCode, equals(200));
      verify(mockBlockStore.putBlock(any)).called(1);
    });

    test('handleBlockPut rejects a body over the 4 MiB cap', () async {
      // _readBodyBounded must abort the upload instead of buffering an
      // unbounded request body into memory.
      final oversized = Uint8List(4 * 1024 * 1024 + 1);
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/block/put'),
        body: oversized,
      );

      final response = await handlers.handleBlockPut(request);
      expect(response.statusCode, equals(500));
      verifyNever(mockBlockStore.putBlock(any));
    });

    test('handleBlockStat success', () async {
      final cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      final block = Block(
        cid: CID.decode(cid),
        data: Uint8List.fromList([1, 2, 3]),
      );
      final pbResp = GetBlockResponse()
        ..found = true
        ..block = block.toProto();

      when(mockBlockStore.getBlock(cid)).thenAnswer((_) async => pbResp);

      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/block/stat?arg=$cid'),
      );
      final response = await handlers.handleBlockStat(request);
      expect(response.statusCode, equals(200));
      final body = json.decode(await response.readAsString());
      expect(body['Key'], equals(cid));
      expect(body['Size'], equals(3));
    });

    test('handleSwarmDisconnect success', () async {
      final addr = '/ip4/1.2.3.4/tcp/4001/p2p/QmPeer';
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/swarm/disconnect?arg=$addr'),
      );
      final response = await handlers.handleSwarmDisconnect(request);
      expect(response.statusCode, equals(200));
      verify(mockNode.disconnectFromPeer(addr)).called(1);
    });

    test('handleGet requires an arg', () async {
      final request = Request('POST', Uri.parse('http://localhost/api/v0/get'));
      final response = await handlers.handleGet(request);
      expect(response.statusCode, equals(500));
    });

    test('handleGet returns a TAR archive for a file', () async {
      final block = await Block.fromData(
        Uint8List.fromList(utf8.encode('tar me')),
        format: 'raw',
      );
      when(mockBlockStore.getBlock(block.cid.encode())).thenAnswer(
        (_) async => GetBlockResponse()
          ..found = true
          ..block = block.toProto(),
      );

      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/get?arg=/ipfs/${block.cid}'),
      );
      final response = await handlers.handleGet(request);
      expect(response.statusCode, equals(200));
      expect(response.headers['content-type'], equals('application/x-tar'));
      final tar = await response.read().expand((i) => i).toList();
      // POSIX ustar: the entry name occupies the first 100 header bytes.
      expect(
        utf8.decode(tar.sublist(0, block.cid.encode().length)),
        equals(block.cid.encode()),
      );
      // The file payload follows the 512-byte header.
      expect(utf8.decode(tar.sublist(512, 512 + 6)), equals('tar me'));
    });

    test('handleDagPut stores the node and returns a CID link', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/dag/put?pin=false'),
        headers: {'content-type': 'application/json'},
        body: utf8.encode('{"hello":"world"}'),
      );
      final response = await handlers.handleDagPut(request);
      expect(response.statusCode, equals(200));
      final body = json.decode(await response.readAsString());
      // Kubo shape: {"Cid":{"/":"<cid>"}}.
      expect(body['Cid'], isA<Map<String, dynamic>>());
      expect(body['Cid']['/'], isA<String>());
      verify(mockBlockStore.putBlock(any)).called(1);
    });

    test('handleId error', () async {
      when(mockNode.publicKey).thenThrow(Exception('Failed to get key'));
      final request = Request('POST', Uri.parse('http://localhost/api/v0/id'));
      final response = await handlers.handleId(request);
      expect(response.statusCode, equals(500));
    });

    test('handleCat missing arg', () async {
      final request = Request('POST', Uri.parse('http://localhost/api/v0/cat'));
      final response = await handlers.handleCat(request);
      expect(response.statusCode, equals(500));
      final body = json.decode(await response.readAsString());
      expect(body['Message'], contains('Missing argument'));
    });

    test('handleAdd missing content-type', () async {
      final request = Request('POST', Uri.parse('http://localhost/api/v0/add'));
      final response = await handlers.handleAdd(request);
      expect(response.statusCode, equals(500));
      final respBody = json.decode(await response.readAsString());
      expect(respBody['Message'], contains('Missing Content-Type'));
    });

    test('handleAdd invalid boundary', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/add'),
        headers: {'content-type': 'multipart/form-data'}, // missing boundary
      );
      final response = await handlers.handleAdd(request);
      expect(response.statusCode, equals(500));
    });

    test('handleLs error', () async {
      final cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      when(mockNode.ls(cid)).thenThrow(Exception('Ls failed'));
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/ls?arg=$cid'),
      );
      final response = await handlers.handleLs(request);
      expect(response.statusCode, equals(500));
    });

    test('handleDhtFindPeer not found', () async {
      final peerIdStr = 'QmP53fV995Dq65yX7E69m6jUeP5jA58X4vUf5Q5u5W5v';
      when(mockDHTClient.findPeer(any)).thenAnswer((_) async => null);

      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/dht/findpeer?arg=$peerIdStr'),
      );
      final response = await handlers.handleDhtFindPeer(request);
      expect(response.statusCode, equals(500));
      final body = json.decode(await response.readAsString());
      expect(body['Message'], contains('Peer not found'));
    });

    test('handleBlockGet missing arg', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/block/get'),
      );
      final response = await handlers.handleBlockGet(request);
      expect(response.statusCode, equals(500));
    });

    test('handleBlockGet not found', () async {
      final cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      final pbResp = GetBlockResponse()..found = false;
      when(mockBlockStore.getBlock(cid)).thenAnswer((_) async => pbResp);

      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/block/get?arg=$cid'),
      );
      final response = await handlers.handleBlockGet(request);
      expect(response.statusCode, equals(404));
    });

    test('handleDagGet missing arg', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/dag/get'),
      );
      final response = await handlers.handleDagGet(request);
      expect(response.statusCode, equals(500));
    });

    test('handleDhtFindProviders missing arg', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/dht/findprovs'),
      );
      final response = await handlers.handleDhtFindProviders(request);
      expect(response.statusCode, equals(500));
    });

    test('handleDhtProvide missing arg', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/dht/provide'),
      );
      final response = await handlers.handleDhtProvide(request);
      expect(response.statusCode, equals(500));
    });

    test('handleNamePublish missing arg', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/name/publish'),
      );
      final response = await handlers.handleNamePublish(request);
      expect(response.statusCode, equals(500));
    });

    test('handleNameResolve missing arg', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/name/resolve'),
      );
      final response = await handlers.handleNameResolve(request);
      expect(response.statusCode, equals(500));
    });

    test('handleSwarmConnect missing arg', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/swarm/connect'),
      );
      final response = await handlers.handleSwarmConnect(request);
      expect(response.statusCode, equals(500));
    });

    test('handleSwarmDisconnect missing arg', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/swarm/disconnect'),
      );
      final response = await handlers.handleSwarmDisconnect(request);
      expect(response.statusCode, equals(500));
    });

    test('handleBlockStat missing arg', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/block/stat'),
      );
      final response = await handlers.handleBlockStat(request);
      expect(response.statusCode, equals(500));
    });

    test('handleBlockStat not found', () async {
      final cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      final pbResp = GetBlockResponse()..found = false;
      when(mockBlockStore.getBlock(cid)).thenAnswer((_) async => pbResp);

      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/block/stat?arg=$cid'),
      );
      final response = await handlers.handleBlockStat(request);
      expect(response.statusCode, equals(404));
    });

    test('handleDhtFindProviders error', () async {
      final cid = 'QmHash';
      when(mockDHTClient.findProviders(cid)).thenThrow(Exception('DHT error'));

      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/dht/findprovs?arg=$cid'),
      );
      final response = await handlers.handleDhtFindProviders(request);
      expect(response.statusCode, equals(500));
    });

    test('handleDhtProvide error', () async {
      final cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      when(
        mockDHTClient.addProvider(any, any),
      ).thenThrow(Exception('DHT error'));

      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/dht/provide?arg=$cid'),
      );
      final response = await handlers.handleDhtProvide(request);
      expect(response.statusCode, equals(500));
    });

    test('handleNamePublish error', () async {
      final path = '/ipfs/QmHash';
      when(
        mockNode.publishIPNS(any, keyName: anyNamed('keyName')),
      ).thenThrow(Exception('IPNS error'));

      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/name/publish?arg=$path'),
      );
      final response = await handlers.handleNamePublish(request);
      expect(response.statusCode, equals(500));
    });

    test('handleNameResolve error', () async {
      final name = 'QmName';
      when(mockNode.resolveIPNS(name)).thenThrow(Exception('IPNS error'));

      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/name/resolve?arg=$name'),
      );
      final response = await handlers.handleNameResolve(request);
      expect(response.statusCode, equals(500));
    });

    test('handleSwarmConnect error', () async {
      final addr = '/ip4/1.2.3.4/tcp/4001/p2p/QmPeer';
      when(mockNode.connectToPeer(addr)).thenThrow(Exception('Connect error'));

      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/swarm/connect?arg=$addr'),
      );
      final response = await handlers.handleSwarmConnect(request);
      expect(response.statusCode, equals(500));
    });

    test('handleSwarmDisconnect error', () async {
      final addr = '/ip4/1.2.3.4/tcp/4001/p2p/QmPeer';
      when(
        mockNode.disconnectFromPeer(addr),
      ).thenThrow(Exception('Disconnect error'));

      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/swarm/disconnect?arg=$addr'),
      );
      final response = await handlers.handleSwarmDisconnect(request);
      expect(response.statusCode, equals(500));
    });

    test('handleBlockPut error', () async {
      when(mockBlockStore.putBlock(any)).thenThrow(Exception('Put error'));

      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/block/put'),
        body: [1, 2, 3, 4],
      );
      final response = await handlers.handleBlockPut(request);
      expect(response.statusCode, equals(500));
    });

    test('handleBlockStat error', () async {
      final cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      when(mockBlockStore.getBlock(cid)).thenThrow(Exception('Stat error'));

      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/block/stat?arg=$cid'),
      );
      final response = await handlers.handleBlockStat(request);
      expect(response.statusCode, equals(500));
    });

    test('handleDagExport returns a CAR archive of the DAG', () async {
      final block = await Block.fromData(
        Uint8List.fromList([5, 6, 7]),
        format: 'raw',
      );
      final pbResp = GetBlockResponse()
        ..found = true
        ..block = block.toProto();
      when(
        mockBlockStore.getBlock(block.cid.toString()),
      ).thenAnswer((_) async => pbResp);

      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/dag/export?arg=${block.cid}'),
      );
      final response = await handlers.handleDagExport(request);
      expect(response.statusCode, equals(200));
      expect(
        response.headers['Content-Type'],
        equals('application/vnd.ipld.car'),
      );

      final body = await response.read().expand((i) => i).toList();
      final reader = CarReader.fromBytes(Uint8List.fromList(body));
      final header = await reader.header;
      expect(header.roots.length, equals(1));
      final sections = await reader.sections().toList();
      expect(sections.length, equals(1));
      expect(sections.first.bytes, equals(block.data));
    });

    test('handleDagExport rejects traversal deeper than the bound', () async {
      // Security bound (#108): export must refuse DAGs deeper than 32 links
      // rather than recursing without limit. Build a chain of 33 nodes.
      var child = await Block.fromData(
        Uint8List.fromList([0]),
        format: 'dag-pb',
      );
      when(mockBlockStore.getBlock(child.cid.toString())).thenAnswer(
        (_) async => GetBlockResponse()
          ..found = true
          ..block = child.toProto(),
      );
      for (var i = 0; i < 34; i++) {
        final node_ = dag_pb.PBNode(
          links: [dag_pb.PBLink(hash: child.cid.toBytes())],
        );
        final parent = await Block.fromData(
          node_.writeToBuffer(),
          format: 'dag-pb',
        );
        when(mockBlockStore.getBlock(parent.cid.toString())).thenAnswer(
          (_) async => GetBlockResponse()
            ..found = true
            ..block = parent.toProto(),
        );
        child = parent;
      }

      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/dag/export?arg=${child.cid}'),
      );
      final response = await handlers.handleDagExport(request);
      expect(response.statusCode, equals(500));
      final body = json.decode(await response.readAsString());
      expect(body['Message'], contains('maximum depth'));
    });

    test('handleDagExport errors when the root block is missing', () async {
      final block = await Block.fromData(
        Uint8List.fromList([5, 6, 7]),
        format: 'raw',
      );
      when(
        mockBlockStore.getBlock(block.cid.toString()),
      ).thenAnswer((_) async => GetBlockResponse()..found = false);

      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/dag/export?arg=${block.cid}'),
      );
      final response = await handlers.handleDagExport(request);
      expect(response.statusCode, equals(500));
    });

    test('handleDagImport stores blocks that hash-verify', () async {
      final block = await Block.fromData(Uint8List.fromList([1, 2, 3, 4]));
      final writer = CarWriter(roots: [coreCid(block.cid)]);
      await writer.write(coreCid(block.cid), block.data);
      final carData = await writer.close();

      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/dag/import'),
        body: carData,
      );
      final response = await handlers.handleDagImport(request);
      expect(response.statusCode, equals(200));
      verify(mockBlockStore.putBlock(any)).called(1);
    });

    test(
      'handleDagImport rejects block whose data does not match CID',
      () async {
        final block = await Block.fromData(Uint8List.fromList([1, 2, 3, 4]));
        final writer = CarWriter(roots: [coreCid(block.cid)]);
        await writer.write(
          coreCid(block.cid),
          Uint8List.fromList([9, 9, 9, 9]),
        );
        final carData = await writer.close();

        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/v0/dag/import'),
          body: carData,
        );
        final response = await handlers.handleDagImport(request);
        expect(response.statusCode, equals(500));
        verifyNever(mockBlockStore.putBlock(any));
      },
    );
  });

  group('remaining RPC handler branches', () {
    GetBlockResponse found(Block block) => GetBlockResponse()
      ..found = true
      ..block = block.toProto();

    void storeBlock(Block block) {
      when(
        mockBlockStore.getBlock(block.cid.encode()),
      ).thenAnswer((_) async => found(block));
    }

    String multipartBody(String boundary, String content) =>
        '--$boundary\r\n'
        'Content-Disposition: form-data; name="file"; filename="f.txt"\r\n'
        '\r\n'
        '$content\r\n'
        '--$boundary--\r\n';

    test('handleAdd wrap-with-directory emits a wrapping dir entry', () async {
      // File whose dag-pb block carries a link so cumulative size includes
      // the declared link Tsize.
      final child = await Block.fromData(
        Uint8List.fromList([1]),
        format: 'raw',
      );
      final fileNode = dag_pb.PBNode(
        data: unixfs_pb.Data(
          type: unixfs_pb.Data_DataType.File,
          filesize: Int64(3),
        ).writeToBuffer(),
        links: [
          dag_pb.PBLink(name: 'l', hash: child.cid.toBytes(), size: Int64(9)),
        ],
      );
      final fileBlock = await Block.fromData(
        fileNode.writeToBuffer(),
        format: 'dag-pb',
      );
      storeBlock(fileBlock);
      // A dag-pb entry whose stored data cannot be parsed exercises the
      // cumulative-size fallback that counts the block alone.
      final badBlock = await Block.fromData(
        Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF]),
        format: 'dag-pb',
      );
      storeBlock(badBlock);
      // A third entry is simply absent from the blockstore.
      final missing = await Block.fromData(
        Uint8List.fromList([7]),
        format: 'raw',
      );
      when(
        mockBlockStore.getBlock(missing.cid.encode()),
      ).thenAnswer((_) async => GetBlockResponse()..found = false);

      var call = 0;
      when(mockNode.addFile(any)).thenAnswer((_) async {
        call++;
        return switch (call) {
          1 => fileBlock.cid.encode(),
          2 => badBlock.cid.encode(),
          _ => missing.cid.encode(),
        };
      });
      when(mockNode.pin(any)).thenAnswer((_) async {});

      const boundary = 'b';
      final body =
          '--$boundary\r\n'
          'Content-Disposition: form-data; name="f1"; filename="a.txt"\r\n'
          '\r\n'
          'aaa\r\n'
          '--$boundary\r\n'
          'Content-Disposition: form-data; name="f2"; filename="b.txt"\r\n'
          '\r\n'
          'bbb\r\n'
          '--$boundary\r\n'
          'Content-Disposition: form-data; name="f3"; filename="c.txt"\r\n'
          '\r\n'
          'ccc\r\n'
          '--$boundary--\r\n';
      final request = Request(
        'POST',
        Uri.parse(
          'http://localhost/api/v0/add?wrap-with-directory=true&pin=true',
        ),
        headers: {'content-type': 'multipart/form-data; boundary=$boundary'},
        body: body,
      );
      final response = await handlers.handleAdd(request);
      expect(response.statusCode, equals(200));
      final lines = (await response.readAsString())
          .split('\n')
          .map(json.decode)
          .toList();
      // The wrapping directory is emitted with an empty name.
      expect(lines.last['Name'], equals(''));
      expect(lines.last['Hash'], isA<String>());
      verify(mockNode.pin(any)).called(greaterThanOrEqualTo(2));
    });

    test(
      'handleAdd builds blocks directly for non-default DAG options',
      () async {
        when(mockNode.pin(any)).thenAnswer((_) async {});
        const boundary = 'b';
        final request = Request(
          'POST',
          Uri.parse(
            'http://localhost/api/v0/add?cid-version=1&raw-leaves=true',
          ),
          headers: {'content-type': 'multipart/form-data; boundary=$boundary'},
          body: multipartBody(boundary, 'abc'),
        );
        final response = await handlers.handleAdd(request);
        expect(response.statusCode, equals(200));
        // Blocks were built locally and stored via the blockstore rather
        // than delegated to node.addFile.
        verify(mockBlockStore.putBlock(any)).called(greaterThanOrEqualTo(1));
        verifyNever(mockNode.addFile(any));
      },
    );

    test('handleGet normalizes ipfs path prefixes', () async {
      final block = await Block.fromData(
        Uint8List.fromList(utf8.encode('x')),
        format: 'raw',
      );
      storeBlock(block);
      when(mockNode.bitswap).thenReturn(null);

      for (final prefix in ['/ipfs/', 'ipfs/', '/']) {
        final request = Request(
          'POST',
          Uri.parse(
            'http://localhost/api/v0/get?arg=$prefix${block.cid.encode()}',
          ),
        );
        final response = await handlers.handleGet(request);
        expect(response.statusCode, equals(200), reason: 'prefix $prefix');
      }

      // A bare '/' argument has no CID segment at all.
      final empty = await handlers.handleGet(
        Request('POST', Uri.parse('http://localhost/api/v0/get?arg=/')),
      );
      expect(empty.statusCode, equals(500));
    });

    test(
      'handleGet resolves named sub-paths through directory links',
      () async {
        final child = await Block.fromData(
          Uint8List.fromList(utf8.encode('sub-data')),
          format: 'raw',
        );
        storeBlock(child);
        final dirNode = dag_pb.PBNode(
          links: [dag_pb.PBLink(name: 'sub.txt', hash: child.cid.toBytes())],
        );
        final dir = await Block.fromData(
          dirNode.writeToBuffer(),
          format: 'dag-pb',
        );
        storeBlock(dir);
        when(mockNode.bitswap).thenReturn(null);

        final request = Request(
          'POST',
          Uri.parse(
            'http://localhost/api/v0/get?arg=${dir.cid.encode()}/sub.txt',
          ),
        );
        final response = await handlers.handleGet(request);
        expect(response.statusCode, equals(200));
        final tar = await response.read().expand((i) => i).toList();
        expect(utf8.decode(tar.sublist(0, 7)), equals('sub.txt'));
        expect(utf8.decode(tar.sublist(512, 512 + 8)), equals('sub-data'));
      },
    );

    test('handleGet reports missing links and missing child blocks', () async {
      final missing = await Block.fromData(
        Uint8List.fromList([9]),
        format: 'raw',
      );
      when(
        mockBlockStore.getBlock(missing.cid.encode()),
      ).thenAnswer((_) async => GetBlockResponse()..found = false);
      final dirNode = dag_pb.PBNode(
        links: [dag_pb.PBLink(name: 'present', hash: missing.cid.toBytes())],
      );
      final dir = await Block.fromData(
        dirNode.writeToBuffer(),
        format: 'dag-pb',
      );
      storeBlock(dir);
      when(mockNode.bitswap).thenReturn(null);

      // Link name absent from the directory.
      var response = await handlers.handleGet(
        Request(
          'POST',
          Uri.parse(
            'http://localhost/api/v0/get?arg=${dir.cid.encode()}/absent',
          ),
        ),
      );
      expect(response.statusCode, equals(404));

      // Link exists but the child block is nowhere.
      response = await handlers.handleGet(
        Request(
          'POST',
          Uri.parse(
            'http://localhost/api/v0/get?arg=${dir.cid.encode()}/present',
          ),
        ),
      );
      expect(response.statusCode, equals(404));

      // Sub-path against a non-dag-pb root is also "not found".
      final raw = await Block.fromData(Uint8List.fromList([1]), format: 'raw');
      storeBlock(raw);
      response = await handlers.handleGet(
        Request(
          'POST',
          Uri.parse('http://localhost/api/v0/get?arg=${raw.cid.encode()}/x'),
        ),
      );
      expect(response.statusCode, equals(404));

      // A dag-pb CID whose data is not a decodable PBNode falls back to
      // the "not found" path inside _findNamedLink.
      final garbage = await Block.fromData(
        Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF]),
        format: 'dag-pb',
      );
      storeBlock(garbage);
      response = await handlers.handleGet(
        Request(
          'POST',
          Uri.parse(
            'http://localhost/api/v0/get?arg=${garbage.cid.encode()}/x',
          ),
        ),
      );
      expect(response.statusCode, equals(404));
    });

    test('handleGet falls back to Bitswap for missing local blocks', () async {
      final remote = await Block.fromData(
        Uint8List.fromList(utf8.encode('remote')),
        format: 'raw',
      );
      when(
        mockBlockStore.getBlock(remote.cid.encode()),
      ).thenAnswer((_) async => GetBlockResponse()..found = false);
      final bitswap = _FakeBitswapHandler(remote);
      when(mockNode.bitswap).thenReturn(bitswap);

      final response = await handlers.handleGet(
        Request(
          'POST',
          Uri.parse('http://localhost/api/v0/get?arg=${remote.cid.encode()}'),
        ),
      );
      expect(response.statusCode, equals(200));
      // The fetched block is cached into the local blockstore.
      verify(mockBlockStore.putBlock(any)).called(1);

      // When Bitswap also misses the path yields a 404.
      when(
        mockBlockStore.getBlock('nope'),
      ).thenAnswer((_) async => GetBlockResponse()..found = false);
      final miss = await handlers.handleGet(
        Request('POST', Uri.parse('http://localhost/api/v0/get?arg=nope')),
      );
      expect(miss.statusCode, equals(404));
    });

    test('handleGet exports a UnixFS directory tree as TAR', () async {
      final file = await Block.fromData(
        Uint8List.fromList(utf8.encode('inner')),
        format: 'raw',
      );
      storeBlock(file);
      final longName = '${'d' * 95}/${'f' * 30}';
      final longFile = await Block.fromData(
        Uint8List.fromList([2]),
        format: 'raw',
      );
      storeBlock(longFile);
      final veryLongName = 'z' * 150;
      final veryLongFile = await Block.fromData(
        Uint8List.fromList([3]),
        format: 'raw',
      );
      storeBlock(veryLongFile);

      final dirNode = dag_pb.PBNode(
        data: unixfs_pb.Data(
          type: unixfs_pb.Data_DataType.Directory,
        ).writeToBuffer(),
        links: [
          dag_pb.PBLink(name: 'file.txt', hash: file.cid.toBytes()),
          dag_pb.PBLink(name: longName, hash: longFile.cid.toBytes()),
          dag_pb.PBLink(name: veryLongName, hash: veryLongFile.cid.toBytes()),
        ],
      );
      final dir = await Block.fromData(
        dirNode.writeToBuffer(),
        format: 'dag-pb',
      );
      storeBlock(dir);
      when(mockNode.bitswap).thenReturn(null);

      final response = await handlers.handleGet(
        Request(
          'POST',
          Uri.parse('http://localhost/api/v0/get?arg=${dir.cid.encode()}'),
        ),
      );
      expect(response.statusCode, equals(200));
      final tar = await response.read().expand((i) => i).toList();
      // Directory entry: ustar typeflag '5' at offset 156.
      expect(tar[156], equals(0x35));
      // Three file entries follow the directory header.
      var fileEntries = 0;
      for (var off = 0; off + 512 <= tar.length; off += 512) {
        if (tar[off + 156] == 0x30) fileEntries++;
      }
      expect(fileEntries, equals(3));
    });

    test('handleGet fails when a linked TAR block is missing', () async {
      final missing = await Block.fromData(
        Uint8List.fromList([9]),
        format: 'raw',
      );
      when(
        mockBlockStore.getBlock(missing.cid.encode()),
      ).thenAnswer((_) async => GetBlockResponse()..found = false);
      final dirNode = dag_pb.PBNode(
        data: unixfs_pb.Data(
          type: unixfs_pb.Data_DataType.Directory,
        ).writeToBuffer(),
        links: [dag_pb.PBLink(name: 'gone', hash: missing.cid.toBytes())],
      );
      final dir = await Block.fromData(
        dirNode.writeToBuffer(),
        format: 'dag-pb',
      );
      storeBlock(dir);
      when(mockNode.bitswap).thenReturn(null);

      final response = await handlers.handleGet(
        Request(
          'POST',
          Uri.parse('http://localhost/api/v0/get?arg=${dir.cid.encode()}'),
        ),
      );
      expect(response.statusCode, equals(500));
      final body = json.decode(await response.readAsString());
      expect(body['Message'], contains('Get failed'));
    });

    test('handleGet reassembles a chunked UnixFS file into TAR', () async {
      // A chunked file's dag-pb root carries links to leaf blocks, so the
      // TAR writer's unixfsReadFile call must fetch them through the
      // blockstore callback.
      final chunk = await Block.fromData(
        Uint8List.fromList(utf8.encode('chunked!')),
        format: 'raw',
      );
      storeBlock(chunk);
      final fileNode = dag_pb.PBNode(
        data: unixfs_pb.Data(
          type: unixfs_pb.Data_DataType.File,
          filesize: Int64(8),
          blocksizes: [Int64(8)],
        ).writeToBuffer(),
        links: [dag_pb.PBLink(hash: chunk.cid.toBytes(), size: Int64(8))],
      );
      final fileBlock = await Block.fromData(
        fileNode.writeToBuffer(),
        format: 'dag-pb',
      );
      storeBlock(fileBlock);
      when(mockNode.bitswap).thenReturn(null);

      final response = await handlers.handleGet(
        Request(
          'POST',
          Uri.parse(
            'http://localhost/api/v0/get?arg=${fileBlock.cid.encode()}',
          ),
        ),
      );
      expect(response.statusCode, equals(200));
      final tar = await response.read().expand((i) => i).toList();
      // The reassembled payload follows the 512-byte ustar header.
      expect(utf8.decode(tar.sublist(512, 512 + 8)), equals('chunked!'));
    });

    test('TAR traversal enforces depth and node-count bounds', () async {
      final block = await Block.fromData(
        Uint8List.fromList([1]),
        format: 'raw',
      );
      final mirror = mirrors.reflect(handlers);
      // Private members are library-scoped, so resolve them by their
      // readable names rather than Symbols minted in this library.
      final lib = mirror.type.owner! as mirrors.LibraryMirror;
      final tarClass =
          lib.declarations.entries
                  .firstWhere(
                    (e) => mirrors.MirrorSystem.getName(e.key) == '_TarWriter',
                  )
                  .value
              as mirrors.ClassMirror;
      final tar = tarClass.newInstance(const Symbol(''), []).reflectee;
      final tarAddSym = mirror.type.declarations.keys.firstWhere(
        (s) => mirrors.MirrorSystem.getName(s) == '_tarAddNode',
      );

      await expectLater(
        mirror
                .invoke(
                  tarAddSym,
                  [tar, 'n', block],
                  {const Symbol('depth'): 33, const Symbol('nodes'): 1},
                )
                .reflectee
            as Future<void>,
        throwsStateError,
      );
      await expectLater(
        mirror
                .invoke(
                  tarAddSym,
                  [tar, 'n', block],
                  {const Symbol('depth'): 0, const Symbol('nodes'): 10001},
                )
                .reflectee
            as Future<void>,
        throwsStateError,
      );
    });

    test(
      'handleDagGet decodes dag-pb, dag-cbor, dag-json and raw blocks',
      () async {
        final node = await DagJsonCodec().decode(utf8.encode('{"k":"v"}'));
        final cborBytes = await DagCborCodec().encode(node);
        final cborBlock = await Block.fromData(cborBytes, format: 'dag-cbor');
        storeBlock(cborBlock);
        final jsonBlock = await Block.fromData(
          Uint8List.fromList(utf8.encode('{"j":true}')),
          format: 'dag-json',
        );
        storeBlock(jsonBlock);
        final rawBlock = await Block.fromData(
          Uint8List.fromList([1, 2, 3]),
          format: 'raw',
        );
        storeBlock(rawBlock);
        final pbBlock = await Block.fromData(
          dag_pb.PBNode(
            links: [dag_pb.PBLink(name: 'x', hash: rawBlock.cid.toBytes())],
          ).writeToBuffer(),
          format: 'dag-pb',
        );
        storeBlock(pbBlock);

        for (final block in [cborBlock, jsonBlock, rawBlock, pbBlock]) {
          final response = await handlers.handleDagGet(
            Request(
              'POST',
              Uri.parse(
                'http://localhost/api/v0/dag/get?arg=${block.cid.encode()}',
              ),
            ),
          );
          expect(
            response.statusCode,
            equals(200),
            reason: block.cid.codec ?? 'raw',
          );
        }
      },
    );

    test('handleDagPut accepts cbor, protobuf and raw codec options', () async {
      when(mockNode.pin(any)).thenAnswer((_) async {});

      // dag-cbor input with the default dag-cbor store codec.
      final node = await DagJsonCodec().decode(utf8.encode('{"a":1}'));
      final cborBytes = await DagCborCodec().encode(node);
      var response = await handlers.handleDagPut(
        Request(
          'POST',
          Uri.parse('http://localhost/api/v0/dag/put?input-codec=cbor'),
          body: cborBytes,
        ),
      );
      expect(response.statusCode, equals(200));

      // json input alias with the dag-json store codec. The store codec
      // names the CID codec directly, so it must be the canonical name.
      response = await handlers.handleDagPut(
        Request(
          'POST',
          Uri.parse(
            'http://localhost/api/v0/dag/put?input-codec=json'
            '&store-codec=dag-json',
          ),
          body: utf8.encode('{"b":2}'),
        ),
      );
      expect(response.statusCode, equals(200));

      // dag-pb input with the dag-pb store codec (the protobuf alias
      // shares this switch case).
      final pbBytes = dag_pb.PBNode(
        data: unixfs_pb.Data(type: unixfs_pb.Data_DataType.Raw).writeToBuffer(),
      ).writeToBuffer();
      response = await handlers.handleDagPut(
        Request(
          'POST',
          Uri.parse(
            'http://localhost/api/v0/dag/put?input-codec=dag-pb'
            '&store-codec=dag-pb',
          ),
          body: pbBytes,
        ),
      );
      expect(response.statusCode, equals(200));

      // raw input with the raw store codec.
      response = await handlers.handleDagPut(
        Request(
          'POST',
          Uri.parse(
            'http://localhost/api/v0/dag/put?input-codec=raw'
            '&store-codec=raw',
          ),
          body: Uint8List.fromList([9, 9]),
        ),
      );
      expect(response.statusCode, equals(200));
      verify(mockBlockStore.putBlock(any)).called(greaterThanOrEqualTo(4));
    });

    test('handleDagPut rejects unsupported codecs', () async {
      var response = await handlers.handleDagPut(
        Request(
          'POST',
          Uri.parse('http://localhost/api/v0/dag/put?input-codec=bogus'),
          body: Uint8List.fromList([1]),
        ),
      );
      expect(response.statusCode, equals(500));

      response = await handlers.handleDagPut(
        Request(
          'POST',
          Uri.parse('http://localhost/api/v0/dag/put?store-codec=bogus'),
          body: utf8.encode('{"a":1}'),
        ),
      );
      expect(response.statusCode, equals(500));
    });

    test(
      'handleDagPut reads multipart bodies and enforces its limits',
      () async {
        when(mockNode.pin(any)).thenAnswer((_) async {});
        const boundary = 'db';

        // Multipart file upload.
        final body = multipartBody(boundary, '{"m":1}');
        var response = await handlers.handleDagPut(
          Request(
            'POST',
            Uri.parse('http://localhost/api/v0/dag/put?pin=false'),
            headers: {
              'content-type': 'multipart/form-data; boundary=$boundary',
            },
            body: body,
          ),
        );
        expect(response.statusCode, equals(200));

        // Multipart content type without a boundary parameter.
        response = await handlers.handleDagPut(
          Request(
            'POST',
            Uri.parse('http://localhost/api/v0/dag/put'),
            headers: {'content-type': 'multipart/form-data'},
            body: 'x',
          ),
        );
        expect(response.statusCode, equals(500));

        // Multipart framing with no file part at all.
        response = await handlers.handleDagPut(
          Request(
            'POST',
            Uri.parse('http://localhost/api/v0/dag/put'),
            headers: {
              'content-type': 'multipart/form-data; boundary=$boundary',
            },
            body: '--$boundary--\r\n',
          ),
        );
        expect(response.statusCode, equals(500));

        // A part over the 8 MiB cap is rejected.
        final oversized = Uint8List(8 * 1024 * 1024 + 1);
        final huge =
            '--$boundary\r\n'
            'Content-Disposition: form-data; name="f"; filename="f"\r\n'
            '\r\n';
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/v0/dag/put'),
          headers: {'content-type': 'multipart/form-data; boundary=$boundary'},
          body: Stream.fromIterable([
            utf8.encode(huge),
            oversized,
            utf8.encode('\r\n--$boundary--\r\n'),
          ]),
        );
        response = await handlers.handleDagPut(request);
        expect(response.statusCode, equals(500));
      },
    );

    test('handleDagImport reports stats when requested', () async {
      final block = await Block.fromData(Uint8List.fromList([5, 5, 5]));
      final writer = CarWriter(roots: [coreCid(block.cid)]);
      await writer.write(coreCid(block.cid), block.data);
      final carData = await writer.close();

      final response = await handlers.handleDagImport(
        Request(
          'POST',
          Uri.parse('http://localhost/api/v0/dag/import?stats=true'),
          body: carData,
        ),
      );
      expect(response.statusCode, equals(200));
      final body = await response.readAsString();
      expect(body, contains('"Stats"'));
      expect(body, contains('"BlockCount":1'));
    });

    test('DAG export enforces the maximum block-count bound', () async {
      final block = await Block.fromData(
        Uint8List.fromList([1]),
        format: 'raw',
      );
      final visited = <String>{for (var i = 0; i < 10000; i++) 'k$i'};
      final mirror = mirrors.reflect(handlers);
      final exportSym = mirror.type.declarations.keys.firstWhere(
        (s) => mirrors.MirrorSystem.getName(s) == '_exportBlock',
      );
      await expectLater(
        mirror.invoke(exportSym, [
              block.cid,
              CarWriter(roots: [coreCid(block.cid)]),
              visited,
            ]).reflectee
            as Future<void>,
        throwsStateError,
      );
    });

    test('DAG export treats dag-pb format hints as traversable', () async {
      // A block whose CID codec is not dag-pb but whose stored format hint
      // is dag-pb still has its links traversed (legacy format fallback).
      final child = await Block.fromData(
        Uint8List.fromList([7]),
        format: 'raw',
      );
      storeBlock(child);
      final pbBytes = dag_pb.PBNode(
        links: [dag_pb.PBLink(name: 'c', hash: child.cid.toBytes())],
      ).writeToBuffer();
      final rawCidBlock = Block(
        cid: (await Block.fromData(pbBytes, format: 'raw')).cid,
        data: pbBytes,
        format: 'dag-pb',
      );
      storeBlock(rawCidBlock);

      final response = await handlers.handleDagExport(
        Request(
          'POST',
          Uri.parse(
            'http://localhost/api/v0/dag/export?arg=${rawCidBlock.cid}',
          ),
        ),
      );
      expect(response.statusCode, equals(200));
      final reader = CarReader.fromBytes(
        Uint8List.fromList(await response.read().expand((i) => i).toList()),
      );
      final sections = await reader.sections().toList();
      expect(sections.length, equals(2));
    });
  });

  group('pubsub handlers', () {
    test('handlePubsubPublish publishes the raw body', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/pubsub/pub?arg=topic-a'),
        body: utf8.encode('hello'),
      );
      final response = await handlers.handlePubsubPublish(request);
      expect(response.statusCode, equals(200));
      verify(mockNode.publishData('topic-a', utf8.encode('hello'))).called(1);
    });

    test('handlePubsubPublish passes binary bodies through verbatim', () async {
      final payload = Uint8List.fromList(List<int>.generate(256, (i) => i));
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/pubsub/pub?arg=topic-a'),
        body: payload,
      );
      final response = await handlers.handlePubsubPublish(request);
      expect(response.statusCode, equals(200));
      verify(mockNode.publishData('topic-a', payload)).called(1);
      verifyNever(mockNode.publish(any, any));
    });

    test('handlePubsubPublish rejects a missing topic', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/pubsub/pub'),
        body: utf8.encode('hello'),
      );
      final response = await handlers.handlePubsubPublish(request);
      expect(response.statusCode, equals(400));
      verifyNever(mockNode.publishData(any, any));
    });

    test('handlePubsubPublish surfaces node errors', () async {
      when(
        mockNode.publishData('topic-a', any),
      ).thenThrow(Exception('not started'));
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/pubsub/pub?arg=topic-a'),
        body: utf8.encode('hello'),
      );
      final response = await handlers.handlePubsubPublish(request);
      expect(response.statusCode, equals(500));
    });

    test('handlePubsubPublish rejects an oversized body', () async {
      // Bodies are capped at 1 MiB; an oversized payload is a client
      // error, not a node failure.
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/pubsub/pub?arg=topic-a'),
        body: Uint8List(1024 * 1024 + 1),
      );
      final response = await handlers.handlePubsubPublish(request);
      expect(response.statusCode, equals(400));
      verifyNever(mockNode.publishData(any, any));
    });

    test('handlePubsubSubscribe decodes multibase base64url arg', () async {
      final controller = StreamController<PubSubMessage>();
      when(mockNode.pubsubMessages).thenAnswer((_) => controller.stream);

      // Kubo-style clients send the topic as `u`-prefixed unpadded
      // base64url; 'topic-a' -> 'dG9waWMtYQ'.
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/pubsub/sub?arg=udG9waWMtYQ'),
      );
      final response = await handlers.handlePubsubSubscribe(request);
      expect(response.statusCode, equals(200));
      verify(mockNode.subscribe('topic-a')).called(1);
      await controller.close();
    });

    test('handlePubsubPublish decodes multibase base64url arg', () async {
      when(mockNode.publishData('topic-a', any)).thenAnswer((_) async {});
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/pubsub/pub?arg=udG9waWMtYQ'),
        body: utf8.encode('hello'),
      );
      final response = await handlers.handlePubsubPublish(request);
      expect(response.statusCode, equals(200));
      verify(mockNode.publishData('topic-a', utf8.encode('hello'))).called(1);
    });

    test('handlePubsubSubscribe streams NDJSON messages', () async {
      final controller = StreamController<PubSubMessage>();
      when(mockNode.pubsubMessages).thenAnswer((_) => controller.stream);

      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/pubsub/sub?arg=topic-a'),
      );
      final response = await handlers.handlePubsubSubscribe(request);
      expect(response.statusCode, equals(200));
      verify(mockNode.subscribe('topic-a')).called(1);

      controller.add(
        PubSubMessage(topic: 'topic-a', sender: 'QmSender', content: 'hi'),
      );
      controller.add(
        PubSubMessage(topic: 'other', sender: 'QmSender', content: 'skip'),
      );
      final line = await response
          .read()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .firstWhere((l) => l.trim().isNotEmpty)
          .timeout(const Duration(seconds: 5));
      final json = jsonDecode(line) as Map<String, dynamic>;
      expect(json['from'], equals('QmSender'));
      // Multibase `u` (base64url) is unpadded per spec.
      expect(
        json['data'],
        equals('u${base64Url.encode(utf8.encode('hi')).replaceAll('=', '')}'),
      );
      expect(
        json['topicIDs'],
        equals([
          'u${base64Url.encode(utf8.encode('topic-a')).replaceAll('=', '')}',
        ]),
      );
      await controller.close();
    });

    test(
      'handlePubsubSubscribe encodes raw message bytes in the data field',
      () async {
        final controller = StreamController<PubSubMessage>();
        when(mockNode.pubsubMessages).thenAnswer((_) => controller.stream);

        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/v0/pubsub/sub?arg=topic-a'),
        );
        final response = await handlers.handlePubsubSubscribe(request);
        expect(response.statusCode, equals(200));

        final payload = Uint8List.fromList(List<int>.generate(256, (i) => i));
        controller.add(
          PubSubMessage(
            topic: 'topic-a',
            sender: 'QmSender',
            content: utf8.decode(payload, allowMalformed: true),
            data: payload,
          ),
        );
        final line = await response
            .read()
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .firstWhere((l) => l.trim().isNotEmpty)
            .timeout(const Duration(seconds: 5));
        final json = jsonDecode(line) as Map<String, dynamic>;
        // `data` must round-trip the raw wire bytes — re-encoding the
        // lossy UTF-8 `content` view would corrupt the payload.
        expect(
          json['data'],
          equals('u${base64Url.encode(payload).replaceAll('=', '')}'),
        );
        await controller.close();
      },
    );

    test('handlePubsubSubscribe rejects a missing topic', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/pubsub/sub'),
      );
      final response = await handlers.handlePubsubSubscribe(request);
      expect(response.statusCode, equals(400));
      verifyNever(mockNode.subscribe(any));
    });

    test('handlePubsubSubscribe surfaces subscribe errors', () async {
      when(mockNode.subscribe('topic-a')).thenThrow(Exception('failed'));
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/pubsub/sub?arg=topic-a'),
      );
      final response = await handlers.handlePubsubSubscribe(request);
      expect(response.statusCode, equals(500));
    });

    test(
      'handlePubsubSubscribe unsubscribes when the client disconnects',
      () async {
        final controller = StreamController<PubSubMessage>();
        when(mockNode.pubsubMessages).thenAnswer((_) => controller.stream);
        when(mockNode.pubsubLs()).thenReturn(const []);

        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/v0/pubsub/sub?arg=topic-a'),
        );
        final response = await handlers.handlePubsubSubscribe(request);
        expect(response.statusCode, equals(200));
        verify(mockNode.subscribe('topic-a')).called(1);

        // Cancelling the response body mimics the HTTP client going away.
        await response.read().listen((_) {}).cancel();
        verify(mockNode.unsubscribe('topic-a')).called(1);
        await controller.close();
      },
    );

    test(
      'handlePubsubSubscribe keeps the topic while a subscriber remains',
      () async {
        // Broadcast, matching PubSubClient.messagesStream — the node serves
        // concurrent pubsub/sub consumers.
        final controller = StreamController<PubSubMessage>.broadcast();
        when(mockNode.pubsubMessages).thenAnswer((_) => controller.stream);
        when(mockNode.pubsubLs()).thenReturn(const []);

        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/v0/pubsub/sub?arg=topic-a'),
        );
        final first = await handlers.handlePubsubSubscribe(request);
        final second = await handlers.handlePubsubSubscribe(request);
        verify(mockNode.subscribe('topic-a')).called(2);

        await first.read().listen((_) {}).cancel();
        verifyNever(mockNode.unsubscribe('topic-a'));

        await second.read().listen((_) {}).cancel();
        verify(mockNode.unsubscribe('topic-a')).called(1);
        await controller.close();
      },
    );

    test(
      'handlePubsubSubscribe never unsubscribes a pre-existing topic',
      () async {
        final controller = StreamController<PubSubMessage>();
        when(mockNode.pubsubMessages).thenAnswer((_) => controller.stream);
        // The node already owns this subscription (e.g. a library caller
        // subscribed before the RPC client arrived) — the RPC surface must
        // not tear it down on disconnect.
        when(mockNode.pubsubLs()).thenReturn(const ['topic-a']);

        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/v0/pubsub/sub?arg=topic-a'),
        );
        final response = await handlers.handlePubsubSubscribe(request);
        expect(response.statusCode, equals(200));

        await response.read().listen((_) {}).cancel();
        verifyNever(mockNode.unsubscribe('topic-a'));
        await controller.close();
      },
    );

    test(
      'handlePubsubSubscribe swallows unsubscribe failures on disconnect',
      () async {
        final controller = StreamController<PubSubMessage>();
        when(mockNode.pubsubMessages).thenAnswer((_) => controller.stream);
        when(mockNode.pubsubLs()).thenReturn(const []);
        when(mockNode.unsubscribe('topic-a')).thenThrow(Exception('gone'));

        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/v0/pubsub/sub?arg=topic-a'),
        );
        final response = await handlers.handlePubsubSubscribe(request);
        expect(response.statusCode, equals(200));

        // The cleanup path must not propagate a failed unsubscribe — the
        // client is already gone.
        await response.read().listen((_) {}).cancel();
        verify(mockNode.unsubscribe('topic-a')).called(1);
        await controller.close();
      },
    );

    test('handlePubsubLs surfaces node errors', () async {
      when(mockNode.pubsubLs()).thenThrow(Exception('ls failed'));
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/pubsub/ls'),
      );
      final response = await handlers.handlePubsubLs(request);
      expect(response.statusCode, equals(500));
    });

    test('handlePubsubPeers surfaces node errors', () async {
      when(mockNode.pubsubPeers('topic-a')).thenThrow(Exception('peers'));
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/pubsub/peers?arg=topic-a'),
      );
      final response = await handlers.handlePubsubPeers(request);
      expect(response.statusCode, equals(500));
    });

    test('handlePubsubLs returns the topic list', () async {
      when(mockNode.pubsubLs()).thenReturn(['a', 'b']);
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/pubsub/ls'),
      );
      final response = await handlers.handlePubsubLs(request);
      expect(response.statusCode, equals(200));
      final body = json.decode(await response.readAsString());
      expect(body['Strings'], equals(['a', 'b']));
    });

    test('handlePubsubPeers returns peers for the topic', () async {
      when(
        mockNode.pubsubPeers('topic-a'),
      ).thenAnswer((_) async => ['QmA', 'QmB']);
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/pubsub/peers?arg=topic-a'),
      );
      final response = await handlers.handlePubsubPeers(request);
      expect(response.statusCode, equals(200));
      final body = json.decode(await response.readAsString());
      expect(body['Strings'], equals(['QmA', 'QmB']));
    });

    test('handlePubsubPeers without arg returns an empty list', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/pubsub/peers'),
      );
      final response = await handlers.handlePubsubPeers(request);
      expect(response.statusCode, equals(200));
      final body = json.decode(await response.readAsString());
      expect(body['Strings'], isEmpty);
    });
  });
}

class _FakeBitswapHandler extends Mock implements BitswapHandler {
  _FakeBitswapHandler(this._block);

  final Block _block;

  @override
  Future<Block?> wantBlock(String cid) async =>
      cid == _block.cid.encode() ? _block : null;
}
