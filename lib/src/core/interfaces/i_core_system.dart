// src/core/interfaces/i_core_system.dart

/// Base interface for IPFS subsystems with lifecycle management.
///
/// Provides a standard contract for starting, stopping, and monitoring
/// system components like storage, network, and protocols.
abstract class ICoreSystem {
  /// Starts this system component.
  Future<void> start();

  /// Gracefully stops this system component.
  Future<void> stop();

  /// Returns the current status and health information.
  Future<Map<String, dynamic>> getStatus();
}

