// lib/src/utils/car_writer.dart

import 'dart:typed_data';
import 'package:dart_ipfs/src/platform/platform.dart';
import '../core/data_structures/car.dart';

/// Utility class for writing CAR files.
class CarWriter {
  /// Writes the given [CAR] object to bytes.
  static Future<Uint8List> writeCar(CAR car) async {
    // Serialize the CAR to bytes
    return car.toBytes();
  }

  /// Writes the blocks from a CAR to a file (optional).
  static Future<void> writeCarToFile(CAR car, String filePath) async {
    final carData = await writeCar(car);
    // Write the serialized data to a file via platform abstraction
    await getPlatform().writeBytes(filePath, carData);
  }
}
