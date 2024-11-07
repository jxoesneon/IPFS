import 'package:p2plib/p2plib.dart' as p2p;
import '../../proto/generated/dht/dht.pb.dart';
import '../../proto/generated/core/peer.pb.dart';

/// Core peer representation used throughout the application
class IPFSPeer {
  final p2p.PeerId id;
  final List<p2p.FullAddress> addresses;
  final int latency;
  final String agentVersion;

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

  /// Converts from DHTPeer (DHT proto message)
  factory IPFSPeer.fromDHTPeer(DHTPeer peer) {
    return IPFSPeer(
      id: p2p.PeerId(value: peer.id),
      addresses: peer.addrs
          .map((addr) => parseMultiaddrString(addr))
          .whereType<p2p.FullAddress>()
          .toList(),
      latency: 0, // DHT peers don't track latency
      agentVersion: '', // DHT peers don't track version
    );
  }

  PeerProto toProto() {
    return PeerProto()
      ..id = Base58().encode(id.value)
      ..addresses.addAll(addresses.map((addr) => addr.toString()))
      ..latency = Int64(latency)
      ..agentVersion = agentVersion;
  }

  DHTPeer toDHTPeer() {
    return DHTPeer()
      ..id = id.value
      ..addrs.addAll(addresses.map((addr) => addr.toString()));
  }
}
