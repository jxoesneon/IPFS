
// lib/src/core/data_structures/peer.dart

import 'package:fixnum/fixnum.dart';
import 'package:p2plib/p2plib.dart'; // Import p2plib for peer management
import '../../proto/generated/core/peer.pb.dart'; // Import the generated Protobuf file
import '/../src/utils/base58.dart';

/// Represents a peer in the IPFS network.
class Peer {
  final PeerId id; // Unique identifier for the peer using p2plib's PeerId
  final List<Multiaddr> addresses; // List of multiaddresses for the peer using p2plib's Multiaddr
  final int latency; // Estimated latency to the peer
  final String agentVersion; // Version of the IPFS agent running on the peer

  Peer({
    required this.id,
    required this.addresses,
    required this.latency,
    required this.agentVersion,
  });

  /// Creates a [Peer] from its Protobuf representation.
  factory Peer.fromProto(PeerProto proto) {
    return Peer(
      id: PeerId.fromBase58(proto.id), // Convert from base58 string to PeerId
      addresses: proto.addresses.map((addr) => Multiaddr(addr)).toList(), // Convert each address string to Multiaddr
      latency: proto.latency.toInt(),
      agentVersion: proto.agentVersion,
    );
  }

  /// Converts the [Peer] to its Protobuf representation.
  PeerProto toProto() {
    return PeerProto()
      ..id = Base58().encode(id.value) // Convert PeerId back to base58 string
      ..addresses.addAll(addresses.map((addr) => addr.toString())) // Convert Multiaddr back to string
      ..latency = Int64(latency)
      ..agentVersion = agentVersion;
  }

  @override
  String toString() {
    return 'Peer{id: ${id.value}, addresses: ${addresses.map((addr) => addr.toString()).toList()}, latency: $latency, agentVersion: $agentVersion}';
  }
}