import 'dart:async';
import 'peer_connection.dart';
import 'data_channel_stream.dart';

class PeerConnectionIO implements PeerConnection {
  @override
  Future<void> addIceCandidate(RTCIceCandidateInit candidate) async {
    throw UnimplementedError('Native WebRTC not yet implemented');
  }

  @override
  Future<void> close() async {}

  @override
  Future<RTCSessionDescriptionInit> createAnswer() {
    throw UnimplementedError();
  }

  @override
  Future<DataChannelStream> createDataChannel(String label) {
    throw UnimplementedError();
  }

  @override
  Future<RTCSessionDescriptionInit> createOffer() {
    throw UnimplementedError();
  }

  @override
  String? get localDescriptionSdp => null;

  @override
  Stream<DataChannelStream> get onDataChannel => const Stream.empty();

  @override
  Stream<RTCIceCandidateInit> get onIceCandidate => const Stream.empty();

  @override
  String? get remoteDescriptionSdp => null;

  @override
  Future<void> setLocalDescription(
    RTCSessionDescriptionInit description,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<void> setRemoteDescription(String type, String sdp) async {
    throw UnimplementedError();
  }
}

PeerConnection createPC(List<String> iceServers) => PeerConnectionIO();
