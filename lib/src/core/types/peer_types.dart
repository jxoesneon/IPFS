import 'dart:typed_data';

import 'package:dart_ipfs/src/core/data_structures/peer.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/utils/base58.dart';
import 'package:fixnum/fixnum.dart';

import '../../proto/generated/core/peer.pb.dart';
import '../../proto/generated/dht/kademlia.pb.dart' as kad;

/// Core peer representation used throughout the application.
class IPFSPeer {
  /// Creates an IPFS peer.
  IPFSPeer({
    required this.id,
    required this.addresses,
    required this.latency,
    required this.agentVersion,
  });

  /// Converts from PeerProto (core proto message)
  factory IPFSPeer.fromProto(PeerProto proto) {
    return IPFSPeer(
      id: PeerId(value: Base58().base58Decode(proto.id)),
      addresses: proto.addresses
          .map((addr) => parseMultiaddrString(addr))
          .whereType<FullAddress>()
          .toList(),
      latency: proto.latency.toInt(),
      agentVersion: proto.agentVersion,
    );
  }

  /// Converts from Kad Peer (DHT proto message)
  factory IPFSPeer.fromKadPeer(kad.Peer peer) {
    return IPFSPeer(
      id: PeerId(value: Uint8List.fromList(peer.id)),
      addresses: peer.addrs
          .map((addr) => multiaddrFromBytes(Uint8List.fromList(addr)))
          .whereType<FullAddress>()
          .toList(),
      latency: 0, // DHT peers don't track latency
      agentVersion: '', // DHT peers don't track version
    );
  }

  /// The peer ID.
  final PeerId id;

  /// Known addresses for this peer.
  final List<FullAddress> addresses;

  /// Network latency in milliseconds.
  final int latency;

  /// The peer's agent version string.
  final String agentVersion;

  /// Converts to PeerProto.
  PeerProto toProto() {
    return PeerProto()
      ..id = Base58().encode(id.value)
      ..addresses.addAll(addresses.map((addr) => addr.toString()))
      ..latency = Int64(latency)
      ..agentVersion = agentVersion;
  }

  /// Converts to Kad Peer for DHT operations.
  kad.Peer toKadPeer() {
    return kad.Peer()
      ..id = id.value
      ..addrs.addAll(addresses.map((addr) => multiaddrToBytes(addr)));
  }
}
