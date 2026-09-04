// src/core/lifecycle/mobile_lifecycle_adapter.dart
import 'dart:async';

/// Represents the platform lifecycle states of an application embedding IPFS.
enum NodeLifecycleState {
  /// The application is visible and responding to user interaction.
  resumed,

  /// The application is in an inactive state and is not receiving user input
  /// (e.g. phone call, system alert, split-screen window switch).
  inactive,

  /// The application is currently not visible to the user, running in the background.
  paused,

  /// The application is still hosted on a Flutter/Dart engine but detached from any host view.
  detached,
}

/// Operational power tiers governing IPFS connection density and network activity.
enum IpfsPowerMode {
  /// Full connection pool, periodic DHT reprovide, and unconstrained Bitswap broadcasting.
  fullActive,

  /// Scaled-down swarm connections, DHT in client-only mode, prioritized delegated routing.
  lowPower,

  /// Background sleep mode with minimal swarm connections (0-2 peers), reprovider paused,
  /// and persistent blockstore cache flushed to disk.
  suspendedMesh,
}

/// Abstract interface for bridging platform-specific lifecycle and battery events
/// into the IPFS node without binding the core engine to a specific UI framework.
abstract interface class MobileLifecycleAdapter {
  /// Stream emitting changes to the application's lifecycle state.
  Stream<NodeLifecycleState> get lifecycleStream;

  /// Stream emitting boolean flags indicating whether the device is in a low-battery state.
  Stream<bool> get lowBatteryStream;

  /// Requests a temporary execution extension from the mobile OS (e.g. `beginBackgroundTask` on iOS).
  ///
  /// Returns `true` if the background extension was granted by the host OS.
  Future<bool> requestBackgroundExtension({
    Duration duration = const Duration(seconds: 30),
  });

  /// Disposes of any resources, controllers, or native channels held by this adapter.
  Future<void> dispose();
}

/// A controllable, stream-backed [MobileLifecycleAdapter] useful for testing,
/// CLI simulations, or custom platform integrations.
class ManualMobileLifecycleAdapter implements MobileLifecycleAdapter {
  /// Creates a new [ManualMobileLifecycleAdapter].
  ManualMobileLifecycleAdapter({
    NodeLifecycleState initialState = NodeLifecycleState.resumed,
    bool initialLowBattery = false,
  })  : _currentState = initialState,
        _isLowBattery = initialLowBattery;

  final StreamController<NodeLifecycleState> _lifecycleController =
      StreamController<NodeLifecycleState>.broadcast();
  final StreamController<bool> _lowBatteryController =
      StreamController<bool>.broadcast();

  NodeLifecycleState _currentState;
  bool _isLowBattery;
  bool _isDisposed = false;

  /// Returns the latest emitted lifecycle state.
  NodeLifecycleState get currentState => _currentState;

  /// Returns whether the adapter is currently reporting a low-battery state.
  bool get isLowBattery => _isLowBattery;

  @override
  Stream<NodeLifecycleState> get lifecycleStream => _lifecycleController.stream;

  @override
  Stream<bool> get lowBatteryStream => _lowBatteryController.stream;

  /// Programmatically emits a new [NodeLifecycleState].
  void setLifecycleState(NodeLifecycleState state) {
    if (_isDisposed) return;
    _currentState = state;
    _lifecycleController.add(state);
  }

  /// Programmatically emits a new low-battery flag.
  void setLowBattery(bool isLow) {
    if (_isDisposed) return;
    _isLowBattery = isLow;
    _lowBatteryController.add(isLow);
  }

  @override
  Future<bool> requestBackgroundExtension({
    Duration duration = const Duration(seconds: 30),
  }) async {
    // In-memory simulator grants extensions by default unless disposed.
    return !_isDisposed;
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    await _lifecycleController.close();
    await _lowBatteryController.close();
  }
}
