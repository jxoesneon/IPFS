import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'peer_connection.dart';
import 'data_channel_stream.dart';

class PeerConnectionWeb implements PeerConnection {
  final web.RTCPeerConnection _pc;
  final StreamController<RTCIceCandidateInit> _iceController = StreamController.broadcast();
  final StreamController<DataChannelStream> _dataChannelController = StreamController.broadcast();

  PeerConnectionWeb(List<String> iceServers)
      : _pc = web.RTCPeerConnection(web.RTCConfiguration(
          iceServers: iceServers.map((s) {
            return web.RTCIceServer(urls: s.toJS);
          }).toList().toJS as JSArray<web.RTCIceServer>,
        )) {
    _pc.onicecandidate = ((web.RTCPeerConnectionIceEvent ev) {
      if (ev.candidate != null) {
        _iceController.add(RTCIceCandidateInit(
          ev.candidate!.candidate,
          ev.candidate!.sdpMid,
          ev.candidate!.sdpMLineIndex,
        ));
      }
    }).toJS;

    _pc.ondatachannel = ((web.RTCDataChannelEvent ev) {
      _dataChannelController.add(_WebDataChannelStream(ev.channel, incoming: true));
    }).toJS;
  }

  @override
  Stream<RTCIceCandidateInit> get onIceCandidate => _iceController.stream;

  @override
  Stream<DataChannelStream> get onDataChannel => _dataChannelController.stream;

  @override
  String? get localDescriptionSdp => _pc.localDescription?.sdp;

  @override
  String? get remoteDescriptionSdp => _pc.remoteDescription?.sdp;

  @override
  Future<RTCSessionDescriptionInit> createOffer() async {
    final offer = await _pc.createOffer().toDart;
    return RTCSessionDescriptionInit(offer!.type.toString(), offer!.sdp);
  }

  @override
  Future<RTCSessionDescriptionInit> createAnswer() async {
    final answer = await _pc.createAnswer().toDart;
    return RTCSessionDescriptionInit(answer!.type.toString(), answer!.sdp);
  }

  @override
  Future<void> setLocalDescription(RTCSessionDescriptionInit description) async {
    await _pc.setLocalDescription(web.RTCLocalSessionDescriptionInit(
      type: description.type as web.RTCSdpType,
      sdp: description.sdp,
    )).toDart;
  }

  @override
  Future<void> setRemoteDescription(String type, String sdp) async {
    await _pc.setRemoteDescription(web.RTCSessionDescriptionInit(
      type: type as web.RTCSdpType,
      sdp: sdp,
    )).toDart;
  }

  @override
  Future<void> addIceCandidate(RTCIceCandidateInit candidate) async {
    await _pc.addIceCandidate(web.RTCIceCandidateInit(
      candidate: candidate.candidate,
      sdpMid: candidate.sdpMid,
      sdpMLineIndex: candidate.sdpMLineIndex,
    )).toDart;
  }

  @override
  Future<DataChannelStream> createDataChannel(String label) async {
    final channel = _pc.createDataChannel(label);
    return _WebDataChannelStream(channel);
  }

  @override
  Future<void> close() async {
    _pc.close();
    await _iceController.close();
    await _dataChannelController.close();
  }
}

class _WebDataChannelStream extends DataChannelStream {
  final web.RTCDataChannel _channel;

  _WebDataChannelStream(this._channel, {bool incoming = false}) : super(incoming: incoming) {
    _channel.binaryType = 'arraybuffer';
    _channel.onmessage = ((web.MessageEvent ev) {
      final buffer = ev.data as JSArrayBuffer;
      onMessage(buffer.toDart.asUint8List());
    }).toJS;

    _channel.onclose = (() {
      onClosed();
    }).toJS;
    
    _channel.onerror = ((web.Event ev) {
      onClosed();
    }).toJS;
  }

  @override
  String get label => _channel.label;

  @override
  Future<void> write(Uint8List data) async {
    _channel.send(data.toJS);
  }

  @override
  Future<void> close() async {
    _channel.close();
    await super.close();
  }
}

PeerConnection createPC(List<String> iceServers) => PeerConnectionWeb(iceServers);
