import 'dart:async';

import '../../core/errors/transport_errors.dart';
import 'data_channel_stream.dart';
import 'ice_server.dart';
import 'peer_connection.dart';

/// Stub implementation of [PeerConnection] for non-supported platforms.
///
/// Every operation throws [TransportUnavailableException] since no WebRTC
/// backend exists on platforms without `dart:io` or `dart:js_interop`.
class PeerConnectionStub implements PeerConnection {
  /// Creates a new [PeerConnectionStub].
  PeerConnectionStub(List<IceServer> iceServers);

  @override
  Stream<RTCIceCandidateInit> get onIceCandidate =>
      throw TransportUnavailableException(
        'WebRTC is not available on this platform',
      );

  @override
  Stream<DataChannelStream> get onDataChannel =>
      throw TransportUnavailableException(
        'WebRTC is not available on this platform',
      );

  @override
  String? get localDescriptionSdp => throw TransportUnavailableException(
    'WebRTC is not available on this platform',
  );

  @override
  String? get remoteDescriptionSdp => throw TransportUnavailableException(
    'WebRTC is not available on this platform',
  );

  @override
  String? get iceConnectionState => null;

  @override
  String? get signalingState => null;

  @override
  Future<RTCSessionDescriptionInit> createOffer() =>
      throw TransportUnavailableException(
        'WebRTC is not available on this platform',
      );

  @override
  Future<RTCSessionDescriptionInit> createAnswer() =>
      throw TransportUnavailableException(
        'WebRTC is not available on this platform',
      );

  @override
  Future<void> setLocalDescription(RTCSessionDescriptionInit description) =>
      throw TransportUnavailableException(
        'WebRTC is not available on this platform',
      );

  @override
  Future<void> setRemoteDescription(String type, String sdp) =>
      throw TransportUnavailableException(
        'WebRTC is not available on this platform',
      );

  @override
  Future<void> addIceCandidate(RTCIceCandidateInit candidate) =>
      throw TransportUnavailableException(
        'WebRTC is not available on this platform',
      );

  @override
  Future<DataChannelStream> createDataChannel(String label) =>
      throw TransportUnavailableException(
        'WebRTC is not available on this platform',
      );

  @override
  Future<void> close() => throw TransportUnavailableException(
    'WebRTC is not available on this platform',
  );
}

/// Factory for creating a [PeerConnectionStub].
PeerConnection createPC(List<IceServer> iceServers) =>
    PeerConnectionStub(iceServers);
