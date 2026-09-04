// src/core/lifecycle/mobile_lifecycle_coordinator.dart
import 'dart:async';

import '../../protocols/dht/reprovider.dart';
import '../../utils/logger.dart';
import '../data_structures/blockstore.dart';
import '../interfaces/i_lifecycle.dart';
import '../ipfs_node/network_manager.dart';
import 'mobile_lifecycle_adapter.dart';

/// Coordinates node resource utilization, background connection scaling, and
/// persistent cache safety in mobile application environments.
class MobileLifecycleCoordinator implements ILifecycle {
  /// Creates a new [MobileLifecycleCoordinator].
  MobileLifecycleCoordinator({
    required this.adapter,
    this.reprovider,
    this.networkManager,
    this.blockStore,
    this.onDetached,
    this.autoScaleSwarm = true,
    this.maxForegroundConnections = 50,
    this.maxLowPowerConnections = 15,
    this.maxBackgroundConnections = 2,
    this.pauseReproviderOnBackground = true,
    this.flushBlockStoreOnBackground = true,
    this.requestBackgroundExtensionOnPause = true,
    this.backgroundExtensionDuration = const Duration(seconds: 30),
  }) : _logger = Logger('MobileLifecycleCoordinator');

  /// The platform lifecycle adapter providing event streams.
  final MobileLifecycleAdapter adapter;

  /// Optional periodic reprovider service to pause/resume.
  final Reprovider? reprovider;

  /// Optional network manager to manage active swarm peer connections.
  final NetworkManager? networkManager;

  /// Optional block store to flush prior to background sleep.
  final BlockStore? blockStore;

  /// Optional callback triggered when the mobile engine is detached/terminated.
  final Future<void> Function()? onDetached;

  /// Whether to automatically trim swarm connections during power mode changes.
  final bool autoScaleSwarm;

  /// Target maximum connections in [IpfsPowerMode.fullActive].
  final int maxForegroundConnections;

  /// Target maximum connections in [IpfsPowerMode.lowPower].
  final int maxLowPowerConnections;

  /// Target maximum connections in [IpfsPowerMode.suspendedMesh].
  final int maxBackgroundConnections;

  /// Whether to pause periodic reproviding when the application enters the background.
  final bool pauseReproviderOnBackground;

  /// Whether to flush in-memory blockstore pins to persistent disk before backgrounding.
  final bool flushBlockStoreOnBackground;

  /// Whether to request a background execution extension when entering the background.
  final bool requestBackgroundExtensionOnPause;

  /// Duration to request for background extension.
  final Duration backgroundExtensionDuration;

  final Logger _logger;
  final StreamController<IpfsPowerMode> _powerModeController =
      StreamController<IpfsPowerMode>.broadcast();

  StreamSubscription<NodeLifecycleState>? _lifecycleSub;
  StreamSubscription<bool>? _batterySub;

  IpfsPowerMode _currentPowerMode = IpfsPowerMode.fullActive;
  NodeLifecycleState _currentLifecycleState = NodeLifecycleState.resumed;
  bool _isLowBattery = false;
  bool _isRunning = false;
  Completer<void>? _transitionLock;

  /// Returns the current power mode.
  IpfsPowerMode get currentPowerMode => _currentPowerMode;

  /// Returns the latest recorded lifecycle state.
  NodeLifecycleState get currentLifecycleState => _currentLifecycleState;

  /// Returns whether the device is currently reported in low battery mode.
  bool get isLowBattery => _isLowBattery;

  /// Returns whether the coordinator is actively listening to lifecycle events.
  bool get isRunning => _isRunning;

  /// Stream emitting changes to the active [IpfsPowerMode].
  Stream<IpfsPowerMode> get onPowerModeChanged => _powerModeController.stream;

  @override
  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;
    _logger.info('Starting MobileLifecycleCoordinator...');

    _lifecycleSub = adapter.lifecycleStream.listen(
      (state) => unawaited(handleLifecycleChange(state)),
      onError: (e, st) => _logger.error('Error in lifecycle stream', e, st),
    );

    _batterySub = adapter.lowBatteryStream.listen(
      (isLow) => unawaited(handleBatteryState(isLow)),
      onError: (e, st) => _logger.error('Error in battery stream', e, st),
    );

