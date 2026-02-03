// src/core/interfaces/i_service_system.dart
import 'package:dart_ipfs/src/core/interfaces/i_core_system.dart';

/// Interface for service-layer systems with identity and status.
///
/// Extends [ICoreSystem] with service identification and running state.
abstract class IServiceSystem extends ICoreSystem {
  /// Unique identifier for this service.
  String get serviceId;

  /// Whether the service is currently running.
  bool get isRunning;
}
