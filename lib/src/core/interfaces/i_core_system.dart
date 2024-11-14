// src/core/interfaces/i_core_system.dart
abstract class ICoreSystem {
  Future<void> start();
  Future<void> stop();
  Future<Map<String, dynamic>> getStatus();
}
