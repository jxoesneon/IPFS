import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/data_structures/link.dart';
import 'package:dart_ipfs/src/core/data_structures/pin_manager.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/proto/generated/core/block.pb.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_client.dart';
import 'package:dart_ipfs/src/services/rpc/rpc_handlers.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

// Mock BlockStore
class MockBlockStore implements BlockStore {
  final Map<String, Block> blocks = {};

  @override
  Future<GetBlockResponse> getBlock(String cid) async {
    if (blocks.containsKey(cid)) {
      final b = blocks[cid]!;
      final blockProto = BlockProto()
        ..cid = b.cid.toProto()
        ..data = b.data;
      return GetBlockResponse()
        ..found = true
        ..block = blockProto;
    }
    return GetBlockResponse()..found = false;
  }

  @override
  Future<AddBlockResponse> putBlock(Block block) async {
    blocks[block.cid.encode()] = block;
    return AddBlockResponse();
  }

  // Stubs
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  String get path => '';
  @override
  Future<List<Block>> getAllBlocks() async => [];
  @override
  Future<bool> hasBlock(String cid) async => blocks.containsKey(cid);
  @override
  Future<RemoveBlockResponse> removeBlock(String cid) async => RemoveBlockResponse();
  @override
  Future<Map<String, dynamic>> getStatus() async => {};
  @override
  PinManager get pinManager => throw UnimplementedError('Mock');
}

// Mock DHTClient
class MockDHTClient implements DHTClient {
  @override
  Future<List<PeerId>> findProviders(String cid) async {
    return [];
  }

  @override
  Future<PeerId?> findPeer(PeerId id) async {
    // If searching for existing peer
    return id;
  }

