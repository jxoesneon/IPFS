import 'dart:async';
import 'data_channel_stream.dart';
import 'peer_connection_stub.dart'
    if (dart.library.js_interop) 'peer_connection_web.dart'
    if (dart.library.io) 'peer_connection_io.dart';

abstract class PeerConnection {
  Future<void> setRemoteDescription(String type, String sdp);
  Future<RTCSessionDescriptionInit> createOffer();
  Future<RTCSessionDescriptionInit> createAnswer();
  Future<void> setLocalDescription(RTCSessionDescriptionInit description);
  Future<void> addIceCandidate(RTCIceCandidateInit candidate);

  Stream<RTCIceCandidateInit> get onIceCandidate;
  Stream<DataChannelStream> get onDataChannel;

  Future<DataChannelStream> createDataChannel(String label);
  Future<void> close();

  String? get localDescriptionSdp;
  String? get remoteDescriptionSdp;
}

class RTCSessionDescriptionInit {
  final String type;
  final String sdp;
  RTCSessionDescriptionInit(this.type, this.sdp);
}

class RTCIceCandidateInit {
  final String candidate;
  final String? sdpMid;
  final int? sdpMLineIndex;
  RTCIceCandidateInit(this.candidate, this.sdpMid, this.sdpMLineIndex);

  Map<String, dynamic> toJson() => {
    'candidate': candidate,
    'sdpMid': sdpMid,
    'sdpMLineIndex': sdpMLineIndex,
  };
}

PeerConnection createPeerConnection(List<String> iceServers) =>
    createPC(iceServers);
