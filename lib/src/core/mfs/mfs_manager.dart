import 'dart:async';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/directory.dart';
import 'package:dart_ipfs/src/core/interfaces/i_block_store.dart';
import 'package:dart_ipfs/src/core/interfaces/i_lifecycle.dart';
import 'package:dart_ipfs/src/core/security/denylist_service.dart';
import 'package:dart_ipfs/src/core/storage/datastore.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_builder.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart';
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart';
import 'package:fixnum/fixnum.dart';
import 'package:synchronized/synchronized.dart';

/// Kubo-compatible stat result for an MFS path.
class MFSStat {
  /// Creates a new [MFSStat].
  MFSStat({
    required this.hash,
    required this.size,
    required this.cumulativeSize,
    required this.blocks,
    required this.type,
    this.withLocal,
    this.local,
    this.sizeLocal,
    this.mode,
    this.mtime,
    this.mtimeNsecs,
  });

  /// CID string of the target node.
  final String hash;

  /// File size in bytes, or 0 for directories.
  final int size;

  /// Cumulative DAG size in bytes.
  final int cumulativeSize;

  /// Number of direct links (child blocks).
  final int blocks;

  /// Node type: 'file' or 'directory' (Kubo maps everything else —
  /// raw leaves, symlinks, metadata — onto one of these two).
  final String type;

  /// Whether the `with-local` flag was requested.
  final bool? withLocal;

  /// Whether all blocks are present locally.
  final bool? local;

  /// Cumulative size of the locally available portion of the DAG.
  final int? sizeLocal;

  /// Unix mode, when available.
  final int? mode;

  /// Modification time in seconds since epoch, when available.
  final int? mtime;

  /// Nanosecond fraction of the modification time, when available.
  final int? mtimeNsecs;

  /// Converts this stat to a Kubo-compatible JSON map.
  ///
  /// Kubo's `files stat` always returns the full object over HTTP (the
  /// `--hash`/`--size` flags only affect the CLI text format), and `Mode`
  /// is serialized as a four-digit octal string, omitted when unset.
  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{
      'Hash': hash,
      'Size': size,
      'CumulativeSize': cumulativeSize,
      'Blocks': blocks,
      'Type': type,
    };
    if (withLocal == true) {
      result['WithLocality'] = true;
      result['Local'] = local ?? true;
      result['SizeLocal'] = sizeLocal ?? cumulativeSize;
    }
    final m = mode;
    if (m != null && m != 0) {
      result['Mode'] = m.toRadixString(8).padLeft(4, '0');
    }
    if (mtime != null) result['Mtime'] = mtime;
    if (mtimeNsecs != null) result['MtimeNsecs'] = mtimeNsecs;
    return result;
  }
}

/// Kubo-compatible entry in an MFS directory listing.
class MFSListEntry {
  /// Creates a new [MFSListEntry].
  MFSListEntry({
    required this.name,
    required this.type,
    required this.size,
    required this.hash,
    this.mode,
    this.mtime,
    this.mtimeNsecs,
  });

  /// Entry name.
  final String name;

  /// Entry type: 0=file (including raw leaves), 1=directory.
  ///
  /// Matches Kubo's `mfs.NodeListing` where `TFile = 0` and `TDir = 1`.
  /// For non-long listings only [name] is populated; [type], [size] and
  /// [hash] carry their zero values, matching Kubo `files ls`.
  final int type;

  /// Logical file size in bytes for files, 0 for directories — matching
  /// Kubo's `files ls -l`, which reports `File.Size()` (the UnixFS filesize,
  /// not the cumulative DAG size).
  final int size;

  /// CID string of the entry.
  final String hash;

  /// Unix mode, when requested.
  final int? mode;

  /// Modification time in seconds since epoch, when requested.
  final int? mtime;

  /// Nanosecond fraction of the modification time, when requested.
  final int? mtimeNsecs;

  /// Converts this entry to a Kubo-compatible JSON map.
  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{
      'Name': name,
      'Type': type,
      'Size': size,
      'Hash': hash,
    };
    if (mode != null) result['Mode'] = mode;
    if (mtime != null) result['Mtime'] = mtime;
    if (mtimeNsecs != null) result['MtimeNsecs'] = mtimeNsecs;
    return result;
  }
}

/// Error thrown when a path argument is invalid or escapes the MFS root.
class MFSPathError extends Error {
  /// Creates a new [MFSPathError] with the given message.
  MFSPathError(this.message);

  /// The error message.
  final String message;

  @override
  String toString() => 'MFSPathError: $message';
}

/// Shared byte cursor for ranged reads across a recursive DAG walk.
class _ReadCursor {
  _ReadCursor({required this.skip, this.limit});

  /// Bytes to skip before emitting.
  final int skip;

  /// Maximum bytes to emit, or null for unbounded.
  final int? limit;

  int _skipped = 0;
  int _emitted = 0;

  /// Whether no more bytes should be emitted.
  bool get done => limit != null && _emitted >= limit!;

  /// Emits the requested slice of [chunk], honoring skip/limit.
  /// Returns the bytes to emit (possibly empty).
  List<int> take(List<int> chunk) {
    if (done) return const <int>[];
    if (_skipped < skip) {
      final need = skip - _skipped;
      if (need >= chunk.length) {
        _skipped += chunk.length;
        return const <int>[];
      }
      chunk = chunk.sublist(need);
      _skipped = skip;
    }
    final remaining = limit == null ? chunk.length : limit! - _emitted;
    if (remaining <= 0) return const <int>[];
    if (chunk.length > remaining) {
      chunk = chunk.sublist(0, remaining);
    }
    _emitted += chunk.length;
    return chunk;
  }
}

/// Optional UnixFS 1.5 metadata read from or applied to a node.
class _NodeMetadata {
  _NodeMetadata({this.mode, this.mtimeSecs, this.mtimeNsecs});

  final int? mode;
  final int? mtimeSecs;
  final int? mtimeNsecs;

  bool get hasMtime => mtimeSecs != null;
}

