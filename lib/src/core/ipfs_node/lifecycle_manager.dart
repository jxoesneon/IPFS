// src/core/ipfs_node/lifecycle_manager.dart
import 'dart:async';

import '../../utils/logger.dart';
import '../interfaces/i_lifecycle.dart';

/// Orchestrates the startup and shutdown sequence of all node services.
class LifecycleManager {
  /// Initializes a new LifecycleManager.
  LifecycleManager() : _logger = Logger('LifecycleManager');

  final List<ILifecycle> _services = [];
  final Logger _logger;
  bool _isRunning = false;

  /// Registers a service for lifecycle management.
  void register(ILifecycle service) {
    if (_isRunning) {
      _logger.warning(
        'Registering service while node is already running. You must start it manually.',
      );
    }
    _services.add(service);
  }

  /// Starts all registered services in order.
  Future<void> startAll() async {
    if (_isRunning) return;
    _logger.info('Starting all services...');

    for (final service in _services) {
      try {
        _logger.debug('Starting ${service.runtimeType}...');
        await service.start();
      } catch (e, st) {
        _logger.error('Failed to start ${service.runtimeType}', e, st);
        // On failure, attempt to stop what was already started
        await stopAll();
        rethrow;
      }
    }

    _isRunning = true;
    _logger.info('All services started successfully');
  }

  /// Stops all registered services in reverse order.
  Future<void> stopAll() async {
    _logger.info('Stopping all services...');

    for (final service in _services.reversed) {
      try {
        _logger.debug('Stopping ${service.runtimeType}...');
        await service.stop();
      } catch (e, st) {
        _logger.error('Failed to stop ${service.runtimeType}', e, st);
        // Continue stopping other services even if one fails
      }
    }

    _isRunning = false;
    _logger.info('All services stopped');
  }

  /// Returns true if all registered services are running.
  bool get isRunning => _isRunning;
}
