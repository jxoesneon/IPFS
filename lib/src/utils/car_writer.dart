// lib/src/utils/car_writer.dart

import 'dart:async';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/car.dart' as legacy;
import 'package:dart_ipfs/src/platform/platform.dart';
import 'package:dart_ipfs/src/utils/car_reader.dart' show CarSection;

/// Utility class for writing CAR files.
///
/// This class exposes the standard `CarWriter` API from `CAR_FORMAT_SPEC.md`
/// while still delegating to the legacy `CAR` class internally. The legacy
/// static helpers (`writeCar`, `writeCarToFile`) are retained temporarily for
/// internal consumers that have not yet migrated to the new API.
class CarWriter {
  /// Creates a writer for a CAR with the given [roots].
  CarWriter({
    required this.roots,
    this.v2 = false,
    this.index = false,
  });

  /// The root CIDs of the CAR.
  final List<CID> roots;

  /// Whether to write a CAR v2 file.
  final bool v2;

  /// Whether to build an index (CAR v2 only).
  final bool index;

  final List<CarSection> _sections = [];

  /// Writes a single section.
  Future<void> write(CID cid, Uint8List block) async {
    _sections.add(CarSection(cid: cid, bytes: block));
  }

  /// Emits the complete file as bytes.
  Future<Uint8List> close() async {
    final blocks = _sections
        .map(
          (section) => Block(
            cid: section.cid,
            data: section.bytes,
            format: section.cid.codec ?? 'raw',
          ),
        )
        .toList();
    final car = legacy.CAR(
      blocks: blocks,
      header: legacy.CarHeader(
        version: v2 ? 2 : 1,
        roots: roots,
      ),
    );
    return car.toBytes();
  }

  /// Emits the complete file as a stream for large archives.
  Stream<Uint8List> closeStream() async* {
    yield await close();
  }

  /// Writes the given legacy [CAR] object to bytes.
  @Deprecated('Use the new CarWriter API instead')
  static Future<Uint8List> writeCar(legacy.CAR car) async {
    return car.toBytes();
  }

  /// Writes the blocks from a legacy CAR to a file.
  @Deprecated('Use the new CarWriter API instead')
  static Future<void> writeCarToFile(legacy.CAR car, String filePath) async {
    final carData = await writeCar(car);
    await getPlatform().writeBytes(filePath, carData);
  }
}
