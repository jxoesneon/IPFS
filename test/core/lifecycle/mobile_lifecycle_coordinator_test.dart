import 'dart:async';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_manager.dart';
import 'package:dart_ipfs/src/core/lifecycle/mobile_lifecycle_adapter.dart';
import 'package:dart_ipfs/src/core/lifecycle/mobile_lifecycle_coordinator.dart';
import 'package:dart_ipfs/src/protocols/dht/reprovider.dart';
import 'package:test/test.dart';

// Test doubles / stubs
class FakeReprovider implements Reprovider {
  bool pauseCalled = false;
  bool resumeCalled = false;
  bool _paused = false;

  @override
  bool get isPaused => _paused;

  @override
  void pause() {
    pauseCalled = true;
    _paused = true;
  }

  @override
  void resume() {
    resumeCalled = true;
    _paused = false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeNetworkManager implements NetworkManager {
  int lastTrimMaxConnections = -1;
  int trimCallCount = 0;
  bool shouldThrowOnTrim = false;

  @override
  Future<int> trimConnections({int maxConnections = 2}) async {
    trimCallCount++;
    lastTrimMaxConnections = maxConnections;
    if (shouldThrowOnTrim) {
      throw Exception('Simulated network trim error');
    }
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeBlockStore implements BlockStore {
  bool flushCalled = false;
  int flushCallCount = 0;
  bool shouldThrowOnFlush = false;

  @override
  Future<void> flush() async {
    flushCalled = true;
    flushCallCount++;
    if (shouldThrowOnFlush) {
      throw Exception('Simulated disk write error');
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('ManualMobileLifecycleAdapter', () {
    test('initializes with default states', () {
      final adapter = ManualMobileLifecycleAdapter();
      expect(adapter.currentState, equals(NodeLifecycleState.resumed));
      expect(adapter.isLowBattery, isFalse);
    });

    test('initializes with custom states', () {
      final adapter = ManualMobileLifecycleAdapter(
        initialState: NodeLifecycleState.paused,
        initialLowBattery: true,
      );
      expect(adapter.currentState, equals(NodeLifecycleState.paused));
      expect(adapter.isLowBattery, isTrue);
    });

    test('emits lifecycle stream events', () async {
      final adapter = ManualMobileLifecycleAdapter();
      final events = <NodeLifecycleState>[];
      final sub = adapter.lifecycleStream.listen(events.add);

      adapter.setLifecycleState(NodeLifecycleState.inactive);
      adapter.setLifecycleState(NodeLifecycleState.paused);
      adapter.setLifecycleState(NodeLifecycleState.resumed);

      await pumpEventQueue();
      expect(events, equals([
        NodeLifecycleState.inactive,
        NodeLifecycleState.paused,
        NodeLifecycleState.resumed,
      ]));
      expect(adapter.currentState, equals(NodeLifecycleState.resumed));

      await sub.cancel();
      await adapter.dispose();
    });

    test('emits low battery stream events', () async {
      final adapter = ManualMobileLifecycleAdapter();
      final events = <bool>[];
      final sub = adapter.lowBatteryStream.listen(events.add);

      adapter.setLowBattery(true);
      adapter.setLowBattery(false);

      await pumpEventQueue();
      expect(events, equals([true, false]));
      expect(adapter.isLowBattery, isFalse);

      await sub.cancel();
      await adapter.dispose();
    });

    test('requestBackgroundExtension returns true while active, false when disposed', () async {
      final adapter = ManualMobileLifecycleAdapter();
      final granted = await adapter.requestBackgroundExtension();
      expect(granted, isTrue);

      await adapter.dispose();
      final grantedAfterDispose = await adapter.requestBackgroundExtension();
      expect(grantedAfterDispose, isFalse);
    });
  });

  group('MobileLifecycleCoordinator', () {
    late ManualMobileLifecycleAdapter adapter;
    late FakeReprovider reprovider;
    late FakeNetworkManager networkManager;
    late FakeBlockStore blockStore;
    late MobileLifecycleCoordinator coordinator;

    setUp(() {
      adapter = ManualMobileLifecycleAdapter();
      reprovider = FakeReprovider();
      networkManager = FakeNetworkManager();
      blockStore = FakeBlockStore();

      coordinator = MobileLifecycleCoordinator(
        adapter: adapter,
        reprovider: reprovider,
        networkManager: networkManager,
        blockStore: blockStore,
        maxForegroundConnections: 50,
        maxLowPowerConnections: 12,
        maxBackgroundConnections: 3,
      );
    });

    tearDown(() async {
      if (coordinator.isRunning) {
        await coordinator.stop();
      }
      await adapter.dispose();
    });

    test('starts with fullActive mode and responds to start/stop', () async {
      expect(coordinator.currentPowerMode, equals(IpfsPowerMode.fullActive));
      expect(coordinator.isRunning, isFalse);

      await coordinator.start();
      expect(coordinator.isRunning, isTrue);

      // Calling start multiple times is idempotent
      await coordinator.start();
      expect(coordinator.isRunning, isTrue);

      await coordinator.stop();
      expect(coordinator.isRunning, isFalse);

      // Calling stop multiple times is idempotent
      await coordinator.stop();
      expect(coordinator.isRunning, isFalse);
    });

    test('transitions to suspendedMesh on app paused and trims connections', () async {
      await coordinator.start();
      final modeChanges = <IpfsPowerMode>[];
      final sub = coordinator.onPowerModeChanged.listen(modeChanges.add);

      adapter.setLifecycleState(NodeLifecycleState.paused);
      await pumpEventQueue();

      expect(coordinator.currentPowerMode, equals(IpfsPowerMode.suspendedMesh));
      expect(coordinator.currentLifecycleState, equals(NodeLifecycleState.paused));
      expect(reprovider.pauseCalled, isTrue);
      expect(blockStore.flushCalled, isTrue);
      expect(networkManager.trimCallCount, equals(1));
      expect(networkManager.lastTrimMaxConnections, equals(3));
      expect(modeChanges, equals([IpfsPowerMode.suspendedMesh]));

      await sub.cancel();
    });

    test('resumes from paused to fullActive when battery is healthy', () async {
      await coordinator.start();

      adapter.setLifecycleState(NodeLifecycleState.paused);
      await pumpEventQueue();
      expect(coordinator.currentPowerMode, equals(IpfsPowerMode.suspendedMesh));

      adapter.setLifecycleState(NodeLifecycleState.resumed);
      await pumpEventQueue();

      expect(coordinator.currentPowerMode, equals(IpfsPowerMode.fullActive));
      expect(reprovider.resumeCalled, isTrue);
    });

    test('resumes from paused to lowPower when device is low on battery', () async {
      await coordinator.start();

      adapter.setLifecycleState(NodeLifecycleState.paused);
      await pumpEventQueue();

      adapter.setLowBattery(true);
      await pumpEventQueue();
      // Low battery during paused does not prematurely wake node from suspendedMesh
      expect(coordinator.currentPowerMode, equals(IpfsPowerMode.suspendedMesh));

      adapter.setLifecycleState(NodeLifecycleState.resumed);
      await pumpEventQueue();

      expect(coordinator.currentPowerMode, equals(IpfsPowerMode.lowPower));
      expect(networkManager.lastTrimMaxConnections, equals(12));
    });

    test('transitions between fullActive and lowPower when battery state toggles in foreground', () async {
      await coordinator.start();

      adapter.setLowBattery(true);
      await pumpEventQueue();
      expect(coordinator.currentPowerMode, equals(IpfsPowerMode.lowPower));
      expect(networkManager.lastTrimMaxConnections, equals(12));

      adapter.setLowBattery(false);
      await pumpEventQueue();
      expect(coordinator.currentPowerMode, equals(IpfsPowerMode.fullActive));
      expect(reprovider.resumeCalled, isTrue);
    });

    test('maintains power mode on inactive state', () async {
      await coordinator.start();

      adapter.setLifecycleState(NodeLifecycleState.inactive);
      await pumpEventQueue();
      expect(coordinator.currentPowerMode, equals(IpfsPowerMode.fullActive));
      expect(coordinator.currentLifecycleState, equals(NodeLifecycleState.inactive));
    });

    test('executes onDetached callback on detached state', () async {
      var detachedCalled = false;
      final customCoordinator = MobileLifecycleCoordinator(
        adapter: adapter,
        onDetached: () async {
          detachedCalled = true;
        },
      );

      await customCoordinator.start();
      adapter.setLifecycleState(NodeLifecycleState.detached);
      await pumpEventQueue();

      expect(detachedCalled, isTrue);
      expect(customCoordinator.currentPowerMode, equals(IpfsPowerMode.suspendedMesh));
      await customCoordinator.stop();
    });

    test('handles component exceptions gracefully without wedging state transitions', () async {
      networkManager.shouldThrowOnTrim = true;
      blockStore.shouldThrowOnFlush = true;

      await coordinator.start();

      // Even if networkManager and blockStore throw, coordinator completes transition safely
      adapter.setLifecycleState(NodeLifecycleState.paused);
      await pumpEventQueue();

      expect(coordinator.currentPowerMode, equals(IpfsPowerMode.suspendedMesh));

      adapter.setLifecycleState(NodeLifecycleState.resumed);
      await pumpEventQueue();

      expect(coordinator.currentPowerMode, equals(IpfsPowerMode.fullActive));
    });

    test('rapid concurrent state transitions execute sequentially without deadlock', () async {
      await coordinator.start();

      // Rapidly toggle state
      adapter.setLifecycleState(NodeLifecycleState.paused);
      adapter.setLifecycleState(NodeLifecycleState.resumed);
      adapter.setLifecycleState(NodeLifecycleState.paused);
      adapter.setLifecycleState(NodeLifecycleState.resumed);

      await pumpEventQueue();
      expect(coordinator.currentPowerMode, equals(IpfsPowerMode.fullActive));
    });

    test('works cleanly with all null optional components', () async {
      final minimalCoordinator = MobileLifecycleCoordinator(
        adapter: adapter,
      );

      await minimalCoordinator.start();

      adapter.setLifecycleState(NodeLifecycleState.paused);
      await pumpEventQueue();
      expect(minimalCoordinator.currentPowerMode, equals(IpfsPowerMode.suspendedMesh));

      adapter.setLifecycleState(NodeLifecycleState.resumed);
      await pumpEventQueue();
      expect(minimalCoordinator.currentPowerMode, equals(IpfsPowerMode.fullActive));

      await minimalCoordinator.stop();
    });
  });
}
