// lib/src/services/rpc/mfs_handlers.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../core/ipfs_node/ipfs_node.dart';
import '../../utils/logger.dart';

/// Maximum allowed multipart body size for `files/write` (100 MiB).
const _maxMultipartSize = 100 * 1024 * 1024;

/// RPC handlers for the `/api/v0/files/*` MFS endpoint surface.
///
/// These handlers mirror Kubo's `ipfs files` command API and delegate to the
/// shared [MFSManager] instance exposed by [IPFSNode.mfs]. The full Kubo verb
/// set is covered: `mkdir`, `write`, `read`, `stat`, `ls`, `cp`, `mv`, `rm`,
/// `flush`, `chcid`, plus the UnixFS 1.5 metadata verbs `touch` (mtime) and
/// `chmod`.
class MFSHandlers {
  /// Creates a new [MFSHandlers] for the given [node].
  MFSHandlers(this.node);

  /// The IPFS node whose MFS manager is used for operations.
  final IPFSNode node;

  final _logger = Logger('MFSHandlers');

  /// Registers every `/api/v0/files/*` route on [router].
  ///
  /// The RPC server owns the top-level router; calling this from its setup is
  /// the only wiring needed to expose the complete `ipfs files` surface.
  void registerOn(Router router) {
    router.post('/api/v0/files/ls', handleFilesLs);
    router.post('/api/v0/files/stat', handleFilesStat);
    router.post('/api/v0/files/read', handleFilesRead);
    router.post('/api/v0/files/write', handleFilesWrite);
    router.post('/api/v0/files/mkdir', handleFilesMkdir);
    router.post('/api/v0/files/cp', handleFilesCp);
    router.post('/api/v0/files/mv', handleFilesMv);
    router.post('/api/v0/files/rm', handleFilesRm);
    router.post('/api/v0/files/flush', handleFilesFlush);
    router.post('/api/v0/files/chcid', handleFilesChcid);
    router.post('/api/v0/files/touch', handleFilesTouch);
    router.post('/api/v0/files/mtime', handleFilesTouch);
    router.post('/api/v0/files/chmod', handleFilesChmod);
  }

  /// Builds a standalone router handling the files verbs at relative paths
  /// (e.g. for `Router.mount('/api/v0/files/', ...)`).
  Handler get filesHandler {
    final router = Router()
      ..post('/ls', handleFilesLs)
      ..post('/stat', handleFilesStat)
      ..post('/read', handleFilesRead)
      ..post('/write', handleFilesWrite)
      ..post('/mkdir', handleFilesMkdir)
      ..post('/cp', handleFilesCp)
      ..post('/mv', handleFilesMv)
      ..post('/rm', handleFilesRm)
      ..post('/flush', handleFilesFlush)
      ..post('/chcid', handleFilesChcid)
      ..post('/touch', handleFilesTouch)
      ..post('/mtime', handleFilesTouch)
      ..post('/chmod', handleFilesChmod);
    return router.call;
  }

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
  /// Query parameters: `arg` (path, MFS or `/ipfs/<cid>`), `long`, `U`
  /// (unsorted). Kubo returns `{"Entries": [...]}`; without `long` each
  /// entry carries only its `Name`.
  Future<Response> handleFilesLs(Request request) async {
    final rawPath = _singleArg(request) ?? '/';
    final path = _contentOrMfsPath(rawPath);
    if (path == null) {
      return _errorResponse(
        'paths must start with a leading slash: $rawPath',
        code: 400,
      );
    }
    final long = _boolParam(request, 'long');
    final u = _boolParam(request, 'U');

    try {
      final entries = await node.mfs.ls(path, long: long, u: u);
      return _jsonResponse({
        'Entries': entries.map((e) => e.toJson()).toList(),
      });
    } catch (e, st) {
      _logger.error('files/ls failed for path: $path', e, st);
      return _errorResponse('files/ls failed: $e');
    }
  }

