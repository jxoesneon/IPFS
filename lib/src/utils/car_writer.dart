// lib/src/utils/car_writer.dart

import 'dart:io';
import 'dart:typed_data';
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
    // Write the serialized data to a file
    // You can use dart:io for file operations
    final file = File(filePath);
    await file.writeAsBytes(carData);
  }
}
