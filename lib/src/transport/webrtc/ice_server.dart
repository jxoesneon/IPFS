// lib/src/transport/webrtc/ice_server.dart
import 'package:dart_ipfs/src/core/config/network_config.dart';

/// A generic WebRTC ICE server configuration.
///
/// Supports both STUN and TURN entries. For TURN servers, [username] and
/// [credential] are provided separately so the underlying platform-specific
/// implementation can pass them to the browser/native peer connection.
class IceServer {
  /// Creates a new [IceServer].
  const IceServer({
    required this.urls,
    this.username,
    this.credential,
  });

  /// Creates a STUN-only ICE server from a URL string such as
  /// `stun:stun.example.com:19302`.
  factory IceServer.fromStun(String url) => IceServer(urls: url);

  /// Creates a TURN ICE server from a [TurnServer] configuration.
  factory IceServer.fromTurn(TurnServer server) => IceServer(
        urls: server.url,
        username: server.username,
        credential: server.credential,
      );

  /// The ICE server URL, e.g. `stun:stun.example.com:19302` or
  /// `turn:turn.example.com:3478`.
  final String urls;

  /// Optional username for TURN authentication.
  final String? username;

  /// Optional credential (password) for TURN authentication.
  final String? credential;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IceServer &&
          other.urls == urls &&
          other.username == username &&
          other.credential == credential;

  @override
  int get hashCode => Object.hash(urls, username, credential);
}

/// Builds a list of [IceServer] entries from a [NetworkConfig].
///
/// If no STUN/TURN servers are configured, the returned list is empty so that
/// transports do not fall back to a hardcoded production server.
List<IceServer> buildIceServersFromNetworkConfig(NetworkConfig config) {
  final servers = <IceServer>[];
  for (final url in config.stunServers) {
    servers.add(IceServer.fromStun(url));
  }
  for (final turn in config.turnServers) {
    servers.add(IceServer.fromTurn(turn));
  }
  return servers;
}
