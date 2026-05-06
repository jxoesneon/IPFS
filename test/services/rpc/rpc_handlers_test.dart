import 'dart:convert';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dart_ipfs/src/services/rpc/rpc_handlers.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_client.dart';
import 'package:dart_ipfs/src/core/data_structures/link.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/utils/base58.dart';
import 'package:shelf/shelf.dart';
import 'dart:typed_data';

import 'rpc_handlers_test.mocks.dart';

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
        mockNode.cat(cid),
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
      verify(mockDHTClient.addProvider(cid, 'QmPeer')).called(1);
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
    });

    test('handleLs missing arg', () async {
      final request = Request('POST', Uri.parse('http://localhost/api/v0/ls'));
      final response = await handlers.handleLs(request);
      expect(response.statusCode, equals(500));
    });

    test('handleDagGet success', () async {
      final cid = 'QmHash';
      final block = Block(
        cid: CID.decode('QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn'),
        data: Uint8List.fromList([1, 2, 3]),
      );
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
      expect(
        await response.read().expand((i) => i).toList(),
        equals([1, 2, 3]),
      );
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
      verify(mockNode.publishIPNS(path, keyName: 'self')).called(1);
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

    test('handleGet returns 501', () async {
      final request = Request('POST', Uri.parse('http://localhost/api/v0/get'));
      final response = await handlers.handleGet(request);
      expect(response.statusCode, equals(501));
    });

    test('handleDagPut returns 501', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/dag/put'),
      );
      final response = await handlers.handleDagPut(request);
      expect(response.statusCode, equals(501));
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
      final cid = 'QmHash';
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
  });
}