    _logger.debug('MobileLifecycleCoordinator started successfully');
  }

  @override
  Future<void> stop() async {
    if (!_isRunning) return;
    _isRunning = false;
    _logger.info('Stopping MobileLifecycleCoordinator...');

    await _lifecycleSub?.cancel();
    _lifecycleSub = null;

    await _batterySub?.cancel();
    _batterySub = null;

    await _powerModeController.close();
    _logger.debug('MobileLifecycleCoordinator stopped');
  }

  /// Processes a change in application lifecycle state.
  Future<void> handleLifecycleChange(NodeLifecycleState state) async {
    _logger.info('Lifecycle state changed to: $state');
    _currentLifecycleState = state;

    switch (state) {
      case NodeLifecycleState.resumed:
        final target = _isLowBattery ? IpfsPowerMode.lowPower : IpfsPowerMode.fullActive;
        await transitionTo(target);
      case NodeLifecycleState.inactive:
        _logger.debug('Application inactive; maintaining mode $_currentPowerMode');
      case NodeLifecycleState.paused:
        if (requestBackgroundExtensionOnPause) {
          try {
            await adapter.requestBackgroundExtension(
              duration: backgroundExtensionDuration,
            );
          } catch (e) {
            _logger.warning('Failed to request background execution extension: $e');
          }
        }
        await transitionTo(IpfsPowerMode.suspendedMesh);
      case NodeLifecycleState.detached:
        _logger.warning('Application detached. Executing shutdown handler...');
        await transitionTo(IpfsPowerMode.suspendedMesh);
        if (onDetached != null) {
          try {
            await onDetached!();
          } catch (e, st) {
            _logger.error('Error executing onDetached callback', e, st);
          }
        }
    }
  }

  /// Processes an update in device battery state.
  Future<void> handleBatteryState(bool isLow) async {
    _logger.info('Device low-battery flag changed to: $isLow');
    _isLowBattery = isLow;

    // Background sleep takes precedence over battery power modes.
    if (_currentLifecycleState == NodeLifecycleState.paused ||
        _currentLifecycleState == NodeLifecycleState.detached) {
      return;
    }

    final target = isLow ? IpfsPowerMode.lowPower : IpfsPowerMode.fullActive;
    await transitionTo(target);
  }

  /// Explicitly transitions the coordinator and underlying IPFS node to [targetMode].
  Future<void> transitionTo(IpfsPowerMode targetMode) async {
    while (_transitionLock != null) {
      await _transitionLock!.future;
    }

    if (_currentPowerMode == targetMode) return;

    _transitionLock = Completer<void>();
    try {
      _logger.info('Transitioning power mode: $_currentPowerMode -> $targetMode');

      switch (targetMode) {
        case IpfsPowerMode.fullActive:
          reprovider?.resume();
          break;

        case IpfsPowerMode.lowPower:
          if (autoScaleSwarm && networkManager != null) {
            try {
              await networkManager!.trimConnections(
                maxConnections: maxLowPowerConnections,
              );
            } catch (e) {
              _logger.warning('Failed to trim connections in lowPower mode: $e');
            }
          }
          break;

        case IpfsPowerMode.suspendedMesh:
          if (pauseReproviderOnBackground) {
            reprovider?.pause();
          }
          if (flushBlockStoreOnBackground && blockStore != null) {
            try {
              await blockStore!.flush();
            } catch (e) {
              _logger.warning('Failed to flush blockstore on pause: $e');
            }
          }
          if (autoScaleSwarm && networkManager != null) {
            try {
              await networkManager!.trimConnections(
                maxConnections: maxBackgroundConnections,
              );
            } catch (e) {
              _logger.warning('Failed to trim connections in suspendedMesh mode: $e');
            }
          }
          break;
      }

      _currentPowerMode = targetMode;
      if (!_powerModeController.isClosed) {
        _powerModeController.add(targetMode);
      }
      _logger.debug('Power mode transition to $targetMode complete');
    } finally {
      final lock = _transitionLock;
      _transitionLock = null;
      lock?.complete();
    }
  }
}
