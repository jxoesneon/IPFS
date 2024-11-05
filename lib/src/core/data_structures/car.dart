import 'dart:typed_data';
import '../data_structures/cid.dart';
import '../data_structures/block.dart';
import 'package:fixnum/fixnum.dart' show Int64;
import '../../proto/generated/core/car.pb.dart' as proto;
import '../../proto/generated/google/protobuf/any.pb.dart';
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
      ..pragma.addAll(header.pragma);

    if (version == 2 && index != null) {
      carProto.index = index!.toProto();
    }

    for (var block in blocks) {
      carProto.blocks.add(block.toProto());
    }

    return carProto.writeToBuffer();
  }

  /// Selectively loads blocks based on CIDs
  Future<CAR> loadSelected(List<String> cids) async {
    if (index == null) {
      throw UnsupportedError('Selective loading requires an index');
    }

    final selectedBlocks = blocks.where(
      (block) => cids.contains(block.cid.encode())
    ).toList();

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
}

/// Represents a CAR file header
class CarHeader {
  final int version;
  final List<String> characteristics;
  final List<CID> roots;
  final Map<String, Any> pragma;

  CarHeader({
    required this.version,
    this.characteristics = const [],
    this.roots = const [],
    this.pragma = const {},
  });
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
      final cid = block.cid.encode();
      final length = block.size();
      index.addEntry(cid, currentOffset, length);
      currentOffset += length;
    }

    return index;
  }

  proto.CarIndex toProto() {
    final pbIndex = proto.CarIndex();
    _offsets.forEach((cid, offset) {
      pbIndex.entries.add(proto.IndexEntry()
        ..cid = cid
        ..offset = Int64(offset)
        ..length = Int64(_lengths[cid]!));
    });
    return pbIndex;
  }
}
