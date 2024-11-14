// src/core/interfaces/i_network_system.dart
import 'package:dart_ipfs/src/core/events/network_events.dart';
import 'package:dart_ipfs/src/core/interfaces/i_core_system.dart';
import 'package:p2plib/p2plib.dart';

abstract class INetworkSystem extends ICoreSystem {
  Future<void> connect(PeerId peer);
  Future<void> disconnect(PeerId peer);
  Stream<NetworkEvent> get events;
}
