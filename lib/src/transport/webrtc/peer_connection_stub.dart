import 'peer_connection.dart';

/// Factory for creating the platform-specific [PeerConnection].
PeerConnection createPC(List<String> iceServers) =>
    throw UnsupportedError('Cannot create PeerConnection');