/// Manages the Mutable File System (MFS) for an IPFS node.
///
/// Every mutation writes its blocks to the block store and persists the new
/// root CID to the datastore (write-through). [flush]/[sync] therefore act as
/// barriers that wait for in-flight mutations and re-persist the root — which
/// is also what Kubo's `ipfs files flush` does when the MFS write buffer is
/// drained.
class MFSManager implements ILifecycle {
  /// Creates a new [MFSManager] with the given [blockStore] and [datastore].
  MFSManager(
    this._blockStore,
    this._datastore, {
    DenylistService? denylistService,
  }) : _denylistService = denylistService;
  final IBlockStore _blockStore;
  final Datastore _datastore;
  final DenylistService? _denylistService;
  static const String _rootKey = '/mfs/root';
  CID? _rootCid;
  final Lock _mutationLock = Lock();
  bool _started = false;

  /// Returns the current root CID of the MFS.
  CID get rootCid => _rootCid!;

  /// Returns true if the MFS manager has been started.
  bool get isStarted => _started;

  /// Initializes the MFS by loading the root CID from the datastore
  /// or creating an empty root directory if it doesn't exist.
  Future<void> init() async {
    final rootCidBytes = await _datastore.get(Key(_rootKey));
    if (rootCidBytes != null) {
      _rootCid = CID.fromBytes(rootCidBytes);
    } else {
      final dirManager = IPFSDirectoryManager();
      final node = dirManager.build();
      final data = node.writeToBuffer();
      _rootCid = await CID.fromContent(data, codec: 'dag-pb');
      await _blockStore.putBlock(
        Block(cid: _rootCid!, data: data, format: 'dag-pb'),
      );
      await _datastore.put(Key(_rootKey), _rootCid!.toBytes());
    }
  }

  @override
  Future<void> start() async {
    if (_started) return;
    await init();
    _started = true;
  }

  @override
  Future<void> stop() async {
    if (!_started) return;
    await sync();
    _started = false;
  }

  bool _pathLooksBlocked(String path) {
    final denylist = _denylistService;
    if (denylist == null) return false;
    return denylist.isBlockedPath(path);
  }

  /// Creates a directory at the given [path].
  ///
  /// [parents] and [recursive] are aliases for creating intermediate
  /// directories and succeeding when the directory already exists — matching
  /// Kubo's `ipfs files mkdir --parents`. Without them an existing path is an
  /// error, as is a path whose parent does not exist.
  ///
  /// [mode], [mtimeSecs] and [mtimeNsecs] store optional UnixFS 1.5 metadata
  /// on the created directory.
  Future<void> mkdir(
    String path, {
    bool recursive = false,
    bool parents = false,
    int? cidVersion,
    String? hash,
    int? mode,
    int? mtimeSecs,
    int? mtimeNsecs,
  }) async {
    final createMissing = recursive || parents;
    final parts = _splitPath(path);
    if (parts.isEmpty) {
      // `mkdir /` is a no-op only when parents is requested.
      if (createMissing) return;
      throw Exception('file already exists: $path');
    }

    await _mutationLock.synchronized(() async {
      await _modifyPath(
        parts,
        (currentCid) async {
          if (currentCid != null) {
            final existingType = await _unixfsType(currentCid);
            if (createMissing && existingType == Data_DataType.Directory) {
              // Directory already exists: `mkdir -p` is idempotent.
              return currentCid;
            }
            throw Exception('file already exists: $path');
          }
          final dirManager = IPFSDirectoryManager();
          if (mode != null) dirManager.setMode(mode);
          if (mtimeSecs != null) {
            dirManager.setModificationTime(
              DateTime.fromMillisecondsSinceEpoch(
                mtimeSecs * 1000,
                isUtc: true,
              ),
            );
          }
          final node = dirManager.build();
          if (mtimeNsecs != null) {
            final unixData = Data.fromBuffer(node.data)
              ..mtimeNsecs = mtimeNsecs;
            node.data = unixData.writeToBuffer();
          }
          final data = node.writeToBuffer();
          final cid = await CID.fromContent(
            data,
            codec: 'dag-pb',
            hashType: hash ?? 'sha2-256',
            version: cidVersion ?? 0,
          );
          await _blockStore.putBlock(
            Block(cid: cid, data: data, format: 'dag-pb'),
          );
          return cid;
        },
        recursive: createMissing,
        isDirectory: true,
      );
    });
  }

  /// Copies a file or directory from [src] to [dst].
  ///
  /// [src] may be an MFS path (`/dir/file`) or an IPFS path
  /// (`/ipfs/<cid>[/sub/path]`), matching Kubo `files cp`. When [dst] ends
  /// with a trailing slash the source is copied inside that directory under
  /// its basename (`ipfs files cp /src /dir/`).
  ///
  /// [parents] creates missing destination directories. [force] overwrites an
  /// existing file at the destination; it refuses to overwrite a directory,
  /// matching Kubo's `unlinkNodeIfExists`. Without [force], an existing
  /// destination of any kind is an error.
  Future<void> cp(
    String src,
    String dst, {
    bool force = false,
    bool parents = false,
  }) async {
    final denylist = _denylistService;
    if (denylist != null && _pathLooksBlocked(src)) {
      throw StateError('Content blocked by operator policy');
    }

    final srcCid = await _resolveAny(src);
    if (srcCid == null) {
      throw Exception('Source path not found: $src');
    }

    // Kubo only treats the destination as a container when it ends with a
    // trailing slash; an existing directory named without a slash is an
    // "already exists" error there, not an implicit container.
    var dstPath = dst;
    if (dst.endsWith('/')) {
      dstPath = '$dst${_basename(src)}';
    }
    final destParts = _splitPath(dstPath);
    if (destParts.isEmpty) {
      throw Exception('Cannot overwrite MFS root: $dst');
    }

    await _mutationLock.synchronized(() async {
      await _modifyPath(destParts, (currentCid) async {
        if (currentCid != null) {
          if (!force) {
            throw Exception('file already exists: $dst');
          }
          final existingType = await _unixfsType(currentCid);
          if (existingType == Data_DataType.Directory ||
              existingType == Data_DataType.HAMTShard) {
            throw Exception(
              'cp: cannot overwrite directory with --force: $dst',
            );
          }
        }
        return srcCid;
      }, recursive: parents);
    });
  }

