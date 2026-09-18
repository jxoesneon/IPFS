@TestOn('vm')
import 'dart:async';

import 'package:dart_ipfs/src/core/lifecycle/mobile_lifecycle_adapter.dart';
import 'package:dart_ipfs/src/core/lifecycle/mobile_lifecycle_coordinator.dart';
import 'package:test/test.dart';

/// End-to-end journeys through [MobileLifecycleCoordinator] driven by the
/// stream-backed [ManualMobileLifecycleAdapter]: real stream subscriptions,
/// lifecycle→power-mode mapping, and transitions.
void main() {
  group('E2E mobile lifecycle coordination', () {
    late ManualMobileLifecycleAdapter adapter;
    late MobileLifecycleCoordinator coordinator;

    setUp(() {
      adapter = ManualMobileLifecycleAdapter();
      coordinator = MobileLifecycleCoordinator(adapter: adapter);
    });

    tearDown(() async {
      await coordinator.stop();
      await adapter.dispose();
    });

    test('starts running and subscribes to adapter streams', () async {
      expect(coordinator.isRunning, isFalse);
      await coordinator.start();
      expect(coordinator.isRunning, isTrue);
      expect(coordinator.currentPowerMode, IpfsPowerMode.fullActive);
    });

    test('adapter lifecycle emissions drive power-mode transitions', () async {
      await coordinator.start();

      final modes = <IpfsPowerMode>[];
      final sub = coordinator.onPowerModeChanged.listen(modes.add);

      adapter.setLifecycleState(NodeLifecycleState.paused);
      await waitForMode(coordinator, IpfsPowerMode.suspendedMesh);
      expect(
        coordinator.currentLifecycleState,
        equals(NodeLifecycleState.paused),
      );

      adapter.setLifecycleState(NodeLifecycleState.resumed);
      await waitForMode(coordinator, IpfsPowerMode.fullActive);
      expect(
        coordinator.currentLifecycleState,
        equals(NodeLifecycleState.resumed),
      );

      await sub.cancel();
      expect(
        modes,
        containsAllInOrder(<IpfsPowerMode>[
          IpfsPowerMode.suspendedMesh,
          IpfsPowerMode.fullActive,
        ]),
      );
    });

    test('battery emissions drive lowPower and back', () async {
      await coordinator.start();

      adapter.setLowBattery(true);
      await waitForMode(coordinator, IpfsPowerMode.lowPower);
      expect(coordinator.isLowBattery, isTrue);

      adapter.setLowBattery(false);
      await waitForMode(coordinator, IpfsPowerMode.fullActive);
      expect(coordinator.isLowBattery, isFalse);
    });

    test(
      'low battery during background sleep does not wake the node',
      () async {
        await coordinator.start();

        adapter.setLifecycleState(NodeLifecycleState.paused);
        await waitForMode(coordinator, IpfsPowerMode.suspendedMesh);

        adapter.setLowBattery(true);
        await Future<void>.delayed(const Duration(milliseconds: 200));
        // Background sleep takes precedence — stays suspended.
        expect(coordinator.currentPowerMode, IpfsPowerMode.suspendedMesh);
      },
    );

    test('detached invokes the shutdown callback', () async {
      var detached = false;
      await coordinator.stop();
      coordinator = MobileLifecycleCoordinator(
        adapter: adapter,
        onDetached: () async {
          detached = true;
        },
      );
      await coordinator.start();

      adapter.setLifecycleState(NodeLifecycleState.detached);
      await waitForMode(coordinator, IpfsPowerMode.suspendedMesh);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(detached, isTrue);
    });

    test('explicit transitionTo applies power modes directly', () async {
      await coordinator.start();

      await coordinator.transitionTo(IpfsPowerMode.lowPower);
      expect(coordinator.currentPowerMode, IpfsPowerMode.lowPower);

      await coordinator.transitionTo(IpfsPowerMode.fullActive);
      expect(coordinator.currentPowerMode, IpfsPowerMode.fullActive);
    });
  });
}

Future<void> waitForMode(
  MobileLifecycleCoordinator coordinator,
  IpfsPowerMode mode, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (coordinator.currentPowerMode == mode) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  throw TimeoutException('Timed out waiting for power mode $mode', timeout);
}
