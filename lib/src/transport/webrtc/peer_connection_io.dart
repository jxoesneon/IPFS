import 'dart:async';

import '../../core/errors/transport_errors.dart';
import 'data_channel_stream.dart';
import 'ice_server.dart';
import 'peer_connection.dart';

/// IO implementation of [PeerConnection].
///
/// WebRTC relies on browser APIs and has no IO backend, so operations that
/// require a real peer connection throw [TransportUnavailableException].
class PeerConnectionIO implements PeerConnection {
  /// Creates a new [PeerConnectionIO].
  PeerConnectionIO(List<IceServer> iceServers);

  @override
  Stream<RTCIceCandidateInit> get onIceCandidate => const Stream.empty();

  @override
  Stream<DataChannelStream> get onDataChannel => const Stream.empty();

  @override
  String? get localDescriptionSdp =>
      throw TransportUnavailableException.forPlatform('WebRTC', 'IO');

  @override
  String? get remoteDescriptionSdp =>
      throw TransportUnavailableException.forPlatform('WebRTC', 'IO');

  @override
  String? get iceConnectionState => null;

  @override
  String? get signalingState => null;

  @override
  Future<RTCSessionDescriptionInit> createOffer() =>
      throw TransportUnavailableException.forPlatform('WebRTC', 'IO');

  @override
  Future<RTCSessionDescriptionInit> createAnswer() =>
      throw TransportUnavailableException.forPlatform('WebRTC', 'IO');

  @override
  Future<void> setLocalDescription(RTCSessionDescriptionInit description) =>
      throw TransportUnavailableException.forPlatform('WebRTC', 'IO');

  @override
  Future<void> setRemoteDescription(String type, String sdp) =>
      throw TransportUnavailableException.forPlatform('WebRTC', 'IO');

  @override
  Future<void> addIceCandidate(RTCIceCandidateInit candidate) =>
      throw TransportUnavailableException.forPlatform('WebRTC', 'IO');

  @override
  Future<DataChannelStream> createDataChannel(String label) =>
      throw TransportUnavailableException.forPlatform('WebRTC', 'IO');

  @override
  Future<void> close() =>
      throw TransportUnavailableException.forPlatform('WebRTC', 'IO');
}

/// Factory for creating a [PeerConnectionIO].
PeerConnection createPC(List<IceServer> iceServers) =>
    PeerConnectionIO(iceServers);
