import 'dart:typed_data';
import 'package:dart_ipfs/src/core/interfaces/block_cloneable.dart';
import 'package:dart_ipfs/src/core/interfaces/block_data.dart';
import 'package:dart_ipfs/src/core/cid.dart';

class Block with BlockCloneable<Block> implements BlockData {
  @override
  final Uint8List data;

  @override
  CID get cid => _cid;

  final CID _cid;

  const Block({
    required this.data,
    required CID cid,
  }) : _cid = cid;

  @override
  Block clone() => Block(
        data: Uint8List.fromList(data),
        cid: cid,
      );

  @override
  Block copyWith(void Function(Block) updates) {
    final clone = Block(
      data: data,
      cid: cid,
    );
    updates(clone);
    return clone;
  }

  @override
  Uint8List toBytes() => data;

  @override
  int get size => data.length;
}