  @override
  Future<void> addProvider(String cid, String providerId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Mock IPFSNode
class MockIPFSNode implements IPFSNode {
  final MockBlockStore _blockStore = MockBlockStore();
  final MockDHTClient _dhtClient = MockDHTClient();

  @override
  String get peerId => 'QmTestNode';

  @override
  List<String> get addresses => ['/ip4/127.0.0.1/tcp/4001'];

  @override
  BlockStore get blockStore => _blockStore;

  @override
  DHTClient get dhtClient => _dhtClient;

  @override
  Future<Uint8List?> cat(String cid) async {
    final block = await _blockStore.getBlock(cid);
    if (block.found) return Uint8List.fromList(block.block.data);
    return null; // Or throw? IPFSNode.cat logic usually returns data.
  }

  @override
  Future<List<Link>> ls(String cid) async {
    // Mock ls to return empty list or dummy
    if (cid == 'QmDir') {
      return [
        Link(name: 'file.txt', cid: CID.computeForDataSync(utf8.encode('content')), size: 100),
      ];
    }
    return [];
  }

  @override
  Future<List<String>> get connectedPeers => Future.value(['QmPeer1']);

  @override
  Future<void> connectToPeer(String multiaddr) async {}

  @override
  Future<void> disconnectFromPeer(String peerId) async {}

  @override
  Future<void> publishIPNS(String cid, {required String keyName}) async {}

  @override
  Future<String> resolveIPNS(String name) async => '/ipfs/QmResolved';

  @override
  Future<String> get publicKey => Future.value('CAESIQ...');

  @override
  List<String> resolvePeerId(String peerIdStr) => ['/ip4/127.0.0.1/tcp/4001'];

  @override
  Future<String> addFile(Uint8List data) async {
    final cid = CID.computeForDataSync(data);
    await _blockStore.putBlock(Block(cid: cid, data: data));
    return cid.encode();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('RPCHandlers', () {
    late MockIPFSNode node;
    late RPCHandlers handlers;

    setUp(() {
      node = MockIPFSNode();
      handlers = RPCHandlers(node);
    });

    test('handleVersion returns version info', () async {
      final request = Request('GET', Uri.parse('http://localhost/api/v0/version'));
      final response = await handlers.handleVersion(request);
      expect(response.statusCode, 200);
    });

    test('handleId returns identity info', () async {
      final request = Request('POST', Uri.parse('http://localhost/api/v0/id'));
      final response = await handlers.handleId(request);
      final body = json.decode(await response.readAsString());
      expect(body['ID'], 'QmTestNode');
      expect(body['Addresses'], isNotEmpty);
    });

    test('handleCat retrieves content', () async {
      final data = Uint8List.fromList(utf8.encode('Hello Cat'));
      final cid = CID.computeForDataSync(data);
      final cidStr = cid.encode();

      await node.blockStore.putBlock(Block(cid: cid, data: data));

      final request = Request('POST', Uri.parse('http://localhost/api/v0/cat?arg=$cidStr'));
      final response = await handlers.handleCat(request);
      expect(response.statusCode, 200);
      expect(await response.readAsString(), 'Hello Cat');
    });

    test('handleLs lists directory', () async {
      final request = Request('POST', Uri.parse('http://localhost/api/v0/ls?arg=QmDir'));
      final response = await handlers.handleLs(request);
      final body = json.decode(await response.readAsString());
      expect(body['Objects'], isNotEmpty);
      expect(body['Objects'][0]['Links'], isNotEmpty);
    });

    test('handleBlockPut stores block', () async {
      final data = utf8.encode('Block Data');
      final request = Request('POST', Uri.parse('http://localhost/api/v0/block/put'), body: data);
      final response = await handlers.handleBlockPut(request);
      final body = json.decode(await response.readAsString());

      expect(body['Key'], isNotNull);
      expect(body['Key'], isNotNull);
      expect(body['Key'], isNotNull);
      final String cidStr = body['Key'] as String;
      final stored = await node.blockStore.getBlock(cidStr);
      expect(stored.found, isTrue);
    });

    test('handleBlockGet retrieves block', () async {
      final data = Uint8List.fromList(utf8.encode('Block Content'));
      final cid = CID.computeForDataSync(data);
      final cidStr = cid.encode();
      await node.blockStore.putBlock(Block(cid: cid, data: data));

      final request = Request('POST', Uri.parse('http://localhost/api/v0/block/get?arg=$cidStr'));
      final response = await handlers.handleBlockGet(request);
      expect(await response.readAsString(), 'Block Content');
    });

    test('handleDhtFindProviders', () async {
      final request = Request('POST', Uri.parse('http://localhost/api/v0/dht/findprovs?arg=QmCid'));
      final response = await handlers.handleDhtFindProviders(request);
      // Should trigger internal error? dhtClient.findProviders returns dummy.
      // Response is ndjson.
      // Expect success (empty response for no providers)
      expect(response.statusCode, 200);
      // expect(body, contains('"Type":4')); // No providers returned
    });

    test('handleAdd accepts multipart upload', () async {
      final boundary = 'boundary';
      final fileContent = 'Hello IPFS';
      final body =
          '--$boundary\r\n'
          'Content-Disposition: form-data; name="file"; filename="test.txt"\r\n'
          'Content-Type: text/plain\r\n'
          '\r\n'
          '$fileContent\r\n'
          '--$boundary--\r\n';

      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/add'),
        headers: {'content-type': 'multipart/form-data; boundary=$boundary'},
        body: body,
      );

      final response = await handlers.handleAdd(request);
      expect(response.statusCode, 200);

      final responseBody = await response.readAsString();
      final jsonResponse = json.decode(responseBody);

      expect(jsonResponse['Name'], 'test.txt');
      expect(jsonResponse['Hash'], isNotEmpty);
      expect(jsonResponse['Size'], isNotEmpty);

      // Verify content was added to store
      final String cid = jsonResponse['Hash'] as String;
      final storedBlock = await node.blockStore.getBlock(cid);
      expect(storedBlock.found, isTrue);
      expect(utf8.decode(storedBlock.block.data), fileContent);
    });

    test('handleSwarmPeers', () async {
      final request = Request('POST', Uri.parse('http://localhost/api/v0/swarm/peers'));
      final response = await handlers.handleSwarmPeers(request);
      final body = json.decode(await response.readAsString());
      expect(body['Peers'], isNotEmpty);
    });
  });
}
