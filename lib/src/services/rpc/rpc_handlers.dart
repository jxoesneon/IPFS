// lib/src/services/rpc/rpc_handlers.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:shelf/shelf.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:p2plib/p2plib.dart' show PeerId;
import 'package:dart_ipfs/src/utils/base58.dart';

/// Handlers for IPFS RPC API endpoints
/// 
/// Implements Kubo-compatible RPC methods
class RPCHandlers {
  final IPFSNode node;

  RPCHandlers(this.node);

  /// GET /api/v0/version - Get IPFS version
  Future<Response> handleVersion(Request request) async {
    final response = {
      'Version': 'dart_ipfs/0.1.0',
      'Commit': 'phase3-gateway-rpc',
      'Repo': '1',
      'System': Platform.operatingSystem,
      'Golang': 'Dart ${Platform.version}',
    };

    return _jsonResponse(response);
  }

  /// POST /api/v0/id - Get peer identity
  Future<Response> handleId(Request request) async {
    try {
      final peerId = node.peerId;
      final addresses = node.addresses;

      final response = {
        'ID': peerId,
        'PublicKey': '', // TODO: Get from keystore
        'Addresses': addresses,
        'AgentVersion': 'dart_ipfs/0.1.0',
        'ProtocolVersion': 'ipfs/0.1.0',
        'Protocols': ['/ipfs/kad/1.0.0', '/ipfs/bitswap/1.2.0'],
      };

      return _jsonResponse(response);
    } catch (e) {
      return _errorResponse('Failed to get node ID: $e');
    }
  }

  /// POST /api/v0/add - Add file(s)
  Future<Response> handleAdd(Request request) async {
    try {
      // TODO: Parse multipart/form-data
      // For now, return not implemented
      return Response(501, body: json.encode({
        'Message': 'File upload not yet implemented',
        'Code': 0,
        'Type': 'error'
      }));
    } catch (e) {
      return _errorResponse('Add failed: $e');
    }
  }

  /// POST /api/v0/cat - Get file content
  Future<Response> handleCat(Request request) async {
    try {
      final cid = request.url.queryParameters['arg'];
      if (cid == null || cid.isEmpty) {
        return _errorResponse('Missing argument: cid');
      }

      final content = await node.cat(cid);
      return Response.ok(content);
    } catch (e) {
      return _errorResponse('Cat failed: $e');
    }
  }

  /// POST /api/v0/get - Download file/directory
  Future<Response> handleGet(Request request) async {
    // Similar to cat but with tar archive support
    return Response(501, body: 'Not implemented');
  }

  /// POST /api/v0/ls - List directory
  Future<Response> handleLs(Request request) async {
    try {
      final path = request.url.queryParameters['arg'];
      if (path == null || path.isEmpty) {
        return _errorResponse('Missing argument: path');
      }

      final entries = await node.ls(path);
      final objects = entries.map((e) => {
        'Name': e.name,
        'Hash': e.cid.encode(),
        'Size': e.size.toInt(),
        'Type': 'file', // Default as Link doesn't carry type
      }).toList();

      final response = {
        'Objects': [
          {
            'Hash': path,
            'Links': objects,
          }
        ]
      };

      return _jsonResponse(response);
    } catch (e) {
      return _errorResponse('Ls failed: $e');
    }
  }

  /// POST /api/v0/dag/get - Get DAG node
  Future<Response> handleDagGet(Request request) async {
    final cid = request.url.queryParameters['arg'];
    if (cid == null) {
      return _errorResponse('Missing argument: cid');
    }

    try {
      // Get block and return as JSON
      final block = await node.blockStore.getBlock(cid);
      if (!block.found) {
        return _errorResponse('Block not found: $cid', code: 404);
      }

      // Return raw block data (could be enhanced to parse UnixFS/CBOR)
      return Response.ok(block.block.data);
    } catch (e) {
      return _errorResponse('DAG get failed: $e');
    }
  }

  /// POST /api/v0/dag/put - Add DAG node
  Future<Response> handleDagPut(Request request) async {
    return Response(501, body: 'Not implemented');
  }

  /// POST /api/v0/dht/findprovs - Find providers for CID
  Future<Response> handleDhtFindProviders(Request request) async {
    final cid = request.url.queryParameters['arg'];
    if (cid == null) {
      return _errorResponse('Missing argument: cid');
    }

    try {
      final providers = await node.dhtClient.findProviders(cid);
      
      // Stream response (ndjson format)
      final responses = providers.map((p) => json.encode({
        'Type': 4, // Provider type
        'Responses': [{
          'ID': p.toString(),
          'Addrs': [], // TODO: Get addresses
        }]
      })).join('\n');

      return Response.ok(responses, headers: {
        'Content-Type': 'application/json',
        'X-Stream-Output': '1',
      });
    } catch (e) {
      return _errorResponse('DHT findprovs failed: $e');
    }
  }

