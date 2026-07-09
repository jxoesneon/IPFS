// lib/src/services/rpc/mfs_handlers.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:shelf/shelf.dart';

import '../../core/ipfs_node/ipfs_node.dart';
import '../../utils/logger.dart';

/// Maximum allowed multipart body size for `files/write` (100 MiB).
const _maxMultipartSize = 100 * 1024 * 1024;

/// RPC handlers for the `/api/v0/files/*` MFS endpoint surface.
///
/// These handlers mirror Kubo's `ipfs files` command API and delegate to the
/// shared [MFSManager] instance exposed by [IPFSNode.mfs].
class MFSHandlers {
  /// Creates a new [MFSHandlers] for the given [node].
  MFSHandlers(this.node);

  /// The IPFS node whose MFS manager is used for operations.
  final IPFSNode node;

  final _logger = Logger('MFSHandlers');

  Response? _checkDenylistForPath(String path) {
    final service = node.denylistService;
    if (service == null || !service.configuredEnabled) return null;
    if (!service.isBlockedPath(path)) return null;

    final action = service.recordHit(path, source: 'rpc');
    if (action == 'log') return null;

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

  /// POST /api/v0/files/ls
  ///
  /// Query parameters: `arg` (path), `long`, `U` (unsorted).
  Future<Response> handleFilesLs(Request request) async {
    final path = _singleArg(request) ?? '/';
    final long = _boolParam(request, 'long');
    final u = _boolParam(request, 'U');

    try {
      final entries = await node.mfs.ls(path, long: long, u: u);
      final stat = await node.mfs.stat(path);
      return _jsonResponse({
        'Entries': entries.map((e) => e.toJson()).toList(),
        'Hash': stat.hash,
      });
    } catch (e, st) {
      _logger.error('files/ls failed for path: $path', e, st);
      return _errorResponse('files/ls failed: $e');
    }
  }

  /// POST /api/v0/files/stat
  ///
  /// Query parameters: `arg`, `with-local`, `hash`, `size`, `cid-base`.
  Future<Response> handleFilesStat(Request request) async {
    final path = _singleArg(request) ?? '/';
    final withLocal = _boolParam(request, 'with-local');
    final hash = _boolParam(request, 'hash');
    final size = _boolParam(request, 'size');
    final cidBase = request.url.queryParameters['cid-base'];

    try {
      final stat = await node.mfs.stat(
        path,
        withLocal: withLocal,
        hash: hash,
        size: size,
        cidBase: cidBase,
      );
      return _jsonResponse(stat.toJson());
    } catch (e, st) {
      _logger.error('files/stat failed for path: $path', e, st);
      return _errorResponse('files/stat failed: $e');
    }
  }

  /// POST /api/v0/files/read
  ///
  /// Query parameters: `arg`, `offset`, `count`.
  Future<Response> handleFilesRead(Request request) async {
    final path = _singleArg(request);
    if (path == null) {
      return _errorResponse('Missing argument: path');
    }

    final offset = _intParam(request, 'offset');
    final count = _intParam(request, 'count');

    final invalid = _validateOffsetCount(offset, count);
    if (invalid != null) {
      return _errorResponse(invalid, code: 400);
    }

    try {
      final stream = await node.mfs.read(path, offset: offset, count: count);
      return Response.ok(
        stream,
        headers: {'Content-Type': 'application/octet-stream'},
      );
    } catch (e, st) {
      _logger.error('files/read failed for path: $path', e, st);
      return _errorResponse('files/read failed: $e');
    }
  }

  /// POST /api/v0/files/write
  ///
  /// Query parameters: `arg` (path), `create`, `offset`, `truncate`, `count`,
  /// `raw-leaves`, `cid-version`, `hash`.
  /// The request body is multipart/form-data with the file content.
  Future<Response> handleFilesWrite(Request request) async {
    final path = _singleArg(request);
    if (path == null) {
      return _errorResponse('Missing argument: path');
    }

    final create = _boolParam(request, 'create', defaultValue: true);
    final offset = _intParam(request, 'offset');
    final truncate = _boolParam(request, 'truncate', defaultValue: true);
    final count = _intParam(request, 'count');
    final rawLeaves = _boolParam(request, 'raw-leaves');
    final cidVersion = _intParam(request, 'cid-version');
    final hash = request.url.queryParameters['hash'];

    final invalid = _validateOffsetCount(offset, count);
    if (invalid != null) {
      return _errorResponse(invalid, code: 400);
    }
    if (cidVersion != null && (cidVersion < 0 || cidVersion > 1)) {
      return _errorResponse('Invalid cid-version: $cidVersion', code: 400);
    }

    if (!request.headers.containsKey('content-type')) {
      return _errorResponse('Missing Content-Type header');
    }

    final contentType = request.headers['content-type']!;
    final boundary = _getBoundary(contentType);
    if (boundary == null) {
      return _errorResponse('Invalid Content-Type: missing boundary');
    }

    try {
      final transformer = MimeMultipartTransformer(boundary);
      final parts = transformer.bind(request.read());

      final collected = await parts.toList();
      if (collected.isEmpty) {
        return _errorResponse('No file content found in request');
      }

      final contentBuilder = BytesBuilder();
      var totalSize = 0;
      for (final part in collected) {
        await for (final chunk in part) {
          totalSize += chunk.length;
          if (totalSize > _maxMultipartSize) {
            return _errorResponse(
              'Request body exceeds maximum size of $_maxMultipartSize bytes',
              code: 400,
            );
          }
          contentBuilder.add(chunk);
        }
      }

      await node.mfs.write(
        path,
        Stream.fromIterable([contentBuilder.toBytes()]),
        create: create,
        offset: offset,
        truncate: truncate,
        count: count,
        rawLeaves: rawLeaves,
        cidVersion: cidVersion,
        hash: hash,
      );

      return Response.ok('');
    } catch (e, st) {
      _logger.error('files/write failed for path: $path', e, st);
      return _errorResponse('files/write failed: $e');
    }
  }

  /// POST /api/v0/files/mkdir
  ///
  /// Query parameters: `arg`, `parents`, `recursive`, `cid-version`, `hash`.
  Future<Response> handleFilesMkdir(Request request) async {
    final path = _singleArg(request);
    if (path == null) {
      return _errorResponse('Missing argument: path');
    }

    final parents = _boolParam(request, 'parents');
    final recursive = _boolParam(request, 'recursive');
    final cidVersion = _intParam(request, 'cid-version');
    final hash = request.url.queryParameters['hash'];

    if (cidVersion != null && (cidVersion < 0 || cidVersion > 1)) {
      return _errorResponse('Invalid cid-version: $cidVersion', code: 400);
    }

    try {
      await node.mfs.mkdir(
        path,
        recursive: recursive,
        parents: parents,
        cidVersion: cidVersion,
        hash: hash,
      );
      return Response.ok('');
    } catch (e, st) {
      _logger.error('files/mkdir failed for path: $path', e, st);
      return _errorResponse('files/mkdir failed: $e');
    }
  }

  /// POST /api/v0/files/cp
  ///
  /// Query parameters: two `arg` values (source, destination).
  Future<Response> handleFilesCp(Request request) async {
    final args = _allArgs(request);
    if (args.length < 2) {
      return _errorResponse('Missing arguments: source and destination');
    }

    final blocked = _checkDenylistForPath(args[0]);
    if (blocked != null) {
      return blocked;
    }

    try {
      await node.mfs.cp(args[0], args[1]);
      return Response.ok('');
    } catch (e, st) {
      _logger.error('files/cp failed: ${args[0]} -> ${args[1]}', e, st);
      return _errorResponse('files/cp failed: $e');
    }
  }

  /// POST /api/v0/files/mv
  ///
  /// Query parameters: two `arg` values (source, destination).
  Future<Response> handleFilesMv(Request request) async {
    final args = _allArgs(request);
    if (args.length < 2) {
      return _errorResponse('Missing arguments: source and destination');
    }

    final blocked = _checkDenylistForPath(args[0]);
    if (blocked != null) {
      return blocked;
    }

    try {
      await node.mfs.mv(args[0], args[1]);
      return Response.ok('');
    } catch (e, st) {
      _logger.error('files/mv failed: ${args[0]} -> ${args[1]}', e, st);
      return _errorResponse('files/mv failed: $e');
    }
  }

  /// POST /api/v0/files/rm
  ///
  /// Query parameters: `arg`, `recursive`, `force`.
  Future<Response> handleFilesRm(Request request) async {
    final path = _singleArg(request);
    if (path == null) {
      return _errorResponse('Missing argument: path');
    }

    final recursive = _boolParam(request, 'recursive');
    final force = _boolParam(request, 'force');

    try {
      await node.mfs.rm(path, recursive: recursive, force: force);
      return Response.ok('');
    } catch (e, st) {
      _logger.error('files/rm failed for path: $path', e, st);
      return _errorResponse('files/rm failed: $e');
    }
  }

  /// POST /api/v0/files/flush
  ///
  /// Query parameters: `arg` (default `/`).
  Future<Response> handleFilesFlush(Request request) async {
    final path = _singleArg(request) ?? '/';

    try {
      final rootCid = await node.mfs.flush(path: path);
      return _jsonResponse({'Hash': rootCid.encode()});
    } catch (e, st) {
      _logger.error('files/flush failed for path: $path', e, st);
      return _errorResponse('files/flush failed: $e');
    }
  }

  /// POST /api/v0/files/chcid
  ///
  /// Query parameters: `arg`, `cid-version`, `hash`.
  Future<Response> handleFilesChcid(Request request) async {
    final path = _singleArg(request);
    if (path == null) {
      return _errorResponse('Missing argument: path');
    }

    final cidVersion = _intParam(request, 'cid-version');
    final hash = request.url.queryParameters['hash'];

    if (cidVersion != null && (cidVersion < 0 || cidVersion > 1)) {
      return _errorResponse('Invalid cid-version: $cidVersion', code: 400);
    }

    try {
      await node.mfs.chcid(path, cidVersion: cidVersion, hash: hash);
      return Response.ok('');
    } catch (e, st) {
      _logger.error('files/chcid failed for path: $path', e, st);
      return _errorResponse('files/chcid failed: $e');
    }
  }

  // --------------------------------------------------------------------------
  // Helper methods
  // --------------------------------------------------------------------------

  String? _singleArg(Request request) {
    final args = _allArgs(request);
    if (args.isEmpty) return null;
    return args.first;
  }

  List<String> _allArgs(Request request) {
    return request.url.queryParametersAll['arg'] ?? [];
  }

  bool _boolParam(Request request, String name, {bool defaultValue = false}) {
    final value = request.url.queryParameters[name];
    if (value == null) return defaultValue;
    return value == 'true' || value == '1';
  }

  int? _intParam(Request request, String name) {
    final value = request.url.queryParameters[name];
    if (value == null || value.isEmpty) return null;
    return int.tryParse(value);
  }

  String? _getBoundary(String contentType) {
    try {
      final parameters = MediaType.parse(contentType).parameters;
      return parameters['boundary'];
    } catch (e) {
      return null;
    }
  }

  /// Returns an error message if [offset] or [count] are invalid/negative.
  String? _validateOffsetCount(int? offset, int? count) {
    if (offset != null && offset < 0) {
      return 'Invalid offset: $offset';
    }
    if (count != null && count < 0) {
      return 'Invalid count: $count';
    }
    return null;
  }

  Response _jsonResponse(Map<String, dynamic> data) {
    return Response.ok(
      json.encode(data),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Response _errorResponse(String message, {int code = 500}) {
    return Response(
      code,
      body: json.encode({'Message': message, 'Code': 0, 'Type': 'error'}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
