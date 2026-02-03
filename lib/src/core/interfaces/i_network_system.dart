// src/core/interfaces/i_network_system.dart
import 'package:dart_ipfs/src/core/events/network_events.dart';
import 'package:dart_ipfs/src/core/interfaces/i_core_system.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';

/// Interface for network subsystem operations.
///
/// Extends [ICoreSystem] with peer connection management
/// and network event streaming.
abstract class INetworkSystem extends ICoreSystem {
  /// Connects to the specified [peer].
  Future<void> connect(PeerId peer);

  /// Disconnects from the specified [peer].
  Future<void> disconnect(PeerId peer);

  /// Stream of network events for monitoring.
  Stream<NetworkEvent> get events;
}
