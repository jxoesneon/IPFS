import 'dart:async';

import 'data_channel_stream.dart';
import 'peer_connection.dart';

/// Stub implementation of [PeerConnection] for non-supported platforms.
class PeerConnectionStub implements PeerConnection {
  /// Creates a new [PeerConnectionStub].
  PeerConnectionStub(List<String> iceServers);

  @override
  Stream<RTCIceCandidateInit> get onIceCandidate => throw UnimplementedError();

  @override
  Stream<DataChannelStream> get onDataChannel => throw UnimplementedError();

  @override
  String? get localDescriptionSdp => throw UnimplementedError();

  @override
  String? get remoteDescriptionSdp => throw UnimplementedError();

  @override
  Future<RTCSessionDescriptionInit> createOffer() => throw UnimplementedError();

  @override
  Future<RTCSessionDescriptionInit> createAnswer() =>
      throw UnimplementedError();

  @override
  Future<void> setLocalDescription(RTCSessionDescriptionInit description) =>
      throw UnimplementedError();

  @override
  Future<void> setRemoteDescription(String type, String sdp) =>
      throw UnimplementedError();

  @override
  Future<void> addIceCandidate(RTCIceCandidateInit candidate) =>
      throw UnimplementedError();

  @override
  Future<DataChannelStream> createDataChannel(String label) =>
      throw UnimplementedError();

  @override
  Future<void> close() => throw UnimplementedError();
}

/// Factory for creating a [PeerConnectionStub].
PeerConnection createPC(List<String> iceServers) =>
    PeerConnectionStub(iceServers);
