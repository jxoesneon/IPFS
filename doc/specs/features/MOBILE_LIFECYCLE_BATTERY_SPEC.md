# Feature Specification: Mobile Lifecycle & Battery-Aware Connection Scaling (MOBILE_LIFECYCLE_BATTERY_SPEC)

## 1. Executive Summary

Mobile platforms (iOS, iPadOS, Android) impose strict resource and background execution constraints. Unlike server environments where a `dart_ipfs` node can maintain hundreds of long-lived TCP/QUIC swarm connections and continuously crawl the Kademlia DHT, mobile nodes are subject to aggressive OS watchdogs:
- **iOS/iPadOS**: Unentitled background execution is limited to ~30 seconds before the OS terminates suspended network sockets.
- **Android**: Android Doze Mode and App Standby restrict network access and defer background jobs during screen-off states.
- **Battery & Thermal Throttling**: Running continuous DHT provider sweeps, Bitswap broadcasts, and periodic reprovide passes on battery power leads to rapid depletion and user uninstalls.

This specification defines the **`MobileLifecycleCoordinator`**, an intelligent lifecycle- and power-aware state management layer that adaptively scales connection pools, pauses high-churn DHT crawls, transitions routing to delegated endpoints (Reframe/IPNI), and cleanly suspends/resumes the node across mobile app lifecycle states.

---

## 2. Platform Realities & Constraints

| Platform | Background Window | Socket Behavior in Background | Watchdog Penalty |
| :--- | :--- | :--- | :--- |
| **iOS / iPadOS** | ~30 seconds (`beginBackgroundTask`) | Sockets suspended; incoming packets dropped | `SIGKILL` (0x8badf00d) if background thread does not complete |
| **Android (Standard)** | Indefinite while active; throttled in Standby | Network access restricted during Doze maintenance windows | JobScheduler / WorkManager termination |
| **Desktop / Server** | Unlimited | Continuous long-lived connection pool | None |

---

## 3. Architecture & Power States

```
                 +-----------------------------------+
                 |           APP RESUMED             |
                 |      Power State: FULL_ACTIVE     |
                 +-----------------------------------+
                   |                               ^
                   | App Pauses / Screen Off       | App Resumes
                   v                               |
                 +-----------------------------------+
                 |           APP PAUSED              |
                 |      Power State: LOW_POWER       |
                 +-----------------------------------+
                   |                               ^
                   | Background Window Expires     | Wakeup / Push
                   v                               |
                 +-----------------------------------+
                 |         BACKGROUND SLEEP          |
                 |    Power State: SUSPENDED_MESH    |
                 +-----------------------------------+
```

### Power State Definitions

1. **`IpfsPowerMode.fullActive` (Foreground)**:
   - Swarm max connections: Standard config (e.g. 50–100 peers).
   - DHT mode: Active server/client as configured; periodic reprovide active.
   - Bitswap: Broadcast active.
2. **`IpfsPowerMode.lowPower` (Foreground Low Battery or Inactive)**:
   - Swarm max connections: Reduced (e.g. 10–15 peers).
   - DHT mode: Client-only; background crawling disabled.
   - Content resolution: Prioritize Delegated Routing (Reframe / IPNI) before DHT fallback.
3. **`IpfsPowerMode.suspendedMesh` (Background Sleep)**:
   - Swarm connections: Gracefully downscaled to 0–2 bootstrap/relay peers; non-essential sockets closed.
   - Reprovider: Suspended.
   - Blockstore: In-memory write buffers flushed to persistent storage (Hive / SQLite / Filesystem).
   - Discovery: Local mDNS and DHT crawls halted.

---

## 4. Technical Specification

### 4.1 Interface Contract: `MobileLifecycleAdapter`

```dart
/// Platform-agnostic lifecycle event interface.
enum NodeLifecycleState {
  resumed,
  inactive,
  paused,
  detached,
}

enum IpfsPowerMode {
  fullActive,
  lowPower,
  suspendedMesh,
}

abstract interface class MobileLifecycleAdapter {
  Stream<NodeLifecycleState> get lifecycleStream;
  Stream<bool> get lowBatteryStream;
  Future<void> requestBackgroundExtension({Duration duration});
}
```

### 4.2 The `MobileLifecycleCoordinator`

```dart
class MobileLifecycleCoordinator {
  MobileLifecycleCoordinator({
    required this.ipfsNode,
    required this.adapter,
    this.autoScaleSwarm = true,
  });

  final IpfsNode ipfsNode;
  final MobileLifecycleAdapter adapter;
  final bool autoScaleSwarm;

  IpfsPowerMode _currentMode = IpfsPowerMode.fullActive;
  IpfsPowerMode get currentMode => _currentMode;

  Future<void> onLifecycleChanged(NodeLifecycleState state) async {
    switch (state) {
      case NodeLifecycleState.resumed:
        await transitionTo(IpfsPowerMode.fullActive);
      case NodeLifecycleState.inactive:
        // Screen locking or system dialog appearing
        break;
      case NodeLifecycleState.paused:
        // App moving to background
        await transitionTo(IpfsPowerMode.suspendedMesh);
      case NodeLifecycleState.detached:
        // Process termination impending
        await ipfsNode.stop();
    }
  }

  Future<void> transitionTo(IpfsPowerMode mode) async {
    if (_currentMode == mode) return;
    _currentMode = mode;

    switch (mode) {
      case IpfsPowerMode.fullActive:
        ipfsNode.reprovider?.resume();
        ipfsNode.router?.resumeDiscovery();
        break;
      case IpfsPowerMode.lowPower:
        ipfsNode.reprovider?.pause();
        await ipfsNode.swarm?.trimConnections(maxConnections: 15);
        break;
      case IpfsPowerMode.suspendedMesh:
        ipfsNode.reprovider?.pause();
        ipfsNode.router?.pauseDiscovery();
        await ipfsNode.blockStore?.flush();
        await ipfsNode.swarm?.trimConnections(maxConnections: 2);
        break;
    }
  }
}
```

---

## 5. Verification Plan

1. **Unit & State Machine Tests**:
   - Verify `transitionTo` invokes correct sub-component methods (`reprovider.pause()`, `swarm.trimConnections()`, `blockStore.flush()`).
   - Verify state transitions produce expected `IpfsPowerMode` events.
2. **Mock Lifecycle Verification**:
   - Simulate rapid `resumed` -> `paused` -> `resumed` toggles to verify race safety and connection pool stabilization.
3. **Platform Integration Tests**:
   - Verify Flutter runner integration via `WidgetsBindingObserver`.
