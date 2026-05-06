// src/core/interfaces/i_lifecycle.dart
/// Interface for services that require explicit startup and shutdown.
abstract class ILifecycle {
  /// Starts the service.
  Future<void> start();

  /// Stops the service.
  Future<void> stop();
}
