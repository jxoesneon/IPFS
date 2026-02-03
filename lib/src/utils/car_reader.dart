// lib/src/utils/car_reader.dart

import 'dart:typed_data';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/car.dart';

/// Utility class for reading CAR files.
class CarReader {
  /// Reads a CAR file from the given byte data and returns a [CAR] object.
  static Future<CAR> readCar(Uint8List carData) async {
    // Deserialize the CAR from bytes
    final car = CAR.fromBytes(carData);

    // Perform any additional processing or validation if necessary
    // For example, you might want to verify the integrity of the blocks

    return car;
  }

  /// Extracts blocks from a CAR file and returns them as a list.
  static Future<List<Block>> extractBlocks(Uint8List carData) async {
    final car = await readCar(carData);
    return car.blocks;
  }
}