  /// POST /api/v0/dht/findpeer - Find peer by ID
  Future<Response> handleDhtFindPeer(Request request) async {
    final peerId = request.url.queryParameters['arg'];
    if (peerId == null) {
      return _errorResponse('Missing argument: peerID');
    }

    try {
      final found = await node.dhtClient.findPeer(PeerId(value: Base58().base58Decode(peerId)));
      if (found != null) {
        return _jsonResponse({
          'Type': 2,
          'Responses': [{
            'ID': found.toString(),
            'Addrs': [], // TODO
          }]
        });
      } else {
        return _errorResponse('Peer not found');
      }
    } catch (e) {
      return _errorResponse('DHT findpeer failed: $e');
    }
  }

  /// POST /api/v0/dht/provide - Announce provider
  Future<Response> handleDhtProvide(Request request) async {
    final cid = request.url.queryParameters['arg'];
    if (cid == null) {
      return _errorResponse('Missing argument: cid');
    }

    try {
      await node.dhtClient.addProvider(cid, node.peerId);
      return _jsonResponse({'Success': true});
    } catch (e) {
      return _errorResponse('DHT provide failed: $e');
    }
  }

  /// POST /api/v0/name/publish - Publish IPNS record
  Future<Response> handleNamePublish(Request request) async {
    final path = request.url.queryParameters['arg'];
    if (path == null) {
      return _errorResponse('Missing argument: path');
    }

    try {
      await node.publishIPNS(path, keyName: 'self');
      return _jsonResponse({
        'Name': 'self',
        'Value': path,
      });
    } catch (e) {
      return _errorResponse('Name publish failed: $e');
    }
  }

  /// POST /api/v0/name/resolve - Resolve IPNS name
  Future<Response> handleNameResolve(Request request) async {
    final name = request.url.queryParameters['arg'];
    if (name == null) {
      return _errorResponse('Missing argument: name');
    }

    try {
      final path = await node.resolveIPNS(name);
      return _jsonResponse({
        'Path': path,
      });
    } catch (e) {
      return _errorResponse('Name resolve failed: $e');
    }
  }

  /// POST /api/v0/swarm/peers - List connected peers
  Future<Response> handleSwarmPeers(Request request) async {
    try {
      final peers = node.connectedPeers;
      final peerList = peers.map((p) => {
        'Peer': p,
        'Addr': '',
      }).toList();

      return _jsonResponse({'Peers': peerList});
    } catch (e) {
      return _errorResponse('Swarm peers failed: $e');
    }
  }

  /// POST /api/v0/swarm/connect - Connect to peer
  Future<Response> handleSwarmConnect(Request request) async {
    final addr = request.url.queryParameters['arg'];
    if (addr == null) {
      return _errorResponse('Missing argument: multiaddr');
    }

    try {
      await node.connectToPeer(addr);
      return _jsonResponse({
        'Strings': ['connect $addr success']
      });
    } catch (e) {
      return _errorResponse('Swarm connect failed: $e');
    }
  }

  /// POST /api/v0/swarm/disconnect - Disconnect from peer
  Future<Response> handleSwarmDisconnect(Request request) async {
    final addr = request.url.queryParameters['arg'];
    if (addr == null) {
      return _errorResponse('Missing argument: multiaddr');
    }

    try {
      await node.disconnectFromPeer(addr);
      return _jsonResponse({
        'Strings': ['disconnect $addr success']
      });
    } catch (e) {
      return _errorResponse('Swarm disconnect failed: $e');
    }
  }

  /// POST /api/v0/block/get - Get raw block
  Future<Response> handleBlockGet(Request request) async {
    final cid = request.url.queryParameters['arg'];
    if (cid == null) {
      return _errorResponse('Missing argument: cid');
    }

    try {
      final block = await node.blockStore.getBlock(cid);
      if (!block.found) {
        return _errorResponse('Block not found', code: 404);
      }

      return Response.ok(block.block.data);
    } catch (e) {
      return _errorResponse('Block get failed: $e');
    }
  }

  /// POST /api/v0/block/put - Add raw block
  Future<Response> handleBlockPut(Request request) async {
    try {
      final data = await request.read().toList();
      final bytes = data.expand((x) => x).toList();
      
      final cid = await CID.fromContent(Uint8List.fromList(bytes));
      // TODO: Store block
      
      return _jsonResponse({
        'Key': cid.encode(),
        'Size': bytes.length,
      });
    } catch (e) {
      return _errorResponse('Block put failed: $e');
    }
  }

  /// POST /api/v0/block/stat - Get block stats
  Future<Response> handleBlockStat(Request request) async {
    final cid = request.url.queryParameters['arg'];
    if (cid == null) {
      return _errorResponse('Missing argument: cid');
    }

    try {
      final block = await node.blockStore.getBlock(cid);
      if (!block.found) {
        return _errorResponse('Block not found', code: 404);
      }

      return _jsonResponse({
        'Key': cid,
        'Size': block.block.data.length,
      });
    } catch (e) {
      return _errorResponse('Block stat failed: $e');
    }
  }

  // Helper methods

  Response _jsonResponse(Map<String, dynamic> data) {
    return Response.ok(
      json.encode(data),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Response _errorResponse(String message, {int code = 500}) {
    return Response(code, 
      body: json.encode({
        'Message': message,
        'Code': 0,
        'Type': 'error'
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