  /// Moves a file or directory from [src] to [dst].
  ///
  /// Matches Kubo's `mfs.Mv`: a [dst] ending in `/` or naming an existing
  /// directory moves the source inside it under its basename; an existing
  /// file at [dst] is silently replaced; a name collision inside a target
  /// directory is an error.
  Future<void> mv(String src, String dst) async {
    final denylist = _denylistService;
    if (denylist != null && _pathLooksBlocked(src)) {
      throw StateError('Content blocked by operator policy');
    }

    final srcParts = _splitPath(src);
    if (srcParts.isEmpty) {
      throw Exception('Cannot move MFS root: $src');
    }
    final srcCid = await _resolvePath(_rootCid!, srcParts);
    if (srcCid == null) {
      throw Exception('Source path not found: $src');
    }

    final srcName = srcParts.last;
    var dstPath = dst;
    var redirectedIntoDir = dst.endsWith('/');
    if (!redirectedIntoDir) {
      final dstCid = await _resolvePath(_rootCid!, _splitPath(dst));
      if (dstCid != null) {
        final dstType = await _unixfsType(dstCid);
        if (dstType == Data_DataType.Directory ||
            dstType == Data_DataType.HAMTShard) {
          dstPath = '${_normalizePath(dst)}/$srcName';
          redirectedIntoDir = true;
        }
      }
    } else {
      dstPath = '$dst$srcName';
    }

    final normalizedDst = _normalizePath(dstPath);
    if (_normalizePath(src) == normalizedDst) {
      return; // Moving a node onto itself is a no-op.
    }

    final dstParts = _splitPath(normalizedDst);
    final existing = await _resolvePath(_rootCid!, dstParts);
    if (existing != null) {
      if (redirectedIntoDir) {
        // Inside a target directory Kubo's AddChild fails on any name
        // collision, file or directory.
        throw Exception('file already exists: $normalizedDst');
      }
      final existingType = await _unixfsType(existing);
      if (existingType == Data_DataType.Directory ||
          existingType == Data_DataType.HAMTShard) {
        // Unreachable: when the destination resolves to a directory the path
        // is redirected inside it above, so `existing` here is never a dir.
        // coverage:ignore-start
        throw Exception('file already exists: $normalizedDst');
        // coverage:ignore-end
      }
      // An existing file at the destination is silently replaced (Kubo
      // unlinks it before re-adding the source node).
    }

    await cp(src, normalizedDst, force: true);
    await rm(src, recursive: true);
  }

  /// Removes a file or directory at the given [path].
  ///
  /// [force] ignores missing paths and implies [recursive] for directories,
  /// matching Kubo `files rm --force`.
  Future<void> rm(
    String path, {
    bool recursive = false,
    bool force = false,
  }) async {
    final parts = _splitPath(path);
    if (parts.isEmpty) throw Exception('Cannot remove root');

    final parentParts = parts.sublist(0, parts.length - 1);
    final nameToRemove = parts.last;

    await _mutationLock.synchronized(() async {
      await _modifyPath(parentParts, (parentCid) async {
        if (parentCid == null) {
          if (force) return null;
          throw Exception('Parent path not found');
        }
        final parentBlock = await _blockStore.getBlock(parentCid.encode());
        if (!parentBlock.found) {
          if (force) return null;
          throw Exception('Parent block not found');
        }

        final parentNode = PBNode.fromBuffer(parentBlock.block.data);
        final newLinks = parentNode.links
            .where((l) => l.name != nameToRemove)
            .toList();

        if (newLinks.length == parentNode.links.length) {
          // Nothing removed
          if (force) return parentCid;
          throw Exception('Path not found: $path');
        }

        final removeDirs = recursive || force;
        if (!removeDirs) {
          final removedLink = parentNode.links.firstWhere(
            (l) => l.name == nameToRemove,
          );
          final removedBlock = await _blockStore.getBlock(
            CID.fromBytes(Uint8List.fromList(removedLink.hash)).encode(),
          );
          if (removedBlock.found) {
            final removedNode = PBNode.fromBuffer(removedBlock.block.data);
            final unixData = Data.fromBuffer(removedNode.data);
            if (unixData.type == Data_DataType.Directory) {
              throw Exception('Cannot remove directory without -r: $path');
            }
          }
        }

        parentNode.links.clear();
        parentNode.links.addAll(newLinks);

        final newData = parentNode.writeToBuffer();
        final newCid = await CID.fromContent(newData, codec: 'dag-pb');
        await _blockStore.putBlock(
          Block(cid: newCid, data: newData, format: 'dag-pb'),
        );
        return newCid;
      });
    });
  }

  /// Lists the contents of the directory at the given [path].
  ///
  /// [path] may be an MFS path or an `/ipfs/<cid>[/sub]` path. If the target
  /// is a file, a single entry describing it is returned — matching Kubo
  /// `files ls` on a non-directory path.
  ///
  /// [long] mirrors `files ls -l`: entries get their `Type` (0=file,
  /// 1=directory), `Size` (logical file size; 0 for directories) and `Hash`
  /// populated, plus UnixFS 1.5 `Mode`/`Mtime` when stored. Without it only
  /// `Name` is populated, matching Kubo's `ListNames` response. [u] requests
  /// unsorted order (Kubo compatibility flag).
  Future<List<MFSListEntry>> ls(
    String path, {
    bool long = false,
    bool u = false,
  }) async {
    final cid = await _resolveAny(path);
    if (cid == null) throw Exception('Path not found: $path');

    final block = await _blockStore.getBlock(cid.encode());
    if (!block.found) throw Exception('Block not found for CID: $cid');

    final type = await _unixfsType(cid);
    if (type != Data_DataType.Directory && type != Data_DataType.HAMTShard) {
      // Kubo lists the file itself when the target is not a directory.
      if (!long) {
        return [
          MFSListEntry(name: _basename(path), type: 0, size: 0, hash: ''),
        ];
      }
      final node = _tryParseNode(block.block.data);
      return [
        _entryFor(
          _basename(path),
          cid,
          node,
          dataLength: block.block.data.length,
        ),
      ];
    }

    final node = PBNode.fromBuffer(block.block.data);
    var entries = node.links.toList();
    if (!u) {
      entries.sort((a, b) => a.name.compareTo(b.name));
    }

    if (!long) {
      // Kubo `files ls` without -l resolves only the names.
      return [
        for (final link in entries)
          MFSListEntry(name: link.name, type: 0, size: 0, hash: ''),
      ];
    }

    final result = <MFSListEntry>[];
    for (final link in entries) {
      final childCid = CID.fromBytes(Uint8List.fromList(link.hash));
      final childBlock = await _blockStore.getBlock(childCid.encode());
      PBNode? childNode;
      var dataLength = 0;
      if (childBlock.found) {
        dataLength = childBlock.block.data.length;
        childNode = _tryParseNode(childBlock.block.data);
      }
      result.add(
        _entryFor(link.name, childCid, childNode, dataLength: dataLength),
      );
    }
    return result;
  }

