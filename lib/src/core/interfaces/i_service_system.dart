// src/core/interfaces/i_service_system.dart
import 'package:dart_ipfs/src/core/interfaces/i_core_system.dart';

abstract class IServiceSystem extends ICoreSystem {
  String get serviceId;
  bool get isRunning;
}
