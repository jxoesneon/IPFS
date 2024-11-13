// src/core/data_structures/peer.dart
import 'dart:io';
import 'package:fixnum/fixnum.dart';
import 'package:dart_ipfs/src/utils/base58.dart';
import 'package:p2plib/p2plib.dart' as p2p; // Import p2plib for peer management
import 'package:dart_ipfs/src/proto/generated/core/peer.pb.dart'; // Import the generated Protobuf file
// lib/src/core/data_structures/peer.dart

/// Represents a peer in the IPFS network.
class Peer {
  final p2p.PeerId id;
  final List<p2p.FullAddress> addresses;
  final int latency;
  final String agentVersion;

  Peer({
    required this.id,
    required this.addresses,
    required this.latency,
    required this.agentVersion,
  });

  /// Creates a [Peer] from its Protobuf representation.
  factory Peer.fromProto(PeerProto proto) {
    return Peer(
      id: p2p.PeerId(
          value: Base58()
              .base58Decode(proto.id)), // Convert base58 string back to PeerId
      addresses: proto.addresses
          .map((addr) => parseMultiaddrString(addr))
          .whereType<p2p.FullAddress>()
          .toList(), // Convert each address string to FullAddress
      latency: proto.latency.toInt(),
      agentVersion: proto.agentVersion,
    );
  }

  /// Converts the [Peer] to its Protobuf representation.
  PeerProto toProto() {
    return PeerProto()
      ..id = Base58().encode(id.value) // Convert PeerId back to base58 string
      ..addresses.addAll(addresses
          .map((addr) => addr.toString())) // Convert FullAddress back to string
      ..latency = Int64(latency)
      ..agentVersion = agentVersion;
  }

  @override
  String toString() {
    return 'Peer{id: ${id.value}, addresses: ${addresses.map((addr) => addr.toString()).toList()}, latency: $latency, agentVersion: $agentVersion}';
  }

  factory Peer.fromId(String peerId) {
    return Peer(
      id: p2p.PeerId(value: Base58().base58Decode(peerId)),
      addresses: [], // Empty list since we don't know addresses yet
      latency: 0, // Default latency
      agentVersion: '', // Empty version since we don't know it yet
    );
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

      final peerId =
          p2p.PeerId(value: Base58().base58Decode(parts[peerIdIndex]));

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
p2p.FullAddress? parseMultiaddrString(String multiaddrString) {
  try {
    final uri = Uri.parse(multiaddrString);
    final protocol = uri.scheme;
    final host = uri.host;
    final port = uri.port;

    // Validate the protocol and port
    if (protocol != 'ip4' && protocol != 'ip6') {
      return null; // or throw an exception for invalid protocol
    }
    if (port == 0) {
      return null; // or throw an exception for invalid port
    }

    // Create the InternetAddress object
    final ipAddress = InternetAddress(host);

    // Create the FullAddress object
    return p2p.FullAddress(address: ipAddress, port: port);
  } catch (e) {
    // Handle any parsing errors
    print('Error parsing multiaddr string: $e');
    return null; // or throw an exception
  }
}