  /// POST /api/v0/files/stat
  ///
  /// Query parameters: `arg` (MFS or `/ipfs/<cid>` path), `with-local`,
  /// `cid-base`. Kubo's `hash`/`size` flags only change the CLI text format;
  /// the RPC response is always the full stat object, so they are accepted
  /// and ignored here.
  Future<Response> handleFilesStat(Request request) async {
    final rawPath = _singleArg(request) ?? '/';
    final path = _contentOrMfsPath(rawPath);
    if (path == null) {
      return _errorResponse(
        'paths must start with a leading slash: $rawPath',
        code: 400,
      );
    }
    final withLocal = _boolParam(request, 'with-local');
    final cidBase = request.url.queryParameters['cid-base'];

    try {
      final stat = await node.mfs.stat(
        path,
        withLocal: withLocal,
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
    final rawPath = _singleArg(request);
    if (rawPath == null) {
      return _errorResponse('argument "path" is required', code: 400);
    }
    final path = _contentOrMfsPath(rawPath);
    if (path == null) {
      return _errorResponse(
        'paths must start with a leading slash: $rawPath',
        code: 400,
      );
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
  /// Query parameters: `arg` (path), `create`, `parents`, `offset`,
  /// `truncate`, `count`, `raw-leaves`, `cid-version`, `hash`, `mode`,
  /// `mtime`, `mtime-nsecs`.
  /// The request body is multipart/form-data with the file content.
  Future<Response> handleFilesWrite(Request request) async {
    final path = _mfsPath(_singleArg(request));
    if (path == null) {
      return _errorResponse(
        'argument "path" is required and must be an absolute MFS path',
        code: 400,
      );
    }

    // Kubo defaults: --create and --truncate are both false; writing a
    // missing file without `create` is an error.
    final create = _boolParam(request, 'create');
    final parents = _boolParam(request, 'parents');
    final offset = _intParam(request, 'offset');
    final truncate = _boolParam(request, 'truncate');
    final count = _intParam(request, 'count');
    final rawLeaves = _boolParam(request, 'raw-leaves');
    final cidVersion = _intParam(request, 'cid-version');
    final hash = request.url.queryParameters['hash'];
    final mode = _modeParam(request);
    final mtimeSecs = _intParam(request, 'mtime');
    final mtimeNsecs = _intParam(request, 'mtime-nsecs');

    final invalid = _validateOffsetCount(offset, count);
    if (invalid != null) {
      return _errorResponse(invalid, code: 400);
    }
    if (cidVersion != null && (cidVersion < 0 || cidVersion > 1)) {
      return _errorResponse('Invalid cid-version: $cidVersion', code: 400);
    }
    if (mtimeNsecs != null && (mtimeNsecs < 0 || mtimeNsecs >= 1000000000)) {
      return _errorResponse('Invalid mtime-nsecs: $mtimeNsecs', code: 400);
    }
    if (request.url.queryParameters.containsKey('mode') && mode == null) {
      return _errorResponse(
        'Invalid mode: ${request.url.queryParameters['mode']}',
        code: 400,
      );
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
        parents: parents,
        rawLeaves: rawLeaves,
        cidVersion: cidVersion,
        hash: hash,
        mode: mode,
        mtimeSecs: mtimeSecs,
        mtimeNsecs: mtimeNsecs,
      );

      return Response.ok('');
    } catch (e, st) {
      _logger.error('files/write failed for path: $path', e, st);
      return _errorResponse('files/write failed: $e');
    }
  }

  /// POST /api/v0/files/mkdir
  ///
  /// Query parameters: `arg`, `parents`, `recursive`, `cid-version`, `hash`,
  /// `mode`, `mtime`, `mtime-nsecs`.
  Future<Response> handleFilesMkdir(Request request) async {
    final path = _mfsPath(_singleArg(request));
    if (path == null) {
      return _errorResponse(
        'argument "path" is required and must be an absolute MFS path',
        code: 400,
      );
    }

    final parents = _boolParam(request, 'parents');
    final recursive = _boolParam(request, 'recursive');
    final cidVersion = _intParam(request, 'cid-version');
    final hash = request.url.queryParameters['hash'];
    final mode = _modeParam(request);
    final mtimeSecs = _intParam(request, 'mtime');
    final mtimeNsecs = _intParam(request, 'mtime-nsecs');

    if (cidVersion != null && (cidVersion < 0 || cidVersion > 1)) {
      return _errorResponse('Invalid cid-version: $cidVersion', code: 400);
    }
    if (mtimeNsecs != null && (mtimeNsecs < 0 || mtimeNsecs >= 1000000000)) {
      return _errorResponse('Invalid mtime-nsecs: $mtimeNsecs', code: 400);
    }
    if (request.url.queryParameters.containsKey('mode') && mode == null) {
      return _errorResponse(
        'Invalid mode: ${request.url.queryParameters['mode']}',
        code: 400,
      );
    }

    try {
      await node.mfs.mkdir(
        path,
        recursive: recursive,
        parents: parents,
        cidVersion: cidVersion,
        hash: hash,
        mode: mode,
        mtimeSecs: mtimeSecs,
        mtimeNsecs: mtimeNsecs,
      );
      return Response.ok('');
    } catch (e, st) {
      _logger.error('files/mkdir failed for path: $path', e, st);
      return _errorResponse('files/mkdir failed: $e');
    }
  }

  /// POST /api/v0/files/cp
  ///
  /// Query parameters: two `arg` values (source, destination), `force`,
  /// `parents`. The source may be an MFS path, `/ipfs/<cid>[/sub/path]` or
  /// an `ipfs://` URI; the destination must be an absolute MFS path.
  Future<Response> handleFilesCp(Request request) async {
    final args = _allArgs(request);
    if (args.length < 2) {
      return _errorResponse(
        'argument "source" and "destination" are required',
        code: 400,
      );
    }

    final src = _contentOrMfsPath(args[0]);
    final dst = _mfsPath(args[1]);
    if (src == null || dst == null) {
      return _errorResponse('paths must start with a leading slash', code: 400);
    }

    final force = _boolParam(request, 'force');
    final parents = _boolParam(request, 'parents');

    final blocked = _checkDenylistForPath(src);
    if (blocked != null) {
      return blocked;
    }

    try {
      await node.mfs.cp(src, dst, force: force, parents: parents);
      return Response.ok('');
    } catch (e, st) {
      _logger.error('files/cp failed: $src -> $dst', e, st);
      return _errorResponse('files/cp failed: $e');
    }
  }

  /// POST /api/v0/files/mv
  ///
  /// Query parameters: two `arg` values (source, destination), both absolute
  /// MFS paths.
  Future<Response> handleFilesMv(Request request) async {
    final args = _allArgs(request);
    if (args.length < 2) {
      return _errorResponse(
        'argument "source" and "destination" are required',
        code: 400,
      );
    }

    final src = _mfsPath(args[0]);
    final dst = _mfsPath(args[1]);
    if (src == null || dst == null) {
      return _errorResponse('paths must start with a leading slash', code: 400);
    }

    final blocked = _checkDenylistForPath(src);
    if (blocked != null) {
      return blocked;
    }

    try {
      await node.mfs.mv(src, dst);
      return Response.ok('');
    } catch (e, st) {
      _logger.error('files/mv failed: $src -> $dst', e, st);
      return _errorResponse('files/mv failed: $e');
    }
  }

  /// POST /api/v0/files/rm
  ///
  /// Query parameters: one or more `arg` values (Kubo `files rm` is
  /// variadic), `recursive`, `force`.
  Future<Response> handleFilesRm(Request request) async {
    final args = _allArgs(request);
    if (args.isEmpty) {
      return _errorResponse('argument "path" is required', code: 400);
    }

    final recursive = _boolParam(request, 'recursive');
    final force = _boolParam(request, 'force');

    final errors = <String>[];
    for (final arg in args) {
      final path = _mfsPath(arg);
      if (path == null) {
        errors.add('$arg is not a valid path');
        continue;
      }
      try {
        await node.mfs.rm(path, recursive: recursive, force: force);
      } catch (e) {
        errors.add('$path: $e');
      }
    }
    if (errors.isNotEmpty) {
      _logger.error('files/rm failed: ${errors.join('; ')}');
      return _errorResponse("can't remove some files: ${errors.join('; ')}");
    }
    return Response.ok('');
  }

  /// POST /api/v0/files/flush
  ///
  /// Query parameters: `arg` (default `/`). Returns `{"Cid": "<cid>"}` with
  /// the CID of the flushed path (the root CID for `/`), matching Kubo.
  Future<Response> handleFilesFlush(Request request) async {
    final rawPath = _singleArg(request) ?? '/';
    final path = _mfsPath(rawPath);
    if (path == null) {
      return _errorResponse(
        'paths must start with a leading slash: $rawPath',
        code: 400,
      );
    }

    try {
      final cid = await node.mfs.flush(path: path);
      return _jsonResponse({'Cid': cid.encode()});
    } catch (e, st) {
      _logger.error('files/flush failed for path: $path', e, st);
      return _errorResponse('files/flush failed: $e');
    }
  }

  /// POST /api/v0/files/chcid
  ///
  /// Query parameters: `arg` (must not be `/`; directories only in Kubo),
  /// `cid-version`, `hash`.
  Future<Response> handleFilesChcid(Request request) async {
    final path = _mfsPath(_singleArg(request));
    if (path == null) {
      return _errorResponse(
        'argument "path" is required and must be an absolute MFS path',
        code: 400,
      );
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

  /// POST /api/v0/files/touch
  ///
  /// Sets the modification time on an MFS path (UnixFS 1.5). Query
  /// parameters: `arg` (path), `mtime` (seconds), `mtime-nsecs`. Without
  /// `mtime` the current time is applied.
  Future<Response> handleFilesTouch(Request request) async {
    final path = _mfsPath(_singleArg(request));
    if (path == null) {
      return _errorResponse(
        'argument "path" is required and must be an absolute MFS path',
        code: 400,
      );
    }

    final mtimeSecs = _intParam(request, 'mtime');
    final mtimeNsecs = _intParam(request, 'mtime-nsecs');

    if (mtimeNsecs != null && (mtimeNsecs < 0 || mtimeNsecs >= 1000000000)) {
      return _errorResponse('Invalid mtime-nsecs: $mtimeNsecs', code: 400);
    }

    try {
      await node.mfs.touch(path, mtimeSecs: mtimeSecs, mtimeNsecs: mtimeNsecs);
      return Response.ok('');
    } catch (e, st) {
      _logger.error('files/touch failed for path: $path', e, st);
      return _errorResponse('files/touch failed: $e');
    }
  }

  /// POST /api/v0/files/mtime
  ///
  /// Alias for [handleFilesTouch] — sets the modification time on an MFS
  /// path. Accepts the same `arg`, `mtime`, `mtime-nsecs` parameters.
  Future<Response> handleFilesMtime(Request request) =>
      handleFilesTouch(request);

  /// POST /api/v0/files/chmod
  ///
  /// Query parameters: two `arg` values (mode in numeric notation, path).
  Future<Response> handleFilesChmod(Request request) async {
    final args = _allArgs(request);
    if (args.length < 2) {
      return _errorResponse(
        'argument "mode" and "path" are required',
        code: 400,
      );
    }

    final mode = _parseMode(args[0]);
    if (mode == null) {
      return _errorResponse('Invalid mode: ${args[0]}', code: 400);
    }

    final path = _mfsPath(args[1]);
    if (path == null) {
      return _errorResponse(
        'paths must start with a leading slash: ${args[1]}',
        code: 400,
      );
    }

    try {
      await node.mfs.chmod(path, mode);
      return Response.ok('');
    } catch (e, st) {
      _logger.error('files/chmod failed for path: $path', e, st);
      return _errorResponse('files/chmod failed: $e');
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

  /// Validates an MFS-only path argument the way Kubo's `checkPath` does:
  /// it must be non-empty and start with a leading slash. Returns null when
  /// invalid.
  String? _mfsPath(String? arg) {
    if (arg == null || arg.isEmpty || !arg.startsWith('/')) return null;
    return arg;
  }

  /// Validates an argument that may be an MFS path or a content path, like
  /// Kubo's `checkContentOrMfsPath`: `/ipfs/...` (and `ipfs://`/`ipns://`
  /// URIs, rewritten to canonical path form) alongside absolute MFS paths.
  /// Returns null when the argument is not an acceptable path.
  String? _contentOrMfsPath(String? arg) {
    if (arg == null || arg.isEmpty) return null;
    if (arg.startsWith('ipfs://')) return '/ipfs/${arg.substring(7)}';
    if (arg.startsWith('ipns://')) return '/ipns/${arg.substring(7)}';
    if (!arg.startsWith('/')) return null;
    return arg;
  }

  /// Parses a Kubo-style boolean query option. A present-but-empty value
  /// (`?flag=`) counts as `true`, matching Kubo's option parsing.
  bool _boolParam(Request request, String name, {bool defaultValue = false}) {
    final value = request.url.queryParameters[name];
    if (value == null) return defaultValue;
    if (value.isEmpty) return true;
    return value == 'true' || value == '1';
  }

  int? _intParam(Request request, String name) {
    final value = request.url.queryParameters[name];
    if (value == null || value.isEmpty) return null;
    return int.tryParse(value);
  }

  /// Parses the `mode` query parameter (POSIX numeric mode). Accepts octal
  /// (`0644`, `644`) or `0o644`/`0x1a4` style values.
  int? _modeParam(Request request) {
    final value = request.url.queryParameters['mode'];
    if (value == null) return null;
    return _parseMode(value);
  }

  /// Parses a POSIX mode string. Modes are conventionally octal; a leading
  /// `0` or an explicit `0o`/`0x` prefix is honored, otherwise the value is
  /// treated as octal when all digits are valid octal digits and decimal
  /// otherwise — matching `ipfs files chmod` numeric notation.
  static int? _parseMode(String value) {
    var v = value.trim();
    if (v.isEmpty) return null;
    if (v.startsWith('0x') || v.startsWith('0X')) {
      return int.tryParse(v.substring(2), radix: 16);
    }
    if (v.startsWith('0o') || v.startsWith('0O')) {
      return int.tryParse(v.substring(2), radix: 8);
    }
    if (v.startsWith('0') && v.length > 1) {
      return int.tryParse(v, radix: 8);
    }
    // Prefer octal when the digits are all valid octal digits (POSIX mode
    // convention: 644 means 0644), falling back to decimal for values like
    // '999' that cannot be octal.
    if (RegExp(r'^[0-7]+$').hasMatch(v)) {
      return int.tryParse(v, radix: 8);
    }
    return int.tryParse(v);
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