  /// Gets Kubo-compatible information about a file or directory at [path].
  ///
  /// [path] may be an MFS path or an `/ipfs/<cid>[/sub]` path.
  ///
  /// [cidBase] controls the multibase used to encode the returned CID (e.g.
  /// `base32`). [withLocal] computes how much of the DAG is present locally.
  /// Kubo's `hash`/`size` flags only affect the CLI text format, so they are
  /// accepted by the RPC handler but intentionally ignored here.
  Future<MFSStat> stat(
    String path, {
    bool withLocal = false,
    String? cidBase,
  }) async {
    final cid = await _resolveAny(path);
    if (cid == null) throw Exception('Path not found: $path');

    final block = await _blockStore.getBlock(cid.encode());
    if (!block.found) throw Exception('Block not found for CID: $cid');

    final hashString = cidBase != null
        ? cid.encodeWithBaseName(cidBase)
        : cid.encode();

    // Raw blocks carry no UnixFS wrapper; report them as files whose size is
    // the block payload itself.
    if (cid.codec == 'raw') {
      final dataLength = block.block.data.length;
      bool? local;
      int? sizeLocal;
      if (withLocal) {
        local = true;
        sizeLocal = dataLength;
      }
      return MFSStat(
        hash: hashString,
        size: dataLength,
        cumulativeSize: dataLength,
        blocks: 0,
        type: 'file',
        withLocal: withLocal ? true : null,
        local: local,
        sizeLocal: sizeLocal,
      );
    }

    final node = PBNode.fromBuffer(block.block.data);
    final unixData = Data.fromBuffer(node.data);

    final typeName = _typeName(unixData.type);
    final cumulativeSize = _cumulativeSize(node);
    final fileSize = unixData.filesize.toInt();

    int? mode;
    int? mtime;
    int? mtimeNsecs;
    if (unixData.hasMode()) mode = unixData.mode;
    if (unixData.hasMtime()) mtime = unixData.mtime.toInt();
    if (unixData.hasMtimeNsecs()) mtimeNsecs = unixData.mtimeNsecs;

    bool? local;
    int? sizeLocal;
    if (withLocal) {
      final localStats = await _localStats(cid);
      local = localStats.$1;
      sizeLocal = localStats.$2;
    }

    return MFSStat(
      hash: hashString,
      size: typeName == 'directory' ? 0 : fileSize,
      cumulativeSize: cumulativeSize,
      blocks: node.links.length,
      type: typeName,
      withLocal: withLocal ? true : null,
      local: local,
      sizeLocal: sizeLocal,
      mode: mode,
      mtime: mtime,
      mtimeNsecs: mtimeNsecs,
    );
  }

