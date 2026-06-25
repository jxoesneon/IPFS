// lib/src/utils/car_reader.dart

import 'dart:async';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/car.dart' as legacy;

/// A single CID/block section from a CAR archive.
///
/// This is the standard shape defined in `CAR_FORMAT_SPEC.md`. During the
/// migration to the standard `CarReader`/`CarWriter` API it is a wrapper over
/// the legacy block model.
class CarSection {
  /// Creates a [CarSection] with the given [cid] and [bytes].
  CarSection({required this.cid, required this.bytes});

  /// The CID of the section.
  final CID cid;

  /// The raw block bytes of the section.
  final Uint8List bytes;
}

/// Utility class for reading CAR files.
///
/// This class exposes the standard `CarReader` API from `CAR_FORMAT_SPEC.md`
/// while still delegating to the legacy `CAR` class internally. The legacy
/// static helpers (`readCar`, `extractBlocks`) are retained temporarily for
/// internal consumers that have not yet migrated to the new API.
class CarReader {
  /// Parses a CAR from the given byte data.
  CarReader.fromBytes(Uint8List bytes)
      : _bytes = bytes,
        _stream = null,
        _car = legacy.CAR.fromBytes(bytes);

  /// Parses a CAR from a stream of byte chunks.
  ///
  /// **Note:** Streamed construction is not yet implemented in this
  /// transitional wrapper. The constructor accepts the standard signature but
  /// will throw [UnimplementedError] until the standard streaming parser lands.
  CarReader.fromStream(Stream<Uint8List> stream)
      : _bytes = null,
        _stream = stream,
        _car = null;

  final Uint8List? _bytes;
  final Stream<Uint8List>? _stream;
  legacy.CAR? _car;

  Future<legacy.CAR> _load() async {
    if (_car != null) return _car!;
    if (_stream != null) {
      throw UnimplementedError(
        'Streaming CarReader is not yet implemented; use CarReader.fromBytes',
      );
    }
    throw StateError('CarReader has no data source');
  }

  /// The CAR header.
  Future<legacy.CarHeader> get header async => (await _load()).header;

  /// Yields each section in file order.
  Stream<CarSection> sections() async* {
    for (final block in (await _load()).blocks) {
      yield CarSection(
        cid: block.cid,
        bytes: Uint8List.fromList(block.data),
      );
    }
  }

  /// Returns the byte offset of the section containing [cid], or `null` if not
  /// present.
  ///
  /// **Note:** Index-backed lookup is not yet implemented in this
  /// transitional wrapper.
  Future<int?> findCID(CID cid) async => null;

  /// Reads a legacy CAR from the given byte data.
  @Deprecated('Use CarReader.fromBytes(...).sections() during migration')
  static Future<legacy.CAR> readCar(Uint8List carData) async {
    return legacy.CAR.fromBytes(carData);
  }

  /// Extracts blocks from a legacy CAR.
  @Deprecated('Use CarReader.fromBytes(...).sections() during migration')
  static Future<List<Block>> extractBlocks(Uint8List carData) async {
    final car = await readCar(carData);
    return car.blocks;
  }
}
