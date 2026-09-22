// lib/src/services/rpc/rpc_handlers.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/car.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/core/ipld/codecs/standard_codecs.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_builder.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_directory.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_reader.dart';
import 'package:dart_ipfs/src/platform/platform.dart';
import 'package:dart_ipfs/src/proto/dag_marshal.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart' as dag_pb;
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart'
    as unixfs_pb;
import 'package:dart_ipfs/src/protocols/pubsub/pubsub_message.dart';
import 'package:dart_ipfs/src/services/rpc/mfs_handlers.dart';
import 'package:dart_ipfs/src/utils/base58.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:dart_ipfs/src/version.dart';
import 'package:fixnum/fixnum.dart';
import 'package:http_parser/http_parser.dart'; // For MediaType
import 'package:mime/mime.dart';
import 'package:shelf/shelf.dart';

/// Handlers for IPFS RPC API endpoints
///
/// Implements Kubo-compatible RPC methods
class RPCHandlers {
  /// Creates a new [RPCHandlers] with the given [node].
  RPCHandlers(this.node) : mfsHandlers = MFSHandlers(node);

  /// The IPFS node to control via RPC.
  final IPFSNode node;

  /// Handlers for the `/api/v0/files/*` MFS endpoint surface.
  final MFSHandlers mfsHandlers;

  final _logger = Logger('RPCHandlers');

  /// Maximum buffered request body for [handleDagImport] (matches the
  /// `handleAdd` total request cap).
  static const int _maxImportBodyBytes = 1024 * 1024 * 1024;

  /// Maximum buffered request body for [handleBlockPut] — a single block,
  /// matching the 4 MiB inbound libp2p message cap.
  static const int _maxBlockPutBytes = 4 * 1024 * 1024;

  /// Maximum buffered request body for [handleDagPut] — a single DAG node.
  static const int _maxDagPutBytes = 8 * 1024 * 1024;

  /// Maximum buffered request body for [handlePubsubPublish] — a pubsub
  /// payload is a single message, so 1 MiB is generous.
  static const int _maxPubsubPubBytes = 1024 * 1024;

  /// Active `pubsub/sub` stream count per topic. The node-level
  /// subscription is released only when the last stream disconnects.
  final Map<String, int> _pubsubSubRefs = {};

  /// Topics already subscribed when the first `pubsub/sub` stream
  /// arrived — teardown must not unsubscribe what it did not create.
  final Set<String> _pubsubExternalTopics = {};

  /// Traversal bounds for DAG export, matching the gateway CAR export
  /// conventions (`_defaultMaxCarDepth`/`_defaultMaxCarBlocks` in
  /// `gateway_handler.dart`).
  static const int _maxExportDepth = 32;
  static const int _maxExportBlocks = 10000;

  /// Maximum total file payload bytes a `get` TAR export may buffer (1 GiB).
  /// The archive is assembled in memory, so payload bytes must be bounded
  /// globally across the whole traversal.
  static const int _maxExportBytes = 1024 * 1024 * 1024;

  /// Reads the request body into memory, rejecting bodies over [maxBytes].
  static Future<Uint8List> _readBodyBounded(
    Request request,
    int maxBytes,
  ) async {
    final builder = BytesBuilder();
    await for (final chunk in request.read()) {
      if (builder.length + chunk.length > maxBytes) {
        throw ArgumentError('Request body exceeds limit of $maxBytes bytes');
      }
      builder.add(chunk);
    }
    return builder.toBytes();
  }