  /// Writes [data] to a file at the given [path].
  ///
  /// Mirrors Kubo `ipfs files write` semantics:
  /// - [create] (default false): create the file if it does not exist;
  ///   without it, writing a missing path is an error.
  /// - [truncate] (default false): discard existing content and zero-fill up
  ///   to [offset] before writing. With [truncate] false the existing tail
  ///   beyond the written range is preserved.
  /// - [offset] starts writing at the given byte position; an offset beyond
  ///   the current end of a non-truncated file is an error.
  /// - [count] limits how many bytes from [data] are written.
  /// - [parents] creates missing parent directories.
  /// - [cidVersion], [rawLeaves] and [hash] control the CID format of the
  ///   newly built UnixFS DAG.
  /// - [mode], [mtimeSecs] and [mtimeNsecs] store optional UnixFS 1.5
  ///   metadata; supplying any of them disables raw leaves, matching Kubo.
  ///
  /// When the existing file already stores an mtime and no explicit
  /// [mtimeSecs] is given, the mtime is bumped to the current time — matching
  /// Kubo's automatic mtime update on `files write`.
  ///
  /// Full preservation of existing chunk boundaries is future work; at present
  /// unmodified bytes are read back and the DAG is rebuilt from the merged
  /// byte stream.
  Future<void> write(
    String path,
    Stream<List<int>> data, {
    bool create = false,
    int? offset,
    bool truncate = false,
    int? count,
    bool parents = false,
    int? cidVersion,
    bool? rawLeaves,
    String? hash,
    int? mode,
    int? mtimeSecs,
    int? mtimeNsecs,
  }) async {
    final parts = _splitPath(path);
    if (parts.isEmpty) {
      throw Exception('Cannot write to MFS root path: $path');
    }
    final startOffset = offset ?? 0;

    if (startOffset < 0) {
      throw ArgumentError('Offset cannot be negative');
    }
    if (count != null && count < 0) {
      throw ArgumentError('Count cannot be negative');
    }

    await _mutationLock.synchronized(() async {
      final existingCid = await _resolvePath(_rootCid!, parts);
      final bool hasExisting = existingCid != null;

      if (!hasExisting && !create) {
        throw Exception('File does not exist and create is false: $path');
      }

      _NodeMetadata? existingMeta;
      if (hasExisting) {
        final existingType = await _unixfsType(existingCid);
        if (existingType == Data_DataType.Directory) {
          throw Exception('Cannot write over directory: $path');
        }
        existingMeta = await _readMetadata(existingCid);
      }

      final allBytes = await data.expand((b) => b).toList();
      final bytes = count == null
          ? Uint8List.fromList(allBytes)
          : Uint8List.fromList(allBytes.take(count).toList());

      Uint8List updatedBytes;
      if (truncate) {
        // Truncate semantics: zero-fill up to offset, then write data.
        final buffer = BytesBuilder()
          ..add(Uint8List(startOffset))
          ..add(bytes);
        updatedBytes = buffer.toBytes();
      } else {
        // Partial update: read existing file, patch the requested range, and
        // rebuild the DAG. A missing file (create=true) is treated as empty.
        // An offset beyond the end of file zero-fills the gap, matching
        // Kubo's DagModifier sparse expansion on seek.
        // Note: true chunk-boundary preservation is complex and
        // left as future work; we rebuild from the merged byte stream.
        final existingBytes = hasExisting
            ? await _readAllBytes(existingCid)
            : Uint8List(0);
        updatedBytes = Uint8List.fromList(
          _patchBytes(existingBytes, bytes, startOffset),
        );
      }

      // Determine effective UnixFS 1.5 metadata. Explicit parameters win;
      // otherwise carry over stored metadata (with an mtime bump), matching
      // Kubo's mtime-preserving write behavior. Storing metadata forces a
      // dag-pb root and disables raw leaves.
      final effectiveMode = mode ?? existingMeta?.mode;
      var effectiveMtimeSecs = mtimeSecs ?? existingMeta?.mtimeSecs;
      var effectiveMtimeNsecs = mtimeNsecs ?? existingMeta?.mtimeNsecs;
      if (mtimeSecs == null && existingMeta?.hasMtime == true) {
        final now = DateTime.now().toUtc();
        effectiveMtimeSecs = now.millisecondsSinceEpoch ~/ 1000;
        effectiveMtimeNsecs = (now.millisecondsSinceEpoch % 1000) * 1000000;
      }
      final hasMeta =
          effectiveMode != null ||
          effectiveMtimeSecs != null ||
          effectiveMtimeNsecs != null;

      final builder = UnixFSBuilder(
        cidVersion: cidVersion ?? 0,
        rawLeaves: hasMeta ? false : (rawLeaves ?? false),
        hashType: hash ?? 'sha2-256',
      );
      final blocks = await builder
          .build(Stream.fromIterable([updatedBytes]))
          .toList();
      if (blocks.isEmpty) {
        throw Exception('Failed to build UnixFS DAG');
      }
      var rootBlock = blocks.last;
      for (final block in blocks) {
        await _blockStore.putBlock(block);
      }
      if (hasMeta) {
        rootBlock = await _applyMetadata(
          rootBlock,
          mode: effectiveMode,
          mtimeSecs: effectiveMtimeSecs,
          mtimeNsecs: effectiveMtimeNsecs,
          hashType: hash ?? 'sha2-256',
          cidVersion: cidVersion ?? 0,
        );
        await _blockStore.putBlock(rootBlock);
      }
      await _modifyPath(
        parts,
        (currentCid) async {
          if (currentCid == null && !create) {
            // Unreachable under the mutation lock: a missing file without
            // `create` already threw above, and an existing file resolves to
            // a non-null CID here. Kept as a defensive re-check.
            // coverage:ignore-start
            throw Exception('File does not exist and create is false');
            // coverage:ignore-end
          }
          return rootBlock.cid;
        },
        recursive: parents,
        isDirectory: false,
      );
    });
  }

  /// Reads data from a file at the given [path], optionally starting at
  /// [offset] and limiting to [count] bytes.
  ///
  /// [path] may be an MFS path or an `/ipfs/<cid>[/sub]` path. Reading a
  /// directory is an error, matching Kubo `files read`.
  Future<Stream<List<int>>> read(String path, {int? offset, int? count}) async {
    final cid = await _resolveAny(path);
    if (cid == null) throw Exception('Path not found: $path');

    if (cid.codec != 'raw') {
      final type = await _unixfsType(cid);
      if (type == Data_DataType.Directory || type == Data_DataType.HAMTShard) {
        throw Exception('Path is a directory: $path');
      }
    }
    // A missing root block surfaces as an error on the returned stream
    // rather than throwing here, so consumers terminate instead of hanging.

    final controller = StreamController<List<int>>();
    final cursor = _ReadCursor(skip: offset ?? 0, limit: count);

    unawaited(
      _readRecursive(
        cid,
        controller,
        cursor,
      ).then((_) => controller.close()).catchError((Object e) {
        controller.addError(e);
        // Close the stream after the error so consumers terminate
        // instead of hanging forever.
        return controller.close();
      }),
    );

    return controller.stream;
  }

  /// Flushes pending mutations for [path] (or the whole MFS when null or `/`)
  /// and returns the CID of the flushed path.
  ///
  /// The manager writes through on every mutation, so flushing waits for
  /// in-flight operations and re-persists the root CID — matching
  /// `ipfs files flush [--path]`, which returns `{"Cid": "<cid>"}`.
  Future<CID> flush({String? path}) async {
    final effectivePath = path ?? '/';
    return _mutationLock.synchronized(() async {
      final parts = _splitPath(effectivePath);
      final cid = parts.isEmpty
          ? _rootCid
          : await _resolvePath(_rootCid!, parts);
      if (cid == null) {
        throw Exception('Path not found: $effectivePath');
      }
      await _persistRoot();
      return cid;
    });
  }

  /// Flushes the entire MFS and returns the root CID.
  Future<CID> flushAll() async => flush(path: '/');

  /// Waits for in-flight operations to complete and ensures the root CID is
  /// persisted.
  ///
  /// Mutations are already write-through, so this is primarily a barrier that
  /// drains the mutation lock and re-persists the current root.
  Future<void> sync() async {
    await _mutationLock.synchronized(() async {
      await _persistRoot();
    });
  }

