import 'dart:convert';
import 'package:dart_ipfs/dart_ipfs.dart';
import 'package:dart_ipfs/src/services/rpc/rpc_handlers.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  group('RPC Protocol Tests', () {
    late IPFSNode node;
    late RPCHandlers rpcHandlers;

    setUp(() async {
      final config = IPFSConfig(
        dataPath:
            './test_data_rpc_bug/${DateTime.now().millisecondsSinceEpoch}',
        offline: true,
      );
      node = await IPFSNode.create(config);
      await node.start();
      rpcHandlers = RPCHandlers(node);
    });

    tearDown(() async {
      await node.stop();
    });

    test('handleBlockPut should store the block', () async {
      final content = utf8.encode('Hello RPC World');
      final request = Request(
        'POST',
        Uri.parse('http://localhost:5001/api/v0/block/put'),
        body: content,
      );

      final response = await rpcHandlers.handleBlockPut(request);
      expect(response.statusCode, equals(200));

      final jsonResponse = json.decode(await response.readAsString());
      final key = jsonResponse['Key'];

      print('Put block with Key: $key');

      // Verify block is stored
      final block = await node.blockStore.getBlock(key);
      expect(block.found, isTrue,
          reason: 'Block should be found in store after put');
      expect(block.block.data, equals(content));
    });
  });
}
