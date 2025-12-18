import 'dart:typed_data';

import 'package:dart_ipfs/src/core/data_structures/peer.dart';
import 'package:dart_ipfs/src/utils/base58.dart';
import 'package:fixnum/fixnum.dart';
import 'package:p2plib/p2plib.dart' as p2p;

import '../../proto/generated/core/peer.pb.dart';
import '../../proto/generated/dht/kademlia.pb.dart' as kad;

/// Core peer representation used throughout the application
class IPFSPeer {

  IPFSPeer({
    required this.id,
    required this.addresses,
    required this.latency,
    required this.agentVersion,
  });

  /// Converts from PeerProto (core proto message)
  factory IPFSPeer.fromProto(PeerProto proto) {
    return IPFSPeer(
      id: p2p.PeerId(value: Base58().base58Decode(proto.id)),
      addresses: proto.addresses
          .map((addr) => parseMultiaddrString(addr))
          .whereType<p2p.FullAddress>()
          .toList(),
      latency: proto.latency.toInt(),
      agentVersion: proto.agentVersion,
    );
  }

  /// Converts from Kad Peer (DHT proto message)
  factory IPFSPeer.fromKadPeer(kad.Peer peer) {
    return IPFSPeer(
      id: p2p.PeerId(value: Uint8List.fromList(peer.id)),
      addresses: peer.addrs
          .map((addr) => multiaddrFromBytes(Uint8List.fromList(addr)))
          .whereType<p2p.FullAddress>()
          .toList(),
      latency: 0, // DHT peers don't track latency
      agentVersion: '', // DHT peers don't track version
    );
  }
  final p2p.PeerId id;
  final List<p2p.FullAddress> addresses;
  final int latency;
  final String agentVersion;

  PeerProto toProto() {
    return PeerProto()
      ..id = Base58().encode(id.value)
      ..addresses.addAll(addresses.map((addr) => addr.toString()))
      ..latency = Int64(latency)
      ..agentVersion = agentVersion;
  }

  kad.Peer toKadPeer() {
    return kad.Peer()
      ..id = id.value
      ..addrs.addAll(addresses.map((addr) => multiaddrToBytes(addr)));
  }
}
