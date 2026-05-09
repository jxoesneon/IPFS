import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:ipfs_libp2p/dart_libp2p.dart' as libp2p;
import 'package:ipfs_libp2p/p2p/transport/listener.dart' as libp2p_listener;
import 'package:ipfs_libp2p/p2p/transport/transport.dart' as libp2p_trans;
import 'package:ipfs_libp2p/p2p/transport/transport_config.dart'
    as libp2p_config;

import 'data_channel_stream.dart';
import 'peer_connection.dart';
import 'webrtc_transport.dart';

/// WebRTC Direct transport implementation for libp2p.
class WebRTCDirectTransport implements libp2p_trans.Transport {
  /// Creates a new [WebRTCDirectTransport].
  WebRTCDirectTransport();

  @override
  libp2p_config.TransportConfig get config =>
      const libp2p_config.TransportConfig();

  @override
  bool canDial(libp2p.MultiAddr addr) {
    return addr.toString().contains('/webrtc-direct');
  }

  @override
  bool canListen(libp2p.MultiAddr addr) {
    return false;
  }

  @override
  Future<libp2p.Conn> dial(libp2p.MultiAddr addr, {Duration? timeout}) async {
    // addr: /ip4/IP/udp/PORT/webrtc-direct/certhash/MH/p2p/PEER_ID
    final addrStr = addr.toString();
    final parts = addrStr.split('/');
    final ip = parts[parts.indexOf('ip4') + 1];
    final port = parts[parts.indexOf('udp') + 1];
    final peerIdStr = parts.last;
    final peerId = libp2p.PeerId.fromString(peerIdStr);

    final pc = createPeerConnection(const ['stun:stun.l.google.com:19302']);

    // Create offer
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);

    // Exchange SDP via HTTP POST to the server's UDP-over-HTTP port or dedicated endpoint
    final url = Uri.parse('http://$ip:$port/libp2p-webrtc');
    final response = await http.post(url, body: offer.sdp);

    if (response.statusCode != 200) {
      throw Exception('Failed to exchange SDP: ${response.statusCode}');
    }

    final answer = response.body;
    await pc.setRemoteDescription('answer', answer);

    final completer = Completer<libp2p.Conn>();

    pc.onDataChannel.listen((DataChannelStream channel) async {
      if (!completer.isCompleted) {
        completer.complete(
          WebRTCConnection(
            pc,
            channel,
            addr,
            await libp2p.PeerId.random(),
            peerId,
          ),
        );
      }
    });

    final dialTimeout = timeout ?? const Duration(seconds: 30);
    return completer.future.timeout(dialTimeout);
  }

  @override
  Future<libp2p_listener.Listener> listen(libp2p.MultiAddr addr) async {
    throw UnimplementedError(
      'WebRTCDirect listener only supported on native platforms',
    );
  }

  @override
  List<String> get protocols => const ['/webrtc-direct'];

  @override
  Future<void> dispose() async {}
}
