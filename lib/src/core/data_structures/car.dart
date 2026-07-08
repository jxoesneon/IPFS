// lib/src/core/data_structures/car.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/ipld/codecs/standard_codecs.dart';
import 'package:dart_ipfs/src/proto/generated/core/cid.pb.dart'
    show IPFSCIDProto, IPFSCIDVersion;
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:fixnum/fixnum.dart' show Int64;

// ---------------------------------------------------------------------------
// CAR format exceptions
// ---------------------------------------------------------------------------

/// Base class for CAR parsing errors.
class CarException implements Exception {
  /// Creates a [CarException] with the given [message].
  CarException(this.message);

  /// Human-readable error description.
  final String message;

  @override
  String toString() => 'CarException: $message';
}

/// Thrown when a CAR header is malformed or violates the CAR specification.
class CarHeaderException extends CarException {
  /// Creates a [CarHeaderException] with the given [message].
  CarHeaderException(super.message);
}

/// Thrown when a CAR section is malformed or truncated.
class CarSectionException extends CarException {
  /// Creates a [CarSectionException] with the given [message].
  CarSectionException(super.message);
}

/// Thrown when a CAR v2 pragma or header is invalid.
class CarV2Exception extends CarException {
  /// Creates a [CarV2Exception] with the given [message].
  CarV2Exception(super.message);
}

/// Thrown when a CAR index is malformed or inconsistent with the data payload.
class CarIndexException extends CarException {
  /// Creates a [CarIndexException] with the given [message].
  CarIndexException(super.message);
}

// ---------------------------------------------------------------------------
// CAR v1/v2 data structures
// ---------------------------------------------------------------------------

/// Immutable CAR file header.
///
/// Contains the CAR format [version] (1 or 2) and the list of root [CIDs].
/// The header is encoded as a DAG-CBOR map with the canonical key ordering
/// `{ "roots": [...], "version": 1 }`.
class CarHeader {
  /// Creates a [CarHeader] with the given [version] and [roots].
  CarHeader({required this.version, required this.roots});

  /// The CAR format version (1 or 2).
  final int version;