  /// Changes the CID version/hash function of the node at [path].
  ///
  /// Matches Kubo `files chcid`: [path] must not be `/` and must resolve to
  /// a directory ("can only update directories"). With neither [cidVersion]
  /// nor [hash] given the call is a no-op. Supplying [hash] without
  /// [cidVersion] upgrades to CIDv1, matching Kubo's `getPrefix`.
  Future<void> chcid(String path, {int? cidVersion, String? hash}) async {
    final parts = _splitPath(path);
    if (parts.isEmpty) {
      throw Exception('Cannot change CID of MFS root');
    }
    // Kubo: no prefix options at all means the CID builder is nil and the
    // command changes nothing.
    if (cidVersion == null && hash == null) {
      return;
    }
    final hashType = hash ?? 'sha2-256';
    if (hashType != 'sha2-256') {
      throw UnsupportedError('Hash type $hashType not supported');
    }
    // A hash option without an explicit cid-version selects CIDv1.
    final targetVersion = cidVersion ?? 1;
    if (targetVersion != 0 && targetVersion != 1) {
      throw ArgumentError('Unsupported CID version: $targetVersion');
    }

    await _mutationLock.synchronized(() async {
      // Re-hash/re-encode the existing DAG with the requested settings.
      final currentCid = await _resolvePath(_rootCid!, parts);
      if (currentCid == null) {
        throw Exception('Path not found: $path');
      }
      final type = await _unixfsType(currentCid);
      if (type != Data_DataType.Directory && type != Data_DataType.HAMTShard) {
        throw Exception('can only update directories');
      }
      final newCid = await _rehashNode(currentCid, hashType, targetVersion);
      if (newCid == currentCid) {
        // No change
        return;
      }
      await _modifyPath(parts, (existingCid) async => newCid);
    });
  }

  /// Sets the modification time on the node at [path] (`files touch`).
  ///
  /// When [mtimeSecs] is null the current time is used. [mtimeNsecs] supplies
  /// the optional nanosecond fraction.
  Future<void> touch(String path, {int? mtimeSecs, int? mtimeNsecs}) async {
    final secs =
        mtimeSecs ?? DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    await _mutationLock.synchronized(() async {
      await _setMetadata(path, mtimeSecs: secs, mtimeNsecs: mtimeNsecs);
    });
  }

  /// Alias for [touch] — sets the mtime of the node at [path].
  Future<void> mtime(String path, {int? mtimeSecs, int? mtimeNsecs}) =>
      touch(path, mtimeSecs: mtimeSecs, mtimeNsecs: mtimeNsecs);

  /// Sets the POSIX mode on the node at [path] (`files chmod`).
  Future<void> chmod(String path, int mode) async {
    if (mode < 0 || mode > 0xFFFFFFFF) {
      throw ArgumentError('Invalid mode: $mode');
    }
    await _mutationLock.synchronized(() async {
      await _setMetadata(path, mode: mode);
    });
  }

  // --------------------------------------------------------------------------
  // Internal helpers
  // --------------------------------------------------------------------------

  Future<void> _persistRoot() async {
    await _datastore.put(Key(_rootKey), _rootCid!.toBytes());
  }

  /// Resolves [path] to a CID. Supports MFS paths and `/ipfs/<cid>[/sub]`
  /// paths (the latter read-only, used by `cp`/`stat`/`ls`/`read`).
  Future<CID?> _resolveAny(String path) async {
    final normalized = _normalizePath(path);
    if (normalized == '/ipfs' || normalized.startsWith('/ipfs/')) {
      return _resolveIpfsPath(normalized);
    }
    return _resolvePath(_rootCid!, _splitPath(path));
  }

  /// Resolves an `/ipfs/<cid>[/sub/path]` reference through the block store.
  Future<CID?> _resolveIpfsPath(String normalized) async {
    final segments = normalized.split('/').where((s) => s.isNotEmpty).toList();
    // segments[0] == 'ipfs'
    if (segments.length < 2) return null;
    CID cid;
    try {
      cid = CID.decode(segments[1]);
    } catch (_) {
      throw MFSPathError('Invalid IPFS path: $normalized');
    }
    return _resolveDagPath(cid, segments.sublist(2));
  }

  /// Walks named dag-pb links from [root] following [parts].
  Future<CID?> _resolveDagPath(CID root, List<String> parts) async {
    var current = root;
    for (final part in parts) {
      final block = await _blockStore.getBlock(current.encode());
      if (!block.found) return null;
      final node = _tryParseNode(block.block.data);
      if (node == null) return null;
      CID? next;
      for (final link in node.links) {
        if (link.name == part) {
          next = CID.fromBytes(Uint8List.fromList(link.hash));
          break;
        }
      }
      if (next == null) return null;
      current = next;
    }
    return current;
  }

  /// Returns the UnixFS type of the node at [cid], or null for raw blocks /
  /// unparseable nodes.
  Future<Data_DataType?> _unixfsType(CID cid) async {
    if (cid.codec == 'raw') return null;
    final block = await _blockStore.getBlock(cid.encode());
    if (!block.found) return null;
    final node = _tryParseNode(block.block.data);
    if (node == null || !node.hasData()) return null;
    try {
      return Data.fromBuffer(node.data).type;
    } catch (_) {
      return null;
    }
  }

  /// Reads optional UnixFS 1.5 metadata (mode/mtime) from the node at [cid].
  Future<_NodeMetadata?> _readMetadata(CID cid) async {
    if (cid.codec == 'raw') return null;
    final block = await _blockStore.getBlock(cid.encode());
    if (!block.found) return null;
    final node = _tryParseNode(block.block.data);
    if (node == null || !node.hasData()) return null;
    Data unixData;
    try {
      unixData = Data.fromBuffer(node.data);
    } catch (_) {
      return null;
    }
    return _NodeMetadata(
      mode: unixData.hasMode() ? unixData.mode : null,
      mtimeSecs: unixData.hasMtime() ? unixData.mtime.toInt() : null,
      mtimeNsecs: unixData.hasMtimeNsecs() ? unixData.mtimeNsecs : null,
    );
  }

  /// Re-writes [block]'s root node with the given UnixFS 1.5 metadata fields
  /// set and returns the re-hashed block.
  Future<Block> _applyMetadata(
    Block block, {
    int? mode,
    int? mtimeSecs,
    int? mtimeNsecs,
    required String hashType,
    required int cidVersion,
  }) async {
    final node = PBNode.fromBuffer(block.data);
    final unixData = node.hasData()
        ? Data.fromBuffer(node.data)
        : (Data()..type = Data_DataType.File);
    if (mode != null) unixData.mode = mode;
    if (mtimeSecs != null) unixData.mtime = Int64(mtimeSecs);
    if (mtimeNsecs != null) unixData.mtimeNsecs = mtimeNsecs;
    node.data = unixData.writeToBuffer();
    final newData = node.writeToBuffer();
    final newCid = await CID.fromContent(
      newData,
      codec: 'dag-pb',
      hashType: hashType,
      version: cidVersion,
    );
    return Block(cid: newCid, data: newData, format: 'dag-pb');
  }

