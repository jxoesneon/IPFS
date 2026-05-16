import 'dart:async';

import 'data_channel_stream.dart';
import 'peer_connection.dart';

/// IO implementation of [PeerConnection] (stub for now).
class PeerConnectionIO implements PeerConnection {
  /// Creates a new [PeerConnectionIO].
  PeerConnectionIO(List<String> iceServers);

  @override
  Stream<RTCIceCandidateInit> get onIceCandidate => const Stream.empty();


  @override
  Stream<DataChannelStream> get onDataChannel => const Stream.empty();

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

/// Factory for creating a [PeerConnectionIO].
PeerConnection createPC(List<String> iceServers) =>
    PeerConnectionIO(iceServers);
