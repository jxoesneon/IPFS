import 'package:dart_ipfs/src/core/types/peer_id.dart';

/// Represents a peer in the DHT network
class Peer {
  /// Creates a new Peer instance
  Peer({required this.id, required this.address, this.metadata});

  /// The unique identifier of the peer
  final PeerId id;

  /// The multiaddress where this peer can be reached
  final String address;

  /// Optional metadata about the peer
  final Map<String, dynamic>? metadata;

  /// Creates a string representation of the peer
  @override
  String toString() => 'Peer(id: $id, address: $address)';

  /// Creates a copy of this peer with optional parameter updates
  Peer copyWith({PeerId? id, String? address, Map<String, dynamic>? metadata}) {
    return Peer(
      id: id ?? this.id,
      address: address ?? this.address,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Compares two peers for equality
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Peer && other.id == id && other.address == address;
  }

  /// Generates a hash code for the peer
  @override
  int get hashCode => id.hashCode ^ address.hashCode;
}