  /// The root CIDs of the archive.
  final List<CID> roots;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CarHeader) return false;
    if (version != other.version) return false;
    if (roots.length != other.roots.length) return false;
    for (var i = 0; i < roots.length; i++) {
      if (roots[i] != other.roots[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(version, Object.hashAll(roots));

  @override
  String toString() => 'CarHeader(version: $version, roots: $roots)';

  /// Encodes this header to DAG-CBOR bytes.
  Future<Uint8List> _toBytes() async {
    if (version != 1 && version != 2) {
      throw CarHeaderException('Unsupported CAR header version: $version');
    }
    if (roots.isEmpty) {
      throw CarHeaderException('CAR header must contain at least one root');
    }

    final rootsList = IPLDList()
      ..values.addAll(roots.map((cid) {
        final link = IPLDLink(
          version: cid.version,
          codec: cid.codec ?? 'raw',
          multihash: cid.multihash.toBytes(),
        );
        return IPLDNode(kind: Kind.LINK, linkValue: link);
      }));

    final versionNode = IPLDNode(
      kind: Kind.INTEGER,
      intValue: Int64(version),
    );

    final map = IPLDMap()
      ..entries.add(
        MapEntry()
          ..key = 'roots'
          ..value = (IPLDNode(kind: Kind.LIST, listValue: rootsList)),
      )
      ..entries.add(
        MapEntry()
          ..key = 'version'
          ..value = versionNode,
      );

    final headerNode = IPLDNode(kind: Kind.MAP, mapValue: map);
    return await DagCborCodec().encode(headerNode);
  }

  /// Decodes a [CarHeader] from DAG-CBOR bytes.
  static Future<CarHeader> _fromBytes(Uint8List bytes) async {
    final node = await DagCborCodec().decode(bytes);
    if (node.kind != Kind.MAP) {
      throw CarHeaderException('CAR header must be a DAG-CBOR map');
    }

    final map = node.mapValue;
    final rootsEntry = map.entries.firstWhere(
      (e) => e.key == 'roots',
      orElse: () => throw CarHeaderException('CAR header missing "roots"'),
    );
    if (rootsEntry.value.kind != Kind.LIST) {
      throw CarHeaderException('CAR header "roots" must be a list');
    }

    final roots = rootsEntry.value.listValue.values.map((cidNode) {
      if (cidNode.kind != Kind.LINK) {
        throw CarHeaderException('CAR header roots must be CID links');
      }
      final link = cidNode.linkValue;
      final proto = IPFSCIDProto()
        ..version = link.version == 0
            ? IPFSCIDVersion.IPFS_CID_VERSION_0
            : IPFSCIDVersion.IPFS_CID_VERSION_1
        ..multihash = link.multihash
        ..codec = link.codec.isNotEmpty
            ? link.codec
            : (link.version == 0 ? 'dag-pb' : 'raw');
      return CID.fromProto(proto);
    }).toList();

    final versionEntry = map.entries.firstWhere(
      (e) => e.key == 'version',
      orElse: () => throw CarHeaderException('CAR header missing "version"'),
    );
    if (versionEntry.value.kind != Kind.INTEGER) {
      throw CarHeaderException('CAR header "version" must be an integer');
    }
    final version = versionEntry.value.intValue.toInt();

    return CarHeader(version: version, roots: roots);
  }
}

/// A single CID/block section within a CAR archive.
class CarSection {
  /// Creates a [CarSection] with the given [cid] and [bytes].
  CarSection({required this.cid, required this.bytes});

  /// The CID of this section.
  final CID cid;

  /// The raw block bytes of this section.
  final Uint8List bytes;

  /// The on-wire size of this section, including the varint length prefix.
  int get serializedSize {
    final cidBytes = cid.toBytes();
    final payloadLength = cidBytes.length + bytes.length;
    return _varintLength(payloadLength) + payloadLength;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CarSection) return false;
    return cid == other.cid && _bytesEqual(bytes, other.bytes);
  }

  @override
  int get hashCode => Object.hash(cid, Object.hashAll(bytes));

  @override
  String toString() => 'CarSection(cid: $cid, bytes: ${bytes.length})';

  bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

// ---------------------------------------------------------------------------
// CAR index builder
// ---------------------------------------------------------------------------

/// Builder for CAR v2 index payloads.
///
/// Collects `(multihash digest, section offset)` pairs and emits a sorted index
/// payload in either [IndexSorted] (`0x0400`) or [MultihashIndexSorted]
/// (`0x0401`) format.
class IndexBuilder {
  /// Creates an [IndexBuilder] with the given [multihashSorted] format flag.
  ///
  /// When [multihashSorted] is `true` the index is emitted as
  /// `MultihashIndexSorted` (`0x0401`); otherwise it is emitted as
  /// `IndexSorted` (`0x0400`).
  IndexBuilder({this.multihashSorted = false});

  /// Whether to build a `MultihashIndexSorted` index.
  final bool multihashSorted;

  final List<_IndexEntry> _entries = [];

  /// Records a new section at [offset] with the given [cid].
  void add(CID cid, int offset) {
    _entries.add(_IndexEntry(cid, offset));
  }

  /// Builds and returns the sorted index payload bytes.
  ///
  /// The payload starts with the 4-byte little-endian format code, followed by
  /// sorted records. For `IndexSorted` each record is
  /// `[varint digest length | digest bytes | varint offset]`. For
  /// `MultihashIndexSorted` each record is prefixed with the multihash code
  /// as `[varint multihash code | varint digest length | digest bytes | varint offset]`.
  Uint8List build() {
    final sorted = List<_IndexEntry>.from(_entries)
      ..sort((a, b) => _compareBytes(a.digest, b.digest));

    final builder = BytesBuilder();
    final formatCode = multihashSorted ? 0x0401 : 0x0400;
    builder.add(_encodeUint32le(formatCode));

    for (final entry in sorted) {
      final digest = entry.digest;
      if (multihashSorted) {
        builder.add(_encodeVarint(entry.multihashCode));
      }
      builder.add(_encodeVarint(digest.length));
      builder.add(digest);
      builder.add(_encodeVarint(entry.offset));
    }

    return builder.toBytes();
  }

  int _compareBytes(Uint8List a, Uint8List b) {
    final len = a.length < b.length ? a.length : b.length;
    for (var i = 0; i < len; i++) {
      final diff = a[i] - b[i];
      if (diff != 0) return diff;
    }
    return a.length - b.length;
  }
}

class _IndexEntry {
  _IndexEntry(this.cid, this.offset);

  final CID cid;
  final int offset;

  Uint8List get digest => Uint8List.fromList(cid.multihash.digest);

  int get multihashCode => cid.multihash.code;
}

// ---------------------------------------------------------------------------
// CAR reader
// ---------------------------------------------------------------------------

/// Streaming/iterable reader for CAR v1 and v2 archives.
class CarReader {
  /// Parses a CAR archive from the given byte data.
  CarReader.fromBytes(Uint8List bytes)
      : _bytes = bytes,
        _stream = null;

  /// Parses a CAR archive from a stream of byte chunks.
  ///
  /// **Note:** The current implementation accumulates incoming chunks into a
  /// single buffer before parsing. This satisfies the standard API while
  /// keeping the parser simple; future work can replace the accumulator with a
  /// true incremental parser.
  CarReader.fromStream(Stream<Uint8List> stream)
      : _bytes = null,
        _stream = stream;

  final Uint8List? _bytes;
  final Stream<Uint8List>? _stream;
  CarHeader? _header;
  Uint8List? _v1Payload;
  Uint8List? _indexPayload;
  _CarV2Header? _v2Header;

  /// The decoded CAR header.
  Future<CarHeader> get header async => await _loadHeader();

  /// Returns a stream that yields each [CarSection] in file order.
  Stream<CarSection> sections() async* {
    final payload = await _loadV1Payload();
    var offset = 0;

    final (varintLen, headerSize) = _readVarint(payload, 0);
    offset += varintLen;
    final headerBytes = payload.sublist(offset, offset + headerSize);
    offset += headerSize;
    // Ensure header can be parsed (validates DAG-CBOR).
    await CarHeader._fromBytes(headerBytes);

    final seenCids = <String>{};

    while (offset < payload.length) {
      final (varintLen, sectionLen) = _readVarint(payload, offset);
      offset += varintLen;
      if (offset + sectionLen > payload.length) {
        throw CarSectionException(
          'Truncated CAR section at offset $offset: '
          'declared $sectionLen bytes, ${payload.length - offset} available',
        );
      }

      final (cid, cidLen) = _parseCid(payload, offset);
      final blockOffset = offset + cidLen;
      final blockLen = sectionLen - cidLen;
      if (blockLen < 0) {
        throw CarSectionException(
          'CAR section length $sectionLen is smaller than CID length $cidLen',
        );
      }
      final blockBytes = payload.sublist(blockOffset, blockOffset + blockLen);

      yield CarSection(cid: cid, bytes: blockBytes);
      seenCids.add(cid.encode());

      offset += sectionLen;
    }

    // Validate that every root appears in the data section.
    final hdr = await _loadHeader();
    for (final root in hdr.roots) {
      if (!seenCids.contains(root.encode())) {
        throw CarHeaderException(
          'Root CID ${root.encode()} is missing from the data section',
        );
      }
    }
  }

  /// Returns the byte offset of the section containing [cid], or `null` if not
  /// present.
  ///
  /// For CAR v1 and CAR v2 the returned offset is relative to the start of the
  /// CAR v1 data payload. For CAR v2 the index is used when available; otherwise
  /// a streaming scan is performed.
  Future<int?> findCID(CID cid) async {
    // If an index is present, use it.
    final index = await _loadIndex();
    if (index != null) {
      final digest = Uint8List.fromList(cid.multihash.digest);
      final match = index.firstWhere(
        (e) => _bytesEqual(e.digest, digest),
        orElse: () => _IndexEntry(cid, -1),
      );
      if (match.offset >= 0) return match.offset;
      return null;
    }

    // Fallback: linear scan.
    var offset = 0;
    final payload = await _loadV1Payload();

    final (varintLen, headerSize) = _readVarint(payload, 0);
    offset += varintLen;
    // Skip the header bytes; the linear scan only needs the section CIDs.
    offset += headerSize;

    while (offset < payload.length) {
      final (varintLen, sectionLen) = _readVarint(payload, offset);
      offset += varintLen;
      final (sectionCid, cidLen) = _parseCid(payload, offset);
      if (sectionCid == cid) return offset;
      offset += sectionLen;
    }

    return null;
  }

  Future<CarHeader> _loadHeader() async {
    if (_header != null) return _header!;
    final payload = await _loadV1Payload();
    final (headerLen, headerSize) = _readVarint(payload, 0);
    if (headerLen + headerSize > payload.length) {
      throw CarHeaderException('Truncated CAR header varint');
    }
    final headerBytes = payload.sublist(headerLen, headerLen + headerSize);
    _header = await CarHeader._fromBytes(headerBytes);
    return _header!;
  }

  Future<Uint8List> _loadV1Payload() async {
    if (_v1Payload != null) return _v1Payload!;

    final bytes = await _loadBytes();
    if (bytes.isEmpty) {
      throw CarHeaderException('Empty CAR input');
    }

    // CAR v2 pragma check.
    if (bytes.length >= 11 && bytes[0] == 0x0a) {
      final pragma = bytes.sublist(0, 11);
      if (!_bytesEqual(pragma, _carV2Pragma)) {
        throw CarV2Exception('Invalid CAR v2 pragma');
      }
      if (bytes.length < 51) {
        throw CarV2Exception('CAR v2 header truncated');
      }
      _v2Header = _parseV2Header(bytes.sublist(11, 51));
      _v1Payload = bytes.sublist(
        _v2Header!.dataOffset,
        _v2Header!.dataOffset + _v2Header!.dataSize,
      );
      if (_v2Header!.indexOffset != 0) {
        _indexPayload = bytes.sublist(_v2Header!.indexOffset);
      }
      return _v1Payload!;
    }

    // Treat as CAR v1.
    _v1Payload = bytes;
    return _v1Payload!;
  }

  Future<List<_IndexEntry>?> _loadIndex() async {
    if (_indexPayload == null) return null;
    if (_indexPayload!.length < 4) {
      throw CarIndexException('CAR v2 index payload too short');
    }
    final formatCode = _readUint32le(_indexPayload!, 0);
    if (formatCode != 0x0400 && formatCode != 0x0401) {
      throw CarIndexException('Unknown CAR v2 index format code: $formatCode');
    }
    final multihashSorted = formatCode == 0x0401;

    final entries = <_IndexEntry>[];
    var offset = 4;
    while (offset < _indexPayload!.length) {
      int multihashCode;
      if (multihashSorted) {
        final (mhLen, mhCode) = _readVarint(_indexPayload!, offset);
        offset += mhLen;
        multihashCode = mhCode;
      } else {
        multihashCode = 0;
      }

      final (digestLenLen, digestLen) = _readVarint(_indexPayload!, offset);
      offset += digestLenLen;
      if (offset + digestLen > _indexPayload!.length) {
        throw CarIndexException('CAR v2 index truncated while reading digest');
      }
      final digest = _indexPayload!.sublist(offset, offset + digestLen);
      offset += digestLen;

      final (offsetLenLen, sectionOffset) = _readVarint(_indexPayload!, offset);
      offset += offsetLenLen;

      entries.add(
        _IndexedEntry(digest, sectionOffset, multihashCode),
      );
    }

    return entries;
  }

  Future<Uint8List> _loadBytes() async {
    if (_bytes != null) return _bytes;
    final completer = Completer<Uint8List>();
    final builder = BytesBuilder();
    _stream!.listen(
      builder.add,
      onError: completer.completeError,
      onDone: () => completer.complete(builder.toBytes()),
      cancelOnError: true,
    );
    return completer.future;
  }

  _CarV2Header _parseV2Header(Uint8List bytes) {
    if (bytes.length != 40) {
      throw CarV2Exception('CAR v2 header must be exactly 40 bytes');
    }
    // Characteristics bitfield: all bits must be zero for v2.0.
    for (var i = 0; i < 16; i++) {
      if (bytes[i] != 0) {
        throw CarV2Exception('CAR v2 characteristics must be zero for v2.0');
      }
    }
    return _CarV2Header(
      characteristics: bytes.sublist(0, 16),
      dataOffset: _readUint64le(bytes, 16),
      dataSize: _readUint64le(bytes, 24),
      indexOffset: _readUint64le(bytes, 32),
    );
  }

  static (CID, int) _parseCid(Uint8List bytes, int offset) {
    if (offset >= bytes.length) {
      throw CarSectionException('Not enough bytes to parse CID');
    }
    // Find the CID boundary by parsing it.
    try {
      final cid = CID.fromBytes(bytes.sublist(offset));
      return (cid, cid.toBytes().length);
    } catch (e) {
      throw CarSectionException('Failed to parse CID: $e');
    }
  }
}

class _CarV2Header {
  _CarV2Header({
    required this.characteristics,
    required this.dataOffset,
    required this.dataSize,
    required this.indexOffset,
  });

  final Uint8List characteristics;
  final int dataOffset;
  final int dataSize;
  final int indexOffset;
}

class _IndexedEntry implements _IndexEntry {
  _IndexedEntry(this.digest, this.offset, this.multihashCode);

  @override
  final Uint8List digest;
  @override
  final int offset;
  @override
  final int multihashCode;

  @override
  CID get cid => throw UnsupportedError('Index entry does not carry a CID');
}

// ---------------------------------------------------------------------------
// CAR writer
// ---------------------------------------------------------------------------

/// Append-only writer for CAR v1 and v2 archives.
class CarWriter {
  /// Creates a writer for a CAR archive with the given [roots].
  ///
  /// Set [v2] to `true` to wrap the archive in a CAR v2 envelope.
  /// Set [index] to `true` to build an index (CAR v2 only).
  CarWriter({
    required this.roots,
    this.v2 = false,
    this.index = false,
    this.multihashIndex = false,
    this.maxBlockSize = 32 * 1024 * 1024,
  }) {
    if (index && !v2) {
      throw ArgumentError('CAR index is only supported for CAR v2');
    }
  }

  /// The root CIDs of the CAR.
  final List<CID> roots;

  /// Whether to write a CAR v2 file.
  final bool v2;

  /// Whether to build an index (CAR v2 only).
  final bool index;

  /// Whether the index should be `MultihashIndexSorted` (`0x0401`) instead of
  /// `IndexSorted` (`0x0400`).
  final bool multihashIndex;

  /// Maximum allowed block size in bytes.
  final int maxBlockSize;

  final List<_PendingSection> _pending = [];

  /// Writes a single section.
  ///
  /// The [cid] and [block] bytes are buffered until [close] or [closeStream]
  /// is called.
  Future<void> write(CID cid, Uint8List block) async {
    if (block.length > maxBlockSize) {
      throw CarSectionException(
        'Block size ${block.length} exceeds maximum $maxBlockSize',
      );
    }
    _pending.add(_PendingSection(cid, block));
  }

  /// Emits the complete file as bytes.
  Future<Uint8List> close() async {
    final builder = BytesBuilder();
    await for (final chunk in closeStream()) {
      builder.add(chunk);
    }
    return builder.toBytes();
  }

  /// Emits the complete file as a stream of byte chunks.
  ///
  /// For CAR v2 with [index] the entire payload is still materialised in
  /// memory to build the index; the data is yielded as a stream for API
  /// consistency.
  Stream<Uint8List> closeStream() async* {
    if (roots.isEmpty) {
      throw CarHeaderException('CAR writer requires at least one root');
    }

    // Validate that every root is present in the data section.
    final rootSet = roots.map((r) => r.encode()).toSet();
    final writtenCids = _pending.map((s) => s.cid.encode()).toSet();
    for (final root in rootSet) {
      if (!writtenCids.contains(root)) {
        throw CarHeaderException(
          'Root CID $root must be written as a section',
        );
      }
    }

    // Build the CAR v1 payload first so we can compute offsets and index.
    final v1Payload = await _buildV1Payload();

    if (v2) {
      // Pragma + CAR v2 header + data payload.
      const pragmaSize = 11;
      const v2HeaderSize = 40;
      final dataOffset = pragmaSize + v2HeaderSize;
      final dataSize = v1Payload.length;

      var indexOffset = 0;
      Uint8List? indexBytes;
      if (index) {
        indexBytes = _buildIndex(v1Payload);
        indexOffset = dataOffset + dataSize;
      }

      yield _carV2Pragma;
      yield _buildV2Header(dataOffset, dataSize, indexOffset);
      yield v1Payload;
      if (indexBytes != null) {
        yield indexBytes;
      }
    } else {
      yield v1Payload;
    }
  }

  Future<Uint8List> _buildV1Payload() async {
    final builder = BytesBuilder();
    final header = CarHeader(version: 1, roots: roots);
    final headerBytes = await header._toBytes();
    builder.add(_encodeVarint(headerBytes.length));
    builder.add(headerBytes);

    final indexBuilder = index ? IndexBuilder(multihashSorted: multihashIndex) : null;
    var offset = builder.length;

    for (final section in _pending) {
      final cidBytes = section.cid.toBytes();
      final sectionLen = cidBytes.length + section.bytes.length;
      builder.add(_encodeVarint(sectionLen));
      builder.add(cidBytes);
      builder.add(section.bytes);
      indexBuilder?.add(section.cid, offset);
      offset += _varintLength(sectionLen) + sectionLen;
    }

    return builder.toBytes();
  }

  Uint8List _buildIndex(Uint8List v1Payload) {
    // Re-parse v1 payload to collect exact offsets. The offset tracked while
    // writing already matches the v1 payload, but re-parsing ensures correctness.
    final indexBuilder = IndexBuilder(multihashSorted: multihashIndex);
    var offset = 0;
    final (headerLen, headerSize) = _readVarint(v1Payload, 0);
    offset += headerLen + headerSize;

    while (offset < v1Payload.length) {
      final (varintLen, sectionLen) = _readVarint(v1Payload, offset);
      offset += varintLen;
      final (cid, cidLen) = CarReader._parseCid(v1Payload, offset);
      indexBuilder.add(cid, offset);
      offset += sectionLen;
    }

    return indexBuilder.build();
  }

  Uint8List _buildV2Header(int dataOffset, int dataSize, int indexOffset) {
    final header = BytesBuilder();
    // 16-byte characteristics bitfield (all zeros for v2.0).
    header.add(Uint8List(16));
    header.add(_encodeUint64le(dataOffset));
    header.add(_encodeUint64le(dataSize));
    header.add(_encodeUint64le(indexOffset));
    return header.toBytes();
  }
}

class _PendingSection {
  _PendingSection(this.cid, this.bytes);

  final CID cid;
  final Uint8List bytes;
}

// ---------------------------------------------------------------------------
// Varint / fixed-width helpers
// ---------------------------------------------------------------------------

Uint8List _encodeVarint(int value) {
  if (value < 0) throw ArgumentError('Varint must be non-negative');
  final bytes = <int>[];
  while (value >= 0x80) {
    bytes.add((value & 0x7f) | 0x80);
    value >>= 7;
  }
  bytes.add(value & 0x7f);
  return Uint8List.fromList(bytes);
}

int _varintLength(int value) {
  var length = 0;
  do {
    length++;
    value >>= 7;
  } while (value > 0);
  return length;
}

(int, int) _readVarint(Uint8List bytes, int offset) {
  var value = 0;
  var shift = 0;
  for (var i = 0; i < 10; i++) {
    if (offset + i >= bytes.length) {
      throw CarSectionException('Truncated varint at offset $offset');
    }
    final b = bytes[offset + i];
    value |= (b & 0x7f) << shift;
    if ((b & 0x80) == 0) {
      return (i + 1, value);
    }
    shift += 7;
  }
  throw CarSectionException('Varint too long at offset $offset');
}

Uint8List _encodeUint32le(int value) {
  final bytes = Uint8List(4);
  bytes[0] = value & 0xff;
  bytes[1] = (value >> 8) & 0xff;
  bytes[2] = (value >> 16) & 0xff;
  bytes[3] = (value >> 24) & 0xff;
  return bytes;
}

int _readUint32le(Uint8List bytes, int offset) {
  return bytes[offset] |
      (bytes[offset + 1] << 8) |
      (bytes[offset + 2] << 16) |
      (bytes[offset + 3] << 24);
}

Uint8List _encodeUint64le(int value) {
  final bytes = Uint8List(8);
  for (var i = 0; i < 8; i++) {
    bytes[i] = (value >> (i * 8)) & 0xff;
  }
  return bytes;
}

int _readUint64le(Uint8List bytes, int offset) {
  var value = 0;
  for (var i = 0; i < 8; i++) {
    value |= bytes[offset + i] << (i * 8);
  }
  return value;
}

bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

// ---------------------------------------------------------------------------
// CAR v2 constants
// ---------------------------------------------------------------------------

final _carV2Pragma = Uint8List.fromList(
  [0x0a, 0xa1, 0x67, 0x76, 0x65, 0x72, 0x73, 0x69, 0x6f, 0x6e, 0x02],
);
