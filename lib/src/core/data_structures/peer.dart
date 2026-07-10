// src/core/data_structures/peer.dart
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';

import '../../proto/generated/core/peer.pb.dart';
import '../../utils/base58.dart';
import '../types/peer_id.dart';

/// Represents a network address (IP + Port).
/// Replaces p2plib.FullAddress.
class FullAddress {
  /// Creates a [FullAddress] with the given [address] and [port].
  const FullAddress({required this.address, required this.port});

  /// The IP address of the peer (string representation).
  final String address;

  /// The port number of the peer.
  final int port;

  @override
  String toString() => '/ip4/$address/tcp/$port';
}

/// Represents a peer node in the IPFS network.
///
/// A Peer encapsulates information about a remote IPFS node, including
/// its cryptographic identity, network addresses, latency metrics, and
/// client version information.
class Peer {
  /// Creates a new Peer with the given properties.
  ///
  /// @param id The peer ID.
  /// @param addresses List of available network addresses.
  /// @param latency Latency in milliseconds.
  /// @param agentVersion The client agent version string.
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

      // The peer ID is the component after '/p2p/'
      final p2pIndex = parts.indexOf('p2p');
      if (p2pIndex == -1 || p2pIndex + 1 >= parts.length) {
        throw FormatException('No peer ID found in multiaddr: $multiaddr');
      }

      final peerIdStr = parts[p2pIndex + 1];
      if (peerIdStr.isEmpty) {
        throw FormatException('Empty peer ID in multiaddr: $multiaddr');
      }
      final peerId = PeerId(value: Base58().base58Decode(peerIdStr));

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
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('Error parsing multiaddr: $e');
    }
  }
}

/// Helper function to parse a multiaddr string into a FullAddress.
FullAddress? parseMultiaddrString(String multiaddrString) {
  try {
    // Basic support for /ip4/<ip>/tcp/<port> or /ip6/<ip>/tcp/<port>
    final parts = multiaddrString.split('/');
    if (parts.length < 5) return null;

    final protocol = parts[1];
    final host = parts[2];
    final transport = parts[3];
    final portStr = parts[4];

    if (protocol != 'ip4' && protocol != 'ip6') return null;
    if (transport != 'tcp' && transport != 'udp') return null;

    // Basic IP validation
    if (protocol == 'ip4') {
      final ipParts = host.split('.');
      if (ipParts.length != 4) return null;
      for (final part in ipParts) {
        final val = int.tryParse(part);
        if (val == null || val < 0 || val > 255) return null;
      }
    } else if (protocol == 'ip6') {
      if (!host.contains(':') && host != '::1') return null;
      // Simple validation for IPv6
    }

    final port = int.tryParse(portStr);
    if (port == null || port <= 0 || port > 65535) return null;

    return FullAddress(address: host, port: port);
  } catch (e) {
    return null;
  }
}

/// Helper to decode binary multiaddr to FullAddress
FullAddress? multiaddrFromBytes(Uint8List bytes) {
  try {
    var offset = 0;
    // Protocol code 1
    final p1 = bytes[offset++];

    String? ip;
    int? port;

    if (p1 == 4) {
      // ip4
      if (bytes.length < offset + 4) return null;
      ip = bytes.sublist(offset, offset + 4).join('.');
      offset += 4;
    } else if (p1 == 41) {
      // ip6
      if (bytes.length < offset + 16) return null;
      // Simple hex conversion for IPv6
      final hex = bytes
          .sublist(offset, offset + 16)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .toList();
      final groups = <String>[];
      for (var i = 0; i < 16; i += 2) {
        groups.add('${hex[i]}${hex[i + 1]}');
      }
      ip = groups.join(':');
      if (ip == '0000:0000:0000:0000:0000:0000:0000:0001') ip = '::1';
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
  final buffer = <int>[];
  if (address.address.contains('.')) {
    // IPv4
    buffer.add(4); // ip4
    buffer.addAll(address.address.split('.').map(int.parse));
  } else if (address.address.contains(':') || address.address == '::1') {
    // IPv6
    buffer.add(41); // ip6

    // Handle special cases like ::1
    String expanded = address.address;
    if (expanded == '::1') {
      expanded = '0000:0000:0000:0000:0000:0000:0000:0001';
    } else if (expanded.contains('::')) {
      // Simple expansion for ::
      final parts = expanded.split('::');
      final left = parts[0].isEmpty ? <String>[] : parts[0].split(':');
      final right = parts[1].isEmpty ? <String>[] : parts[1].split(':');
      final missing = 8 - (left.length + right.length);
      final mid = List.filled(missing, '0000');
      expanded = (left + mid + right).join(':');
    }

    final groups = expanded.split(':');
    for (final group in groups) {
      final val = int.parse(group.isEmpty ? '0' : group, radix: 16);
      buffer.add((val >> 8) & 0xFF);
      buffer.add(val & 0xFF);
    }
  } else {
    return Uint8List(0); // Unsupported
  }

  // Assuming TCP (6) by default for FullAddress as we don't have protocol field
  buffer.add(6); // tcp
  buffer.add((address.port >> 8) & 0xFF);
  buffer.add(address.port & 0xFF);

  return Uint8List.fromList(buffer);
}