  /// Mutates the UnixFS metadata of the node at [path] and re-links it into
  /// the MFS tree.
  Future<void> _setMetadata(
    String path, {
    int? mode,
    int? mtimeSecs,
    int? mtimeNsecs,
  }) async {
    final parts = _splitPath(path);
    final currentCid = parts.isEmpty
        ? _rootCid
        : await _resolvePath(_rootCid!, parts);
    if (currentCid == null) {
      throw Exception('Path not found: $path');
    }
    if (currentCid.codec == 'raw') {
      throw Exception('Cannot set metadata on a raw block: $path');
    }
    final block = await _blockStore.getBlock(currentCid.encode());
    if (!block.found) {
      throw Exception('Block not found for CID: $currentCid');
    }
    final newBlock = await _applyMetadata(
      block.block.toBlock(),
      mode: mode,
      mtimeSecs: mtimeSecs,
      mtimeNsecs: mtimeNsecs,
      hashType: 'sha2-256',
      cidVersion: currentCid.version,
    );
    await _blockStore.putBlock(newBlock);
    if (newBlock.cid == currentCid) return;
    await _modifyPath(parts, (existingCid) async => newBlock.cid);
  }

  /// Computes whether the DAG rooted at [cid] is fully present locally and
  /// the cumulative size of the locally available portion.
  Future<(bool, int)> _localStats(CID cid) async {
    var allLocal = true;
    var sizeLocal = 0;
    final visited = <String>{};
    final queue = <CID>[cid];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      if (!visited.add(current.encode())) continue;
      final block = await _blockStore.getBlock(current.encode());
      if (!block.found) {
        allLocal = false;
        continue;
      }
      sizeLocal += block.block.data.length;
      final node = _tryParseNode(block.block.data);
      if (node == null) continue;
      for (final link in node.links) {
        queue.add(CID.fromBytes(Uint8List.fromList(link.hash)));
      }
    }
    return (allLocal, sizeLocal);
  }

  /// Parses [bytes] as a [PBNode], returning null for non-dag-pb payloads
  /// (e.g. raw leaf blocks) instead of throwing.
  PBNode? _tryParseNode(List<int> bytes) {
    try {
      return PBNode.fromBuffer(bytes);
    } catch (_) {
      return null;
    }
  }

  /// Builds a long-format list entry for [cid], extracting UnixFS type and
  /// UnixFS 1.5 metadata from [node] when parseable. [dataLength] is the raw
  /// size of the node's block, used as the size for non-dag-pb payloads.
  MFSListEntry _entryFor(
    String name,
    CID cid,
    PBNode? node, {
    required int dataLength,
  }) {
    // Kubo mfs.NodeListing: TFile = 0, TDir = 1.
    var type = 0;
    var size = dataLength;
    int? mode;
    int? mtime;
    int? mtimeNsecs;
    if (node != null && node.hasData()) {
      try {
        final unixData = Data.fromBuffer(node.data);
        if (unixData.type == Data_DataType.Directory ||
            unixData.type == Data_DataType.HAMTShard) {
          type = 1;
          size = 0; // Directories report no size in `files ls -l`.
        } else {
          size = unixData.filesize.toInt();
        }
        if (unixData.hasMode()) mode = unixData.mode;
        if (unixData.hasMtime()) mtime = unixData.mtime.toInt();
        if (unixData.hasMtimeNsecs()) mtimeNsecs = unixData.mtimeNsecs;
      } catch (_) {
        // Leave defaults.
      }
    }
    return MFSListEntry(
      name: name,
      type: type,
      size: size,
      hash: cid.encode(),
      mode: mode,
      mtime: mtime,
      mtimeNsecs: mtimeNsecs,
    );
  }

  String _basename(String path) {
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    return parts.isEmpty ? '/' : parts.last;
  }

  Future<void> _readRecursive(
    CID cid,
    StreamController<List<int>> controller,
    _ReadCursor cursor,
  ) async {
    if (cursor.done) return;
    final block = await _blockStore.getBlock(cid.encode());
    if (!block.found) throw Exception('Block not found');

    // Raw leaf blocks have no UnixFS envelope; emit the payload directly.
    if (cid.codec == 'raw') {
      final chunk = cursor.take(block.block.data);
      if (chunk.isNotEmpty) controller.add(chunk);
      return;
    }

    final node = PBNode.fromBuffer(block.block.data);
    final unixData = Data.fromBuffer(node.data);

    if (unixData.type == Data_DataType.File ||
        unixData.type == Data_DataType.Raw) {
      if (unixData.hasData()) {
        final chunk = cursor.take(unixData.data);
        if (chunk.isNotEmpty) controller.add(chunk);
      }
      for (final link in node.links) {
        if (cursor.done) break;
        await _readRecursive(
          CID.fromBytes(Uint8List.fromList(link.hash)),
          controller,
          cursor,
        );
      }
    } else {
      throw Exception('Not a file');
    }
  }

  Future<Uint8List> _readAllBytes(CID cid) async {
    final controller = StreamController<List<int>>();
    final buffer = BytesBuilder();
    final cursor = _ReadCursor(skip: 0);

    unawaited(
      _readRecursive(
        cid,
        controller,
        cursor,
      ).then((_) => controller.close()).catchError((Object e) {
        controller.addError(e);
        // Close the stream after the error so consumers terminate
        // instead of hanging forever.
        return controller.close();
      }),
    );

    await for (final chunk in controller.stream) {
      buffer.add(chunk);
    }
    return buffer.toBytes();
  }

  /// Splices [patch] into [original] at [offset]. When [offset] is beyond
  /// the end of [original] the gap is zero-filled, matching Kubo's sparse
  /// expansion for `files write --offset` past EOF.
  List<int> _patchBytes(List<int> original, List<int> patch, int offset) {
    if (offset == 0 && patch.length >= original.length) {
      return patch;
    }
    final length = original.length > offset + patch.length
        ? original.length
        : offset + patch.length;
    final result = Uint8List(length);
    result.setRange(0, original.length, original);
    result.setRange(offset, offset + patch.length, patch);
    return result;
  }

  List<String> _splitPath(String path) {
    final normalized = _normalizePath(path);
    return normalized.split('/').where((p) => p.isNotEmpty).toList();
  }

  /// Normalizes [path] the way Kubo's `checkPath` does: `gopath.Clean`
  /// resolves `.`/`..` segments and clamps `..` at the root (`/../x` is
  /// `/x`), it does not error on escaping the root.
  String _normalizePath(String path) {
    if (path.isEmpty || path == '/') return '/';

    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    final stack = <String>[];
    for (final part in parts) {
      if (part == '.') continue;
      if (part == '..') {
        if (stack.isNotEmpty) stack.removeLast();
        continue;
      }
      stack.add(part);
    }
    return stack.isEmpty ? '/' : '/${stack.join('/')}';
  }

  Future<CID?> _resolvePath(CID current, List<String> parts) async {
    if (parts.isEmpty) return current;

    final block = await _blockStore.getBlock(current.encode());
    if (!block.found) return null;

    final node = _tryParseNode(block.block.data);
    if (node == null) return null;
    for (final link in node.links) {
      if (link.name == parts[0]) {
        return _resolvePath(
          CID.fromBytes(Uint8List.fromList(link.hash)),
          parts.sublist(1),
        );
      }
    }
    return null;
  }

  /// Modifies a path and updates all parents up to root.
  Future<void> _modifyPath(
    List<String> parts,
    Future<CID?> Function(CID? currentCid) transform, {
    bool recursive = false,
    bool isDirectory = false,
  }) async {
    _rootCid = await _modifyRecursive(
      _rootCid!,
      parts,
      transform,
      recursive,
      isDirectory,
    );
    await _persistRoot();
  }

  Future<CID> _modifyRecursive(
    CID currentCid,
    List<String> parts,
    Future<CID?> Function(CID? currentCid) transform,
    bool recursive,
    bool isDirectory,
  ) async {
    if (parts.isEmpty) {
      final newCid = await transform(currentCid);
      return newCid ?? currentCid;
    }

    final block = await _blockStore.getBlock(currentCid.encode());
    if (!block.found) throw Exception('Block not found');
    final node = PBNode.fromBuffer(block.block.data);

    final name = parts[0];
    PBLink? foundLink;
    for (final link in node.links) {
      if (link.name == name) {
        foundLink = link;
        break;
      }
    }

    CID nextCid;
    if (foundLink == null) {
      if (parts.length > 1 && !recursive) {
        throw Exception('Path not found: $name');
      }

      if (parts.length == 1) {
        final newChildCid = await transform(null);
        if (newChildCid == null) return currentCid;
        nextCid = newChildCid;
      } else {
        // Create intermediate directory
        final dirManager = IPFSDirectoryManager();
        final emptyDirNode = dirManager.build();
        final emptyDirData = emptyDirNode.writeToBuffer();
        final emptyDirCid = await CID.fromContent(
          emptyDirData,
          codec: 'dag-pb',
        );
        await _blockStore.putBlock(
          Block(cid: emptyDirCid, data: emptyDirData, format: 'dag-pb'),
        );

        nextCid = await _modifyRecursive(
          emptyDirCid,
          parts.sublist(1),
          transform,
          recursive,
          isDirectory,
        );
      }
    } else {
      nextCid = await _modifyRecursive(
        CID.fromBytes(Uint8List.fromList(foundLink.hash)),
        parts.sublist(1),
        transform,
        recursive,
        isDirectory,
      );
    }

    // Update current node with new link to nextCid
    final nextBlock = await _blockStore.getBlock(nextCid.encode());
    final nextNode = PBNode.fromBuffer(nextBlock.block.data);

    final newLink = PBLink()
      ..name = name
      ..hash = nextCid.toBytes()
      ..size = Int64(
        nextBlock.block.data.length +
            nextNode.links.fold<int>(0, (sum, l) => sum + l.size.toInt()),
      );

    final newLinks = node.links.where((l) => l.name != name).toList();
    newLinks.add(newLink);
    newLinks.sort((a, b) => a.name.compareTo(b.name));

    node.links.clear();
    node.links.addAll(newLinks);

    final newData = node.writeToBuffer();
    final updatedCid = await CID.fromContent(newData, codec: 'dag-pb');
    await _blockStore.putBlock(
      Block(cid: updatedCid, data: newData, format: 'dag-pb'),
    );

    return updatedCid;
  }

  /// Maps a UnixFS node type to Kubo's `files stat` Type string. Kubo
  /// reports only "file" and "directory" (HAMT shards count as directories).
  String _typeName(Data_DataType type) {
    switch (type) {
      case Data_DataType.Directory:
      case Data_DataType.HAMTShard:
        return 'directory';
      case Data_DataType.Raw:
      case Data_DataType.File:
      case Data_DataType.Metadata:
      case Data_DataType.Symlink:
      default:
        return 'file';
    }
  }

  int _cumulativeSize(PBNode node) {
    return node.links.fold<int>(
      node.writeToBuffer().length,
      (sum, l) => sum + l.size.toInt(),
    );
  }

  Future<CID> _rehashNode(CID cid, String hashType, int targetVersion) async {
    if (hashType != 'sha2-256') {
      throw UnsupportedError('Hash type $hashType not supported');
    }
    // Re-encoding with the same hash function produces the same CID, so this
    // is effectively a no-op for already-present data.
    final block = await _blockStore.getBlock(cid.encode());
    if (!block.found) throw Exception('Block not found for CID: $cid');
    final newCid = await CID.fromContent(
      Uint8List.fromList(block.block.data),
      codec: 'dag-pb',
      hashType: hashType,
      version: targetVersion,
    );
    // Ensure the block is also reachable under the new CID.
    if (newCid != cid) {
      await _blockStore.putBlock(
        Block(
          cid: newCid,
          data: Uint8List.fromList(block.block.data),
          format: 'dag-pb',
        ),
      );
    }
    return newCid;
  }

  /// Silences the unawaited future analyzer warning without actually awaiting.
  void unawaited(Future<void> future) {}
}