  /// GET /api/v0/version - Get IPFS version
  Future<Response> handleVersion(Request request) async {
    final response = {
      'Version': agentVersion,
      'Commit': 'phase3-gateway-rpc',
      'Repo': repoVersion,
      'System': getPlatform().operatingSystem,
      'Golang': 'Dart ${getPlatform().version}',
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
        'PublicKey': await node.publicKey,
        'Addresses': addresses,
        'AgentVersion': agentVersion,
        'ProtocolVersion': 'ipfs/0.1.0',
        'Protocols': [
          '/ipfs/kad/1.0.0',
          '/ipfs/lan/kad/1.0.0',
          '/ipfs/bitswap/1.2.0',
        ],
      };

      return _jsonResponse(response);
    } catch (e, st) {
      _logger.error('Failed to get node ID', e, st);
      return _errorResponse('Failed to get node ID');
    }
  }

  /// POST /api/v0/add - Add file(s)
  Future<Response> handleAdd(Request request) async {
    try {
      if (!request.headers.containsKey('content-type')) {
        return _errorResponse('Missing Content-Type header');
      }

      final contentType = request.headers['content-type']!;
      final boundary = _getBoundary(contentType);

      if (boundary == null) {
        return _errorResponse('Invalid Content-Type: missing boundary');
      }

      // Kubo-compatible add options. `pin` defaults to true like Kubo;
      // `cid-version`/`raw-leaves` control the produced DAG shape;
      // `wrap-with-directory` wraps all added entries in a directory node.
      final params = request.url.queryParameters;
      final pin = _boolParam(params, 'pin', defaultValue: true);
      final rawLeaves = _boolParam(params, 'raw-leaves');
      final wrapWithDirectory = _boolParam(params, 'wrap-with-directory');
      final cidVersion = int.tryParse(params['cid-version'] ?? '') ?? 0;

      // Transform the request stream into multipart parts
      final transformer = MimeMultipartTransformer(boundary);
      final parts = transformer.bind(request.read());

      final results = <Map<String, dynamic>>[];
      final addedEntries = <(String, String)>[]; // (name, cid) for wrapping
      var totalSize = 0;
      const maxRequestSize = 1024 * 1024 * 1024; // 1 GB
      const maxFileSize = 256 * 1024 * 1024; // 256 MB

      await for (final part in parts) {
        // We only care about file content parts
        // Real IPFS add supports ignoring some parts, wrapping directories, etc.
        // For basic functionality, we treat every part as a file to add.

        // Collect bytes in memory with size limits
        final content = await part.fold<BytesBuilder>(BytesBuilder(), (
          builder,
          chunk,
        ) {
          totalSize += chunk.length;
          if (totalSize > maxRequestSize) {
            throw ArgumentError('Total request size exceeded limit');
          }
          if (builder.length + chunk.length > maxFileSize) {
            throw ArgumentError('File size exceeded limit');
          }
          return builder..add(chunk);
        });
        final bytes = content.takeBytes();

        // Add to IPFS node
        final cid = await _addWithOptions(
          bytes,
          cidVersion: cidVersion,
          rawLeaves: rawLeaves,
        );
        if (pin) {
          await _tryPin(cid);
        }

        // Extract filename if available
        final contentDisposition = part.headers['content-disposition'];
        String name = cid; // Fallback name
        if (contentDisposition != null) {
          final nameMatch = RegExp(
            r'filename="([^"]+)"',
          ).firstMatch(contentDisposition);
          if (nameMatch != null) {
            name = nameMatch.group(1)!;
          }
        }

        addedEntries.add((name, cid));
        results.add({
          'Name': name,
          'Hash': cid,
          'Size': bytes.length.toString(),
        });
      }

      if (results.isEmpty) {
        return _errorResponse('No files found in request');
      }

      if (wrapWithDirectory) {
        final wrapped = await _wrapWithDirectory(addedEntries, cidVersion);
        if (pin) {
          await _tryPin(wrapped.$1);
        }
        results.add({
          // Kubo emits the wrapping directory with an empty name.
          'Name': '',
          'Hash': wrapped.$1,
          'Size': wrapped.$2.toString(),
        });
      }

      // IPFS `add` can result in multiple JSON objects (NDJSON) or a single one.
      // Typical HTTP API response is NDJSON.
      // For simplicity/compatibility, we'll join them with newlines.
      final responseBody = results.map((r) => json.encode(r)).join('\n');

      return Response.ok(
        responseBody,
        headers: {
          'Content-Type': 'application/json',
          // 'X-Stream-Output': '1', // Optional
        },
      );
    } catch (e, st) {
      _logger.error('Add failed', e, st);
      return _errorResponse('Add failed');
    }
  }

  String? _getBoundary(String contentType) {
    final parameters = MediaType.parse(contentType).parameters;
    return parameters['boundary'];
  }

  /// Parses a Kubo-style boolean query option. A present-but-empty value
  /// (`?flag=`) counts as `true`, matching Kubo's option parsing.
  static bool _boolParam(
    Map<String, String> params,
    String name, {
    bool defaultValue = false,
  }) {
    final value = params[name];
    if (value == null) return defaultValue;
    if (value.isEmpty) return true;
    return value == 'true' || value == '1';
  }

  /// Adds [data] honoring `cid-version`/`raw-leaves` options.
  ///
  /// For Kubo defaults (CIDv0, non-raw leaves) this delegates to
  /// [IPFSNode.addFile]. For other DAG shapes the blocks are built with
  /// [UnixFSBuilder] and written to the block store directly.
  Future<String> _addWithOptions(
    Uint8List data, {
    required int cidVersion,
    required bool rawLeaves,
  }) async {
    if (cidVersion == 0 && !rawLeaves) {
      return node.addFile(data);
    }

    final builder = UnixFSBuilder(cidVersion: cidVersion, rawLeaves: rawLeaves);
    // UnixFSBuilder.build unconditionally yields a root block, so the loop
    // always assigns rootCid before it completes.
    late String rootCid;
    await for (final block in builder.build(Stream<List<int>>.value(data))) {
      await node.blockStore.putBlock(block);
      rootCid = block.cid.encode();
    }
    return rootCid;
  }

  /// Best-effort recursive pin for `add`/`dag put`. Pin failures are logged
  /// but do not fail the request — a node without a pin-capable block store
  /// can still accept content.
  Future<void> _tryPin(String cid) async {
    try {
      await node.pin(cid);
    } catch (e, stackTrace) {
      _logger.warning('Pin failed for $cid', e, stackTrace);
    }
  }

  /// Builds a UnixFS directory node wrapping [entries] `(name, cid)` pairs,
  /// stores it, and returns `(directoryCid, serializedSize)`.
  Future<(String, int)> _wrapWithDirectory(
    List<(String, String)> entries,
    int cidVersion,
  ) async {
    final sorted = List<(String, String)>.from(entries)
      ..sort((a, b) => compareEntryNamesUtf8(a.$1, b.$1));
    final links = <dag_pb.PBLink>[];
    for (final (name, cid) in sorted) {
      links.add(
        dag_pb.PBLink(
          name: name,
          hash: CID.decode(cid).toBytes(),
          size: Int64(await _cumulativeDagSize(cid)),
        ),
      );
    }

    final dirData = unixfs_pb.Data(
      type: unixfs_pb.Data_DataType.Directory,
    ).writeToBuffer();
    final node_ = dag_pb.PBNode(data: dirData, links: links);
    final serialized = marshalDagPBNode(node_);

    final dirCid = await CID.fromContent(
      serialized,
      codec: 'dag-pb',
      version: cidVersion,
    );
    await node.blockStore.putBlock(
      Block(cid: dirCid, data: serialized, format: 'dag-pb'),
    );
    return (dirCid.encode(), serialized.length);
  }

  /// Computes the cumulative size (PBLink Tsize) of the DAG rooted at [cid]:
  /// the serialized block size plus the declared sizes of its links.
  Future<int> _cumulativeDagSize(String cid) async {
    final response = await node.blockStore.getBlock(cid);
    if (!response.found) return 0;
    final block = response.block.toBlock();
    var total = block.data.length;
    if (block.cid.codec == 'dag-pb') {
      try {
        final pbNode = dag_pb.PBNode.fromBuffer(block.data);
        for (final link in pbNode.links) {
          total += link.size.toInt();
        }
      } catch (_) {
        // Non-parseable DAG-PB: count the block alone.
      }
    }
    return total;
  }

  Response? _checkDenylist(String cidOrPath, {String source = 'rpc'}) {
    final service = node.denylistService;
    if (service == null || !service.configuredEnabled) {
      return null;
    }
    if (!service.isBlockedByCidString(cidOrPath) &&
        !service.isBlockedPath(cidOrPath)) {
      return null;
    }

    final action = service.recordHit(cidOrPath, source: source);
    if (action == 'log') {
      return null;
    }

    return _denylistBlockedResponse();
  }

  /// The 451 "blocked by operator policy" response shared by request-time
  /// denylist checks and traversal-time [_DenylistBlockedException]
  /// rejections.
  static Response _denylistBlockedResponse() {
    return Response(
      451,
      body: json.encode({
        'Message': 'Content blocked by operator policy',
        'Code': 451,
        'Type': 'error',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// POST /api/v0/cat - Get file content
  ///
  /// Kubo accepts a full IPFS path (`<cid>`, `/ipfs/<cid>/sub/path`, or
  /// `<cid>/sub/path`); the segments after the root resolve through named
  /// DAG-PB directory links.
  Future<Response> handleCat(Request request) async {
    var arg = request.url.queryParameters['arg'];
    if (arg == null || arg.isEmpty) {
      return _errorResponse('Missing argument: cid');
    }

    // Normalize /ipfs/<cid>[/sub/path] or bare <cid>[/sub/path].
    if (arg.startsWith('/ipfs/')) {
      arg = arg.substring(6);
    } else if (arg.startsWith('ipfs/')) {
      arg = arg.substring(5);
    } else if (arg.startsWith('/')) {
      arg = arg.substring(1);
    }
    final segments = arg.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) {
      return _errorResponse('Missing argument: cid');
    }
    final cid = segments.first;
    final subPath = segments.sublist(1).join('/');

    // Check the full /ipfs/<cid>/<sub/path> so path-scoped denylist rules
    // (e.g. `/ipfs/CID/blocked.txt`) are enforced, not just root CIDs.
    final blocked = _checkDenylist(
      '/ipfs/$cid${subPath.isEmpty ? '' : '/$subPath'}',
    );
    if (blocked != null) {
      return blocked;
    }

    try {
      final content = await node.get(cid, path: subPath);
      if (content == null) {
        return _errorResponse('Path not found: $arg', code: 404);
      }
      return Response.ok(content);
    } catch (e, st) {
      _logger.error('Cat failed for cid: $arg', e, st);
      return _errorResponse('Cat failed');
    }
  }

  /// POST /api/v0/get - Download file/directory as a TAR archive.
  ///
  /// Kubo streams a POSIX TAR whose entries are named after the requested
  /// path's last segment: a file root produces a single file entry, a
  /// directory root produces the directory tree recursively.
  Future<Response> handleGet(Request request) async {
    final arg = request.url.queryParameters['arg'];
    if (arg == null || arg.isEmpty) {
      return _errorResponse('Missing argument: path');
    }

    try {
      // Normalize /ipfs/<cid>[/sub/path] or bare <cid>[/sub/path] arguments.
      var path = arg;
      if (path.startsWith('/ipfs/')) {
        path = path.substring(6);
      } else if (path.startsWith('ipfs/')) {
        path = path.substring(5);
      } else if (path.startsWith('/')) {
        path = path.substring(1);
      }
      final segments = path.split('/').where((s) => s.isNotEmpty).toList();
      if (segments.isEmpty) {
        return _errorResponse('Missing argument: path');
      }

      // Check the full /ipfs/<cid>/<sub/path> so path-scoped denylist rules
      // are enforced, not just the root CID.
      final blocked = _checkDenylist('/ipfs/${segments.join('/')}');
      if (blocked != null) {
        return blocked;
      }

      var block = await _rpcGetBlock(segments[0]);
      if (block == null) {
        return _errorResponse('Block not found: ${segments[0]}', code: 404);
      }

      // Resolve any sub-path through named DAG-PB directory links.
      for (final segment in segments.sublist(1)) {
        final childCid = _findNamedLink(block!, segment);
        if (childCid == null) {
          return _errorResponse('Path not found: $arg', code: 404);
        }
        block = await _rpcGetBlock(childCid.encode());
        if (block == null) {
          return _errorResponse('Block not found: $arg', code: 404);
        }
      }

      final tar = _TarWriter();
      await _tarAddNode(
        tar,
        segments.last,
        block!,
        depth: 0,
        budget: _TarTraversalBudget(),
      );

      final tarBytes = tar.close();
      return Response.ok(
        tarBytes,
        headers: {
          'Content-Type': 'application/x-tar',
          'Content-Length': tarBytes.length.toString(),
          'X-Stream-Output': '1',
        },
      );
    } on _DenylistBlockedException {
      // A block fetched mid-traversal matched the denylist.
      return _denylistBlockedResponse();
    } catch (e, st) {
      _logger.error('Get failed for path: $arg', e, st);
      return _errorResponse('Get failed');
    }
  }

  /// Fetches a block from the local block store, falling back to Bitswap.
  ///
  /// Every fetched CID is gated through the denylist so path-scoped and
  /// child-CID rules cannot be bypassed mid-traversal/export; a blocked
  /// fetch throws [_DenylistBlockedException], which the calling handler
  /// translates into the 451 response.
  Future<Block?> _rpcGetBlock(String cid) async {
    if (_checkDenylist(cid) != null) {
      throw const _DenylistBlockedException();
    }
    final response = await node.blockStore.getBlock(cid);
    if (response.found) {
      return response.block.toBlock();
    }
    final bitswap = node.bitswap;
    if (bitswap != null) {
      final networkBlock = await bitswap.wantBlock(cid);
      if (networkBlock != null) {
        await node.blockStore.putBlock(networkBlock);
        return networkBlock;
      }
    }
    return null;
  }

  /// Returns the CID of the link named [name] in a DAG-PB [block], or null.
  CID? _findNamedLink(Block block, String name) {
    if (block.cid.codec != 'dag-pb') return null;
    try {
      final pbNode = dag_pb.PBNode.fromBuffer(block.data);
      for (final link in pbNode.links) {
        if (link.name == name) {
          return CID.fromBytes(Uint8List.fromList(link.hash));
        }
      }
    } catch (_) {
      // Not parseable as DAG-PB.
    }
    return null;
  }

  /// Appends the node addressed by [block] to [tar] under [name].
  ///
  /// UnixFS directories emit a directory entry and recurse into named links;
  /// everything else (files, raw blocks, non-UnixFS nodes) emits a file entry
  /// with the reassembled or raw payload.
  ///
  /// [budget] is shared across the entire traversal: every visited node and
  /// every buffered payload byte counts against the export-wide limits, so a
  /// wide or deep DAG cannot exceed them through per-frame counters.
  Future<void> _tarAddNode(
    _TarWriter tar,
    String name,
    Block block, {
    required int depth,
    required _TarTraversalBudget budget,
  }) async {
    if (depth > _maxExportDepth) {
      throw StateError('TAR export exceeded maximum depth $_maxExportDepth');
    }
    budget.addNode();

    if (block.cid.codec == 'dag-pb') {
      try {
        final pbNode = dag_pb.PBNode.fromBuffer(block.data);
        if (pbNode.hasData()) {
          final unixfsData = unixfs_pb.Data.fromBuffer(pbNode.data);
          if (unixfsData.type == unixfs_pb.Data_DataType.Directory) {
            tar.addDirectory(name);
            for (final link in pbNode.links) {
              final childCid = CID.fromBytes(Uint8List.fromList(link.hash));
              final child = await _rpcGetBlock(childCid.encode());
              if (child == null) {
                throw StateError(
                  'Missing linked block ${childCid.encode()} during TAR export',
                );
              }
              await _tarAddNode(
                tar,
                link.name,
                child,
                depth: depth + 1,
                budget: budget,
              );
            }
            return;
          }
        }
      } catch (e) {
        if (e is StateError || e is _DenylistBlockedException) rethrow;
        // Not a UnixFS directory: fall through and serve as a file entry.
      }
    }

    final data = await unixfsReadFile(
      block,
      (cid) => _rpcGetBlock(cid.encode()),
    );
    budget.addBytes(data.length);
    tar.addFile(name, data);
  }

  /// POST /api/v0/ls - List directory
  Future<Response> handleLs(Request request) async {
    final path = request.url.queryParameters['arg'];
    if (path == null || path.isEmpty) {
      return _errorResponse('Missing argument: path');
    }

    // Normalize /ipfs/<cid>[/sub/path] or bare <cid>[/sub/path] the same way
    // as cat/get so path-scoped denylist rules are enforced here too.
    var normalized = path;
    if (normalized.startsWith('/ipfs/')) {
      normalized = normalized.substring(6);
    } else if (normalized.startsWith('ipfs/')) {
      normalized = normalized.substring(5);
    } else if (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }

    final blocked = _checkDenylist('/ipfs/$normalized');
    if (blocked != null) {
      return blocked;
    }

    // Kubo `resolve-type` defaults to true; Type is the UnixFS DataType enum
    // (0=Raw, 1=Directory, 2=File, 3=Metadata, 4=Symlink, 5=HAMTShard).
    final resolveType = _boolParam(
      request.url.queryParameters,
      'resolve-type',
      defaultValue: true,
    );

    try {
      final entries = await node.ls(normalized);
      final objects = <Map<String, dynamic>>[];
      for (final e in entries) {
        objects.add({
          'Name': e.name,
          'Hash': e.cid.encode(),
          'Size': e.size.toInt(),
          'Type': resolveType ? await _unixfsLinkType(e.cid) : 0,
        });
      }

      final response = {
        'Objects': [
          {'Hash': path, 'Links': objects},
        ],
      };

      return _jsonResponse(response);
    } catch (e, st) {
      _logger.error('Ls failed for path: $path', e, st);
      return _errorResponse('Ls failed');
    }
  }

  /// Resolves the UnixFS [DataType] of the node addressed by [cid].
  ///
  /// Returns the enum integer value, or 0 (Raw/unknown) when the target
  /// cannot be resolved to a typed UnixFS node — matching Kubo, which
  /// reports the protobuf zero value for untyped nodes.
  Future<int> _unixfsLinkType(CID cid) async {
    try {
      if (cid.codec != 'dag-pb') {
        return 0;
      }
      final response = await node.blockStore.getBlock(cid.encode());
      if (!response.found) {
        return 0;
      }
      final pbNode = dag_pb.PBNode.fromBuffer(
        Uint8List.fromList(response.block.data),
      );
      if (pbNode.data.isEmpty) {
        return 0;
      }
      return unixfs_pb.Data.fromBuffer(pbNode.data).type.value;
    } catch (_) {
      return 0;
    }
  }

  /// POST /api/v0/dag/get - Get DAG node
  Future<Response> handleDagGet(Request request) async {
    final cid = request.url.queryParameters['arg'];
    if (cid == null) {
      return _errorResponse('Missing argument: cid');
    }

    final blocked = _checkDenylist(cid);
    if (blocked != null) {
      return blocked;
    }

    try {
      // Get block and return as DAG-JSON like Kubo's dag/get.
      final response = await node.blockStore.getBlock(cid);
      if (!response.found) {
        return _errorResponse('Block not found: $cid', code: 404);
      }

      final block = response.block.toBlock();
      final ipldNode = await _decodeBlockAsIpld(block);
      final dagJson = await DagJsonCodec().encode(ipldNode);
      return Response.ok(
        dagJson,
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, st) {
      _logger.error('DAG get failed for cid: $cid', e, st);
      return _errorResponse('DAG get failed');
    }
  }

  /// Decodes a block into the canonical IPLD node representation for the
  /// codec named by its CID.
  Future<IPLDNode> _decodeBlockAsIpld(Block block) {
    switch (block.cid.codec) {
      case 'dag-pb':
        return DagPbCodec().decode(block.data);
      case 'dag-cbor':
        return DagCborCodec().decode(block.data);
      case 'dag-json':
        return DagJsonCodec().decode(block.data);
      case 'raw':
      default:
        // Unknown codecs are treated as raw byte payloads.
        return RawCodec().decode(block.data);
    }
  }

  /// POST /api/v0/dag/put - Add DAG node.
  ///
  /// Accepts `input-codec` (default `dag-json`), `store-codec` (default
  /// `dag-cbor`), and `pin` (default `true`) query options, matching Kubo.
  /// The body may be a multipart file upload or the raw encoded object.
  Future<Response> handleDagPut(Request request) async {
    try {
      final params = request.url.queryParameters;
      final inputCodec = params['input-codec'] ?? 'dag-json';
      final storeCodec = params['store-codec'] ?? 'dag-cbor';
      final pin = _boolParam(params, 'pin', defaultValue: true);

      final input = await _readDagPutBody(request);

      final ipldNode = await _decodeIpldInput(inputCodec, input);
      final encoded = await _encodeIpldOutput(storeCodec, ipldNode);

      final cid = await CID.fromContent(encoded, codec: storeCodec);
      await node.blockStore.putBlock(
        Block(cid: cid, data: encoded, format: storeCodec),
      );
      if (pin) {
        await _tryPin(cid.encode());
      }

      return _jsonResponse({
        'Cid': {'/': cid.encode()},
      });
    } catch (e, st) {
      _logger.error('DAG put failed', e, st);
      return _errorResponse('DAG put failed: $e');
    }
  }

  /// Reads the dag/put request body: the first multipart part when the
  /// request is a form upload, else the bounded raw body.
  Future<Uint8List> _readDagPutBody(Request request) async {
    final contentType = request.headers['content-type'];
    if (contentType != null && contentType.contains('multipart/')) {
      final boundary = _getBoundary(contentType);
      if (boundary == null) {
        throw ArgumentError('Invalid Content-Type: missing boundary');
      }
      final parts = MimeMultipartTransformer(boundary).bind(request.read());
      await for (final part in parts) {
        final builder = BytesBuilder();
        await for (final chunk in part) {
          if (builder.length + chunk.length > _maxDagPutBytes) {
            throw ArgumentError('Request body exceeds limit');
          }
          builder.add(chunk);
        }
        return builder.toBytes();
      }
      throw ArgumentError('No file part found in multipart request');
    }
    return _readBodyBounded(request, _maxDagPutBytes);
  }

  /// Decodes [input] bytes into an IPLD node per [inputCodec].
  Future<IPLDNode> _decodeIpldInput(String inputCodec, Uint8List input) {
    switch (inputCodec) {
      case 'dag-json':
      case 'json':
        return DagJsonCodec().decode(input);
      case 'dag-cbor':
      case 'cbor':
        return DagCborCodec().decode(input);
      case 'dag-pb':
      case 'protobuf':
        return DagPbCodec().decode(input);
      case 'raw':
        return RawCodec().decode(input);
      default:
        throw ArgumentError('Unsupported input-codec: $inputCodec');
    }
  }

  /// Encodes an IPLD node per [storeCodec].
  Future<Uint8List> _encodeIpldOutput(String storeCodec, IPLDNode node) {
    switch (storeCodec) {
      case 'dag-json':
      case 'json':
        return DagJsonCodec().encode(node);
      case 'dag-cbor':
      case 'cbor':
        return DagCborCodec().encode(node);
      case 'dag-pb':
      case 'protobuf':
        return DagPbCodec().encode(node);
      case 'raw':
        return RawCodec().encode(node);
      default:
        throw ArgumentError('Unsupported store-codec: $storeCodec');
    }
  }

  /// POST /api/v0/dag/export - Export the reachable DAG of [cid] as a CAR v1.
  Future<Response> handleDagExport(Request request) async {
    final cid = request.url.queryParameters['arg'];
    if (cid == null) {
      return _errorResponse('Missing argument: cid');
    }

    final blocked = _checkDenylist(cid);
    if (blocked != null) {
      return blocked;
    }

    try {
      final carData = await _exportCar(cid);
      return Response.ok(
        carData,
        headers: {
          'Content-Type': 'application/vnd.ipld.car',
          'Content-Length': carData.length.toString(),
        },
      );
    } on _DenylistBlockedException {
      return _denylistBlockedResponse();
    } catch (e, st) {
      _logger.error('DAG export failed for cid: $cid', e, st);
      return _errorResponse('DAG export failed: $e');
    }
  }

  /// POST /api/v0/dag/import - Import a CAR v1/v2 archive into the blockstore.
  Future<Response> handleDagImport(Request request) async {
    try {
      final body = await _readBodyBounded(request, _maxImportBodyBytes);
      final reader = CarReader.fromBytes(body);
      final roots = (await reader.header).roots;
      var count = 0;
      var byteCount = 0;
      await for (final section in reader.sections()) {
        final block = Block(
          cid: section.cid,
          data: section.bytes,
          format: _codecToFormat(section.cid.codec ?? 'raw'),
        );
        // CAR bytes are untrusted: hash-verify every section before
        // storing so a crafted archive cannot poison the blockstore.
        if (!await block.validate()) {
          return _errorResponse(
            'DAG import rejected: block data does not match CID ${section.cid}',
          );
        }
        await node.blockStore.putBlock(block);
        count++;
        byteCount += section.bytes.length;
      }

      // Kubo emits one `{"Root":{"Cid":{"/":...},"PinErrorMsg":""}}` line per
      // CAR root (NDJSON), plus a `{"Stats":{...}}` line when ?stats=true.
      final lines = <String>[
        for (final root in roots)
          json.encode({
            'Root': {
              'Cid': {'/': root.toString()},
              'PinErrorMsg': '',
            },
          }),
      ];
      if (_boolParam(request.url.queryParameters, 'stats')) {
        lines.add(
          json.encode({
            'Stats': {'BlockCount': count, 'BlockBytesCount': byteCount},
          }),
        );
      }

      return Response.ok(
        lines.join('\n'),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, st) {
      _logger.error('DAG import failed', e, st);
      return _errorResponse('DAG import failed: $e');
    }
  }

  String _codecToFormat(String codec) {
    switch (codec) {
      case 'dag-pb':
        return 'dag-pb';
      case 'raw':
        return 'raw';
      case 'dag-cbor':
        return 'dag-cbor';
      case 'dag-json':
        return 'dag-json';
      default:
        return 'raw';
    }
  }

  Future<Uint8List> _exportCar(String rootCidStr) async {
    final root = CID.decode(rootCidStr);
    final writer = CarWriter(roots: [root]);
    final visited = <String>{};
    await _exportBlock(root, writer, visited);
    return writer.close();
  }

  Future<void> _exportBlock(
    CID cid,
    CarWriter writer,
    Set<String> visited, {
    int depth = 0,
  }) async {
    if (depth > _maxExportDepth) {
      throw StateError('DAG export exceeded maximum depth $_maxExportDepth');
    }
    if (visited.length >= _maxExportBlocks) {
      throw StateError(
        'DAG export exceeded maximum block count $_maxExportBlocks',
      );
    }

    final key = cid.toString();
    if (visited.contains(key)) return;
    visited.add(key);

    // Mid-traversal denylist gate — a blocked child CID must not leak into
    // the exported archive.
    if (_checkDenylist(key) != null) {
      throw const _DenylistBlockedException();
    }

    final response = await node.blockStore.getBlock(key);
    if (!response.found) {
      throw StateError('Block not found: $key');
    }
    final block = response.block.toBlock();
    await writer.write(cid, block.data);

    // The CID codec is authoritative; the stored format hint is a fallback
    // for blocks whose CID predates codec-aware storage.
    if (block.cid.codec == 'dag-pb' || block.format == 'dag-pb') {
      final pbNode = dag_pb.PBNode.fromBuffer(block.data);
      for (final link in pbNode.links) {
        final linkCid = CID.fromBytes(Uint8List.fromList(link.hash));
        await _exportBlock(linkCid, writer, visited, depth: depth + 1);
      }
    }
  }

  /// POST /api/v0/dht/findprovs - Find providers for CID
  Future<Response> handleDhtFindProviders(Request request) async {
    final cid = request.url.queryParameters['arg'];
    if (cid == null) {
      return _errorResponse('Missing argument: cid');
    }

    _logger.debug('handleDhtFindProviders called for cid=$cid');
    try {
      final providers = await node.dhtClient.findProviders(cid);
      _logger.debug(
        'handleDhtFindProviders: ${providers.length} providers for $cid',
      );

      // Stream response (ndjson format)
      final responses = providers
          .map(
            (p) => json.encode({
              'Type': 4, // Provider type
              'Responses': [
                {'ID': p.toString(), 'Addrs': node.resolvePeerId(p.toString())},
              ],
            }),
          )
          .join('\n');

      return Response.ok(
        responses,
        headers: {'Content-Type': 'application/json', 'X-Stream-Output': '1'},
      );
    } catch (e, st) {
      _logger.error('DHT findprovs failed for cid: $cid', e, st);
      return _errorResponse('DHT findprovs failed');
    }
  }

  /// POST /api/v0/dht/findpeer - Find peer by ID
  Future<Response> handleDhtFindPeer(Request request) async {
    final peerId = request.url.queryParameters['arg'];
    if (peerId == null) {
      return _errorResponse('Missing argument: peerID');
    }

    try {
      final found = await node.dhtClient.findPeer(
        PeerId(value: Base58().base58Decode(peerId)),
      );
      if (found != null) {
        return _jsonResponse({
          'Type': 2,
          'Responses': [
            {
              'ID': found.toString(),
              'Addrs': node.resolvePeerId(found.toString()),
            },
          ],
        });
      } else {
        return _errorResponse('Peer not found');
      }
    } catch (e, st) {
      _logger.error('DHT findpeer failed for peer: $peerId', e, st);
      return _errorResponse('DHT findpeer failed');
    }
  }

  /// POST /api/v0/dht/provide - Announce provider
  ///
  /// On-demand provide with explicit once/queued semantics and detailed
  /// success/failure feedback (see `REPROVIDE_SPEC.md` §4.6).
  ///
  /// Query parameters:
  /// - `arg` (required): CID to announce.
  /// - `recursive` (bool, default false): also announce every block of the
  ///   DAG reachable from `arg` in the local blockstore.
  /// - `queue` (bool, default false): enqueue the provide job instead of
  ///   running it inline; returns `202 Accepted` with a queue position.
  /// - `once` (bool, default true): perform a single-shot announcement and
  ///   wait for the result. `once=false` is equivalent to `queue=true`.
  /// - `timeout` (duration string, e.g. `30s`, `500ms`; default `30s`):
  ///   aborts remaining peer attempts and returns partial results.
  /// - `record` (bool, default true): record metrics for the operation.
  Future<Response> handleDhtProvide(Request request) async {
    final params = request.url.queryParameters;
    final cid = params['arg'];
    if (cid == null) {
      return _errorResponse('Missing argument: cid');
    }

    final blocked = _checkDenylist(cid, source: 'rpc');
    if (blocked != null) {
      return blocked;
    }

    final recursive = _boolParam(params, 'recursive');
    final once = _boolParam(params, 'once', defaultValue: true);
    final queued = _boolParam(params, 'queue') || !once;
    final recordMetrics = _boolParam(params, 'record', defaultValue: true);
    final timeout =
        _parseDurationParam(params['timeout']) ?? const Duration(seconds: 30);

    CID cidObj;
    try {
      cidObj = CID.decode(cid);
    } catch (_) {
      return _errorResponse('Invalid CID: $cid', code: 400);
    }

    final dhtHandler = node.dhtHandler;
    if (dhtHandler != null) {
      if (queued) {
        final position = dhtHandler.enqueueProvide(
          cidObj,
          recursive: recursive,
          timeout: timeout,
          blockStore: node.blockStore,
          recordMetrics: recordMetrics,
        );
        if (position == null) {
          return Response(503, body: 'Provide queue full');
        }
        return Response(
          202,
          body: json.encode({
            'CID': cid,
            'Queued': true,
            'QueuePosition': position,
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      try {
        final result = await dhtHandler.provideDetailed(
          cidObj,
          recursive: recursive,
          timeout: timeout,
          blockStore: node.blockStore,
          recordMetrics: recordMetrics,
        );
        return _jsonResponse({
          'ID': node.peerId,
          'CID': cid,
          'Success': result.success,
          'Attempts': result.attempts,
          'Successes': result.successes,
          'Failures': result.failures,
          'Errors': result.errors,
          'Queued': false,
        });
      } catch (e, st) {
        _logger.error('DHT provide failed for cid: $cid', e, st);
        return _errorResponse('DHT provide failed');
      }
    }

    // Fallback when no concrete DHT handler is exposed (e.g. delegate or
    // client-only surfaces): single-shot announce through the DHT client.
    try {
      await node.dhtClient.addProvider(cid, node.peerId);
      return _jsonResponse({
        'ID': node.peerId,
        'CID': cid,
        'Success': true,
        'Attempts': 1,
        'Successes': 1,
        'Failures': 0,
        'Errors': const <String>[],
        'Queued': false,
      });
    } catch (e, st) {
      _logger.error('DHT provide failed for cid: $cid', e, st);
      return _errorResponse('DHT provide failed');
    }
  }

  /// Parses a Kubo-style duration string (`30s`, `500ms`, `5m`, `1h`) or a
  /// bare integer (seconds). Returns `null` when unparseable.
  static Duration? _parseDurationParam(String? value) {
    if (value == null || value.isEmpty) return null;
    final bare = int.tryParse(value);
    if (bare != null) return Duration(seconds: bare);
    final match = RegExp(r'^(\d+)(ms|s|m|h)$').firstMatch(value);
    if (match == null) return null;
    final amount = int.parse(match.group(1)!);
    switch (match.group(2)) {
      case 'ms':
        return Duration(milliseconds: amount);
      case 's':
        return Duration(seconds: amount);
      case 'm':
        return Duration(minutes: amount);
      case 'h':
        return Duration(hours: amount);
    }
    return null;
  }

  /// POST /api/v0/name/publish - Publish IPNS record
  Future<Response> handleNamePublish(Request request) async {
    final path = request.url.queryParameters['arg'];
    if (path == null) {
      return _errorResponse('Missing argument: path');
    }

    try {
      // name/publish accepts an IPFS path; extract the CID if needed.
      var cid = path;
      if (path.startsWith('/ipfs/')) {
        cid = path.substring(6);
      }
      final name = await node.publishIPNS(cid, keyName: 'self');
      return _jsonResponse({'Name': name, 'Value': path});
    } catch (e, st) {
      _logger.error('Name publish failed for path: $path', e, st);
      return _errorResponse('Name publish failed');
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
      return _jsonResponse({'Path': path});
    } catch (e, st) {
      _logger.error('Name resolve failed for name: $name', e, st);
      return _errorResponse('Name resolve failed');
    }
  }

  /// POST /api/v0/swarm/peers - List connected peers
  Future<Response> handleSwarmPeers(Request request) async {
    try {
      final peers = await node.connectedPeers;
      final peerList = peers.map((p) => {'Peer': p, 'Addr': ''}).toList();

      return _jsonResponse({'Peers': peerList});
    } catch (e, st) {
      _logger.error('Swarm peers failed', e, st);
      return _errorResponse('Swarm peers failed');
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
        'Strings': ['connect $addr success'],
      });
    } catch (e, st) {
      _logger.error('Swarm connect failed for addr: $addr', e, st);
      return _errorResponse('Swarm connect failed');
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
        'Strings': ['disconnect $addr success'],
      });
    } catch (e, st) {
      _logger.error('Swarm disconnect failed for addr: $addr', e, st);
      return _errorResponse('Swarm disconnect failed');
    }
  }

  /// POST /api/v0/block/get - Get raw block
  Future<Response> handleBlockGet(Request request) async {
    final cid = request.url.queryParameters['arg'];
    if (cid == null) {
      return _errorResponse('Missing argument: cid');
    }

    final blocked = _checkDenylist(cid);
    if (blocked != null) {
      return blocked;
    }

    try {
      var block = await node.blockStore.getBlock(cid);

      if (!block.found) {
        // Try fetching the block via Bitswap from connected peers.
        final bitswap = node.bitswap;
        if (bitswap != null) {
          _logger.debug('Block $cid not found locally, trying Bitswap');
          final networkBlock = await bitswap.wantBlock(cid);
          if (networkBlock != null) {
            await node.blockStore.putBlock(networkBlock);
            return Response.ok(networkBlock.data);
          }
        }
        return _errorResponse('Block not found', code: 404);
      }

      return Response.ok(block.block.data);
    } catch (e, st) {
      _logger.error('Block get failed for cid: $cid', e, st);
      return _errorResponse('Block get failed');
    }
  }

  /// POST /api/v0/block/put - Add raw block
  Future<Response> handleBlockPut(Request request) async {
    try {
      final uint8Bytes = await _readBodyBounded(request, _maxBlockPutBytes);

      final cid = await CID.fromContent(uint8Bytes);

      // Create and store the block
      final block = Block(cid: cid, data: uint8Bytes);
      await node.blockStore.putBlock(block);

      return _jsonResponse({'Key': cid.encode(), 'Size': uint8Bytes.length});
    } catch (e, st) {
      _logger.error('Block put failed', e, st);
      return _errorResponse('Block put failed');
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

      return _jsonResponse({'Key': cid, 'Size': block.block.data.length});
    } catch (e, st) {
      _logger.error('Block stat failed for cid: $cid', e, st);
      return _errorResponse('Block stat failed');
    }
  }

  // Helper methods

  Response _jsonResponse(Map<String, dynamic> data) {
    return Response.ok(
      json.encode(data),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// POST /api/v0/pubsub/pub - Publish a message to a pubsub topic.
  ///
  /// Kubo-compatible: the topic is the `arg` query parameter and the request
  /// body is the raw message payload. Returns an empty JSON object on
  /// success.
  Future<Response> handlePubsubPublish(Request request) async {
    final arg = request.url.queryParameters['arg'];
    if (arg == null || arg.isEmpty) {
      return _errorResponse('Missing or empty arg (topic)', code: 400);
    }
    final topic = _decodeTopicArg(arg);

    try {
      final body = await _readBodyBounded(request, _maxPubsubPubBytes);
      // The payload is opaque bytes — decoding as UTF-8 here would corrupt
      // non-text payloads on the wire.
      await node.publishData(topic, body);
      return _jsonResponse(const <String, dynamic>{});
    } on ArgumentError catch (e) {
      return _errorResponse(e.message.toString(), code: 400);
    } catch (e, st) {
      _logger.error('pubsub/pub failed for topic $topic', e, st);
      return _errorResponse('Failed to publish: $e');
    }
  }

  /// POST /api/v0/pubsub/sub - Subscribe to a topic and stream messages.
  ///
  /// Kubo-compatible: subscribes the node to the `arg` topic, then holds the
  /// response open and emits one NDJSON object per received message with
  /// `from`, `data`, `seqno`, and `topicIDs` fields — binary fields are
  /// multibase base64url encoded (`u`-prefixed). The stream ends when the
  /// client disconnects.
  Future<Response> handlePubsubSubscribe(Request request) async {
    final arg = request.url.queryParameters['arg'];
    if (arg == null || arg.isEmpty) {
      return _errorResponse('Missing or empty arg (topic)', code: 400);
    }
    final topic = _decodeTopicArg(arg);

    final refs = _pubsubSubRefs[topic] ?? 0;
    if (refs == 0 && node.pubsubLs().contains(topic)) {
      _pubsubExternalTopics.add(topic);
    }
    _pubsubSubRefs[topic] = refs + 1;

    try {
      await node.subscribe(topic);
    } catch (e, st) {
      await _releasePubsubSubRef(topic);
      _logger.error('pubsub/sub failed for topic $topic', e, st);
      return _errorResponse('Failed to subscribe: $e');
    }

    final controller = StreamController<List<int>>();
    final subscription = node.pubsubMessages
        .where((message) => message.topic == topic)
        .listen((message) {
          // Drop while the client is backpressured: pubsub is real-time
          // and lossy by design — buffering messages for a stalled reader
          // would grow memory without bound.
          if (controller.isClosed || controller.isPaused) return;
          controller.add(
            utf8.encode('${jsonEncode(_encodePubsubMessage(message))}\n'),
          );
        }, onError: controller.addError);
    controller.onCancel = () async {
      await subscription.cancel();
      await _releasePubsubSubRef(topic);
    };

    return Response.ok(
      controller.stream,
      // Disable dart:io response buffering — otherwise each NDJSON line
      // sits in the HttpResponse buffer until it fills (~8KB) or the
      // stream closes, and a long-lived subscription never delivers a
      // single message to the client.
      context: {'shelf.io.buffer_output': false},
      headers: {
        'Content-Type': 'application/json',
        'X-Chunked-Output': '1',
        'Trailer': 'X-Stream-Error',
      },
    );
  }

  /// POST /api/v0/pubsub/ls - List subscribed topics.
  Future<Response> handlePubsubLs(Request request) async {
    try {
      return _jsonResponse({'Strings': node.pubsubLs()});
    } catch (e, st) {
      _logger.error('pubsub/ls failed', e, st);
      return _errorResponse('Failed to list subscriptions');
    }
  }

  /// POST /api/v0/pubsub/peers - List peers subscribed to a topic.
  Future<Response> handlePubsubPeers(Request request) async {
    final arg = request.url.queryParameters['arg'];
    try {
      final peers = arg == null || arg.isEmpty
          ? <String>[]
          : await node.pubsubPeers(_decodeTopicArg(arg));
      return _jsonResponse({'Strings': peers});
    } catch (e, st) {
      _logger.error('pubsub/peers failed', e, st);
      return _errorResponse('Failed to list pubsub peers');
    }
  }

  /// Releases one `pubsub/sub` reference on [topic]. Kubo cancels the
  /// subscription when the stream closes — mirrored here by unsubscribing
  /// once the last RPC subscriber leaves, unless the topic was subscribed
  /// outside this RPC surface.
  Future<void> _releasePubsubSubRef(String topic) async {
    final remaining = (_pubsubSubRefs[topic] ?? 1) - 1;
    if (remaining > 0) {
      _pubsubSubRefs[topic] = remaining;
      return;
    }
    _pubsubSubRefs.remove(topic);
    if (_pubsubExternalTopics.remove(topic)) return;
    try {
      await node.unsubscribe(topic);
    } catch (e) {
      _logger.debug('pubsub/sub cleanup: unsubscribe $topic failed: $e');
    }
  }

  /// Decodes a pubsub `arg` topic. Kubo-style clients send topics as
  /// multibase base64url (`u`-prefixed, unpadded); a `u` value that decodes
  /// cleanly is treated as multibase, anything else is used literally.
  static String _decodeTopicArg(String arg) {
    if (arg.length > 1 && arg.startsWith('u')) {
      try {
        return utf8.decode(
          base64Url.decode(base64Url.normalize(arg.substring(1))),
        );
      } catch (_) {
        // Not a valid multibase value; treat as a literal topic name.
      }
    }
    return arg;
  }

  /// Encodes a [PubSubMessage] in the Kubo `pubsub/sub` wire shape:
  /// binary fields are multibase base64url (`u`-prefixed), `from` is the
  /// sender's string peer ID, and `seqno` is empty (not tracked locally).
  Map<String, dynamic> _encodePubsubMessage(PubSubMessage message) {
    return {
      'from': message.sender,
      // Kubo-compatible: `data` is the raw payload bytes multibase-base64url
      // encoded — using `content` (the lossy UTF-8 view) would corrupt
      // binary payloads.
      'data': 'u${base64Url.encode(message.data).replaceAll('=', '')}',
      'seqno': 'u',
      'topicIDs': [
        'u${base64Url.encode(utf8.encode(message.topic)).replaceAll('=', '')}',
      ],
    };
  }

  Response _errorResponse(String message, {int code = 500}) {
    return Response(
      code,
      body: json.encode({'Message': message, 'Code': 0, 'Type': 'error'}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

/// Thrown when a block fetched mid-traversal (sub-path resolution, TAR
/// export, or chunked-file reassembly) matches the denylist. Handlers
/// translate it into the shared 451 response.
class _DenylistBlockedException implements Exception {
  /// Creates a new [_DenylistBlockedException].
  const _DenylistBlockedException();
}

/// Mutable traversal budget shared across an entire TAR export.
///
/// The node and byte limits are global to the traversal: counts accumulate
/// across every recursion branch, so a wide or deep DAG cannot exceed the
/// export bounds through per-frame counters.
class _TarTraversalBudget {
  /// Maximum number of DAG nodes the export may visit.
  int maxNodes = RPCHandlers._maxExportBlocks;

  /// Maximum total file payload bytes the export may buffer.
  int maxBytes = RPCHandlers._maxExportBytes;

  /// Nodes visited so far.
  int nodes = 0;

  /// Payload bytes written so far.
  int bytes = 0;

  /// Counts one visited node, throwing [StateError] once [maxNodes] is
  /// exceeded.
  void addNode() {
    if (++nodes > maxNodes) {
      throw StateError('TAR export exceeded maximum nodes $maxNodes');
    }
  }

  /// Counts [n] payload bytes, throwing [StateError] once [maxBytes] is
  /// exceeded.
  void addBytes(int n) {
    bytes += n;
    if (bytes > maxBytes) {
      throw StateError('TAR export exceeded maximum bytes $maxBytes');
    }
  }
}

/// Minimal POSIX ustar writer for the `get` TAR response.
///
/// Supports regular files and directories — the only entry kinds `ipfs get`
/// emits — with ustar `prefix` splitting for names longer than 100 bytes.
class _TarWriter {
  final BytesBuilder _out = BytesBuilder();

  /// Adds a directory entry named [name] (a trailing slash is appended when
  /// missing).
  void addDirectory(String name) {
    _writeHeader(
      name.endsWith('/') ? name : '$name/',
      typeflag: 0x35, // '5'
      size: 0,
    );
  }

  /// Adds a regular file entry named [name] containing [data].
  void addFile(String name, List<int> data) {
    _writeHeader(name, typeflag: 0x30, size: data.length); // '0'
    _out.add(data);
    final remainder = data.length % 512;
    if (remainder != 0) {
      _out.add(Uint8List(512 - remainder));
    }
  }

  /// Terminates the archive with the required 1024 zero bytes and returns
  /// the complete TAR.
  Uint8List close() {
    _out.add(Uint8List(1024));
    return _out.takeBytes();
  }

  void _writeHeader(String name, {required int typeflag, required int size}) {
    final header = Uint8List(512);
    final nameBytes = utf8.encode(name);

    var nameField = nameBytes;
    var prefixField = Uint8List(0);
    if (nameBytes.length > 100) {
      // ustar prefix split: prefix <= 155 bytes, name <= 100 bytes.
      final splitAt = name.lastIndexOf('/', 100);
      if (splitAt > 0) {
        prefixField = Uint8List.fromList(
          utf8.encode(name.substring(0, splitAt)),
        );
        nameField = Uint8List.fromList(
          utf8.encode(name.substring(splitAt + 1)),
        );
      }
      if (prefixField.length > 155 || nameField.length > 100) {
        // Fall back to truncating the name; better than a malformed header.
        prefixField = Uint8List(0);
        nameField = Uint8List.fromList(
          nameBytes.sublist(nameBytes.length - 100),
        );
      }
    }

    _writeStr(header, 0, nameField);
    _writeOctal(header, 100, 420, 7); // mode 0644
    _writeOctal(header, 108, 0, 7); // uid
    _writeOctal(header, 116, 0, 7); // gid
    _writeOctal(header, 124, size, 11); // size
    _writeOctal(
      header,
      136,
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      11,
    ); // mtime
    header[156] = typeflag;
    _writeStr(header, 257, Uint8List.fromList(utf8.encode('ustar')));
    header[263] = 0x30; // '0'
    header[264] = 0x30; // '0'
    _writeStr(header, 265, Uint8List.fromList(utf8.encode('dart_ipfs')));
    _writeStr(header, 345, prefixField);

    // Checksum: sum all header bytes with the chksum field as spaces.
    for (var i = 148; i < 156; i++) {
      header[i] = 0x20;
    }
    var sum = 0;
    for (final b in header) {
      sum += b;
    }
    _writeOctal(header, 148, sum, 6);
    header[154] = 0;
    header[155] = 0x20;

    _out.add(header);
  }

  static void _writeStr(Uint8List header, int offset, List<int> bytes) {
    header.setRange(offset, offset + bytes.length, bytes);
  }

  /// Writes [value] as a zero-padded octal ASCII string of [width] digits.
  static void _writeOctal(Uint8List header, int offset, int value, int width) {
    final digits = value.toRadixString(8).padLeft(width, '0');
    for (var i = 0; i < width; i++) {
      header[offset + i] = digits.codeUnitAt(i);
    }
  }
}
