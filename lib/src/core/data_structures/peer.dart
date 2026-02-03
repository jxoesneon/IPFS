// src/core/data_structures/peer.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/proto/generated/core/peer.pb.dart';
import 'package:dart_ipfs/src/utils/base58.dart';
import 'package:fixnum/fixnum.dart';

/// Represents a network address (IP + Port).
/// Replaces p2plib.FullAddress.
class FullAddress {
  /// Creates a [FullAddress] with the given [address] and [port].
  const FullAddress({required this.address, required this.port});

  /// The IP address of the peer.
  final InternetAddress address;

  /// The port number of the peer.
  final int port;

  @override
  String toString() => '/ip4/${address.address}/tcp/$port';
}

/// Represents a peer node in the IPFS network.
///
/// A Peer encapsulates information about a remote IPFS node, including
/// its cryptographic identity, network addresses, latency metrics, and
/// client version information.
class Peer {
  /// Creates a new Peer with the given properties.
  Peer({
    required this.id,
    required this.addresses,
    required this.latency,
    required this.agentVersion,
  });

  /// Creates a [Peer] from its Protobuf representation.
  factory Peer.fromProto(PeerProto proto) {
    return Peer(
      id: PeerId(
        value: Base58().base58Decode(proto.id),
      ), // Convert base58 string back to PeerId
      addresses: proto.addresses
          .map((addr) => parseMultiaddrString(addr))
          .whereType<FullAddress>()
          .toList(), // Convert each address string to FullAddress
      latency: proto.latency.toInt(),
      agentVersion: proto.agentVersion,
    );
  }

  /// Creates a [Peer] with minimal information from a peer ID string.
  factory Peer.fromId(String peerId) {
    return Peer(
      id: PeerId(value: Base58().base58Decode(peerId)),
      addresses: [], // Empty list since we don't know addresses yet
      latency: 0, // Default latency
      agentVersion: '', // Empty version since we don't know it yet
    );
  }

  /// The unique cryptographic identifier for this peer.
  final PeerId id;

  /// Network addresses where this peer can be reached.
  final List<FullAddress> addresses;

  /// Network latency to this peer in milliseconds.
  final int latency;

  /// The IPFS client version string reported by this peer.
  final String agentVersion;

  /// Converts the [Peer] to its Protobuf representation.
  PeerProto toProto() {
    return PeerProto()
      ..id = Base58()
          .encode(id.value) // Convert PeerId back to base58 string
      ..addresses.addAll(
        addresses.map((addr) => addr.toString()),
      ) // Convert FullAddress back to string
      ..latency = Int64(latency)
      ..agentVersion = agentVersion;
  }

  @override
  String toString() {
    return 'Peer{id: ${id.value}, addresses: ${addresses.map((addr) => addr.toString()).toList()}, latency: $latency, agentVersion: $agentVersion}';
  }

  /// Creates a [Peer] from a multiaddr string
  static Future<Peer> fromMultiaddr(String multiaddr) async {
    try {
      // Parse the multiaddr to extract peer ID and address
      final parts = multiaddr.split('/');

      // The peer ID is the last component after '/p2p/'
      final peerIdIndex = parts.indexOf('p2p') + 1;
      if (peerIdIndex >= parts.length) {
        throw FormatException('No peer ID found in multiaddr: $multiaddr');
      }

      final peerId = PeerId(value: Base58().base58Decode(parts[peerIdIndex]));

      // Parse the address portion
      final address = parseMultiaddrString(multiaddr);
      if (address == null) {
        throw FormatException('Invalid address in multiaddr: $multiaddr');
      }

      return Peer(
        id: peerId,
        addresses: [address],
        latency: 0, // Default latency for new peers
        agentVersion: '', // Empty version since we don't know it yet
      );
    } catch (e) {
      throw FormatException('Error parsing multiaddr: $e');
    }
  }
}

/// Helper function to parse a multiaddr string into a FullAddress.
FullAddress? parseMultiaddrString(String multiaddrString) {
  try {
    // Basic support for /ip4/<ip>/tcp/<port> format
    final parts = multiaddrString.split('/');
    if (parts.length < 5) return null;

    final protocol = parts[1];
    final host = parts[2];
    // parts[3] should be 'tcp' or 'udp'
    final portStr = parts[4];
    final port = int.tryParse(portStr);

    if (protocol != 'ip4' && protocol != 'ip6') return null;
    if (port == null || port == 0) return null;

    final ipAddress = InternetAddress(host);
    return FullAddress(address: ipAddress, port: port);
  } catch (e) {
    // print('Error parsing multiaddr string: $e');
    return null;
  }
}

/// Helper to decode binary multiaddr to FullAddress
FullAddress? multiaddrFromBytes(Uint8List bytes) {
  try {
    var offset = 0;
    // Protocol code 1
    final p1 = bytes[offset++];

    InternetAddress? ip;
    int? port;

    if (p1 == 4) {
      // ip4
      if (bytes.length < offset + 4) return null;
      final ipBytes = bytes.sublist(offset, offset + 4);
      ip = InternetAddress.fromRawAddress(ipBytes);
      offset += 4;
    } else if (p1 == 41) {
      // ip6
      if (bytes.length < offset + 16) return null;
      final ipBytes = bytes.sublist(offset, offset + 16);
      ip = InternetAddress.fromRawAddress(ipBytes);
      offset += 16;
    } else {
      return null; // Unsupported transport
    }

    if (offset >= bytes.length) return null;
    final p2 = bytes[offset++];

    if (p2 == 6) {
      // tcp
      if (bytes.length < offset + 2) return null;
      final portBytes = bytes.sublist(offset, offset + 2);
      port = (portBytes[0] << 8) | portBytes[1];
      offset += 2;
    } else if (p2 == 17) {
      // udp
      if (bytes.length < offset + 2) return null;
      final portBytes = bytes.sublist(offset, offset + 2);
      port = (portBytes[0] << 8) | portBytes[1];
      offset += 2;
    }
    // Ignoring p2p ID part if present for now

    if (port != null) {
      return FullAddress(address: ip, port: port);
    }
    return null;
  } catch (e) {
    return null;
  }
}

/// Helper to encode FullAddress to binary multiaddr
Uint8List multiaddrToBytes(FullAddress address) {
  final buffer = BytesBuilder();
  if (address.address.type == InternetAddressType.IPv4) {
    buffer.addByte(4); // ip4
    buffer.add(address.address.rawAddress);
  } else if (address.address.type == InternetAddressType.IPv6) {
    buffer.addByte(41); // ip6
    buffer.add(address.address.rawAddress);
  } else {
    return Uint8List(0); // Unsupported
  }

  // Assuming TCP (6) by default for FullAddress as we don't have protocol field
  buffer.addByte(6); // tcp
  buffer.addByte((address.port >> 8) & 0xFF);
  buffer.addByte(address.port & 0xFF);

  return buffer.toBytes();
}
