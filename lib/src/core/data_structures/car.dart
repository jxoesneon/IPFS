import 'dart:typed_data';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:fixnum/fixnum.dart' show Int64;
import 'package:dart_ipfs/src/proto/generated/core/car.pb.dart' as proto;
import 'package:protobuf/well_known_types/google/protobuf/any.pb.dart';
// lib/src/core/data_structures/car.dart

/// Represents a Content Addressable Archive (CAR) with v1 and v2 support.
class CAR {
  final List<Block> blocks;
  final CarHeader header;
  final CarIndex? index;
  final int version;

  CAR({
    required this.blocks,
    required this.header,
    this.index,
    this.version = 2,
  });

  /// Creates a CARv2 with index
  factory CAR.v2WithIndex(List<Block> blocks) {
    final index = CarIndex.generate(blocks);
    final header = CarHeader(
      version: 2,
      characteristics: ['index-sorted', 'content-addressed'],
      roots: blocks.isNotEmpty ? [blocks.first.cid] : [],
    );

    return CAR(blocks: blocks, header: header, index: index, version: 2);
  }

  /// Serializes the CAR to bytes for storage or transmission.
  Uint8List toBytes() {
    final carProto = proto.CarProto()
      ..version = version
      ..characteristics.addAll(header.characteristics)
      ..pragma.addAll(
        header.pragma.map(
          (k, v) => MapEntry(k, Any()..value = v.toString().codeUnits),
        ),
      )
      ..blocks.addAll(blocks.map((b) => b.toProto()));

    if (index != null) {
      carProto.index = index!.toProto();
    }

    return carProto.writeToBuffer();
  }

  /// Selectively loads blocks based on CIDs
  Future<CAR> loadSelected(List<String> cids) async {
    if (index == null) {
      throw UnsupportedError('Selective loading requires an index');
    }

    final selectedBlocks = blocks
        .where((block) => cids.contains(block.cid.toString()))
        .toList();

    return CAR(
      blocks: selectedBlocks,
      header: header,
      index: index,
      version: version,
    );
  }

  /// Gets block offset information from index
  int? getBlockOffset(String cid) {
    return index?.getOffset(cid);
  }

  /// Creates a CAR from its byte representation
  static CAR fromBytes(Uint8List bytes) {
    final carProto = proto.CarProto.fromBuffer(bytes);

    final blocks = carProto.blocks
        .map((blockProto) => Block.fromProto(blockProto))
        .toList();

    final header = CarHeader(
      version: carProto.header.version,
      characteristics: carProto.header.characteristics,
      roots: carProto.header.roots.map((r) => CID.fromProto(r)).toList(),
      pragma: Map.fromEntries(
        carProto.header.pragma.entries.map(
          (e) => MapEntry(e.key, String.fromCharCodes(e.value.value)),
        ),
      ),
    );

    CarIndex? index;
    if (carProto.hasIndex()) {
      index = CarIndex();
      for (var entry in carProto.index.entries) {
        index.addEntry(entry.cid, entry.offset.toInt(), entry.length.toInt());
      }
    }

    return CAR(
      blocks: blocks,
      header: header,
      index: index,
      version: carProto.version,
    );
  }
}

/// Represents a CAR file header
class CarHeader {
  final int version;
  final List<String> characteristics;
  final List<CID> roots;
  final Map<String, dynamic> pragma;

  CarHeader({
    required this.version,
    this.characteristics = const [],
    this.roots = const [],
    this.pragma = const {},
  });

  proto.CarHeader toProto() {
    return proto.CarHeader()
      ..version = version
      ..characteristics.addAll(characteristics)
      ..roots.addAll(roots.map((r) => r.toProto()))
      ..pragma.addAll(
        pragma.map(
          (k, v) => MapEntry(k, Any()..value = v.toString().codeUnits),
        ),
      );
  }
}

/// Represents a CAR file index for fast block lookup
class CarIndex {
  final Map<String, int> _offsets = {};
  final Map<String, int> _lengths = {};

  void addEntry(String cid, int offset, int length) {
    _offsets[cid] = offset;
    _lengths[cid] = length;
  }

  int? getOffset(String cid) => _offsets[cid];
  int? getLength(String cid) => _lengths[cid];

  /// Generates an index from a list of blocks
  static CarIndex generate(List<Block> blocks) {
    final index = CarIndex();
    var currentOffset = 0;

    for (var block in blocks) {
      final cid = block.cid.toString();
      final length = block.size;
      index.addEntry(cid, currentOffset, length);
      currentOffset += length;
    }

    return index;
  }

  proto.CarIndex toProto() {
    final pbIndex = proto.CarIndex();
    _offsets.forEach((cid, offset) {
      pbIndex.entries.add(
        proto.IndexEntry()
          ..cid = cid
          ..offset = Int64(offset)
          ..length = Int64(_lengths[cid]!),
      );
    });
    return pbIndex;
  }
}
