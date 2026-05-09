import 'dart:async';
import 'dart:typed_data';
import 'package:ipfs_libp2p/dart_libp2p.dart' as libp2p;
import 'package:ipfs_libp2p/p2p/transport/transport.dart' as libp2p_trans;
import 'package:ipfs_libp2p/p2p/transport/listener.dart' as libp2p_listener;
import 'package:ipfs_libp2p/p2p/transport/transport_config.dart'
    as libp2p_config;
import 'peer_connection.dart';
import 'signaling_protocol.dart';
import 'data_channel_stream.dart';

/// WebRTC transport implementation for libp2p.
class WebRTCTransport implements libp2p_trans.Transport {
  /// Creates a new [WebRTCTransport].
  WebRTCTransport({this.host});

  /// The libp2p host associated with this transport.
  libp2p.Host? host;

  @override
  libp2p_config.TransportConfig get config => libp2p_config.TransportConfig();

  @override
  bool canDial(libp2p.MultiAddr addr) {
    final addrStr = addr.toString();
    return addrStr.contains('/webrtc') && !addrStr.contains('/webrtc-direct');
  }

  @override
  bool canListen(libp2p.MultiAddr addr) {
    return canDial(addr);
  }

  @override
  Future<libp2p.Conn> dial(libp2p.MultiAddr addr, {Duration? timeout}) async {
    final currentHost = host;
    if (currentHost == null) {
      throw Exception('Host required for WebRTC relay dialing');
    }

    // addr: /ip4/RELAY_IP/udp/RELAY_PORT/quic-v1/webtransport/p2p/RELAY_ID/p2p-circuit/webrtc/p2p/REMOTE_ID
    final addrStr = addr.toString();
    final p2pCircuitIndex = addrStr.indexOf('/p2p-circuit');
    if (p2pCircuitIndex == -1) {
      throw Exception('Invalid WebRTC multiaddr: missing /p2p-circuit');
    }

    final relayAddr = libp2p.MultiAddr(addrStr.substring(0, p2pCircuitIndex));
    final remotePeerIdStr = addrStr.split('/p2p/').last;
    final remotePeerId = libp2p.PeerId.fromString(remotePeerIdStr);

    // 1. Connect to relay
    final dialTimeout = timeout ?? const Duration(seconds: 30);
    await currentHost
        .connect(libp2p.AddrInfo(await libp2p.PeerId.random(), [relayAddr]))
        .timeout(dialTimeout);

    // 2. Open signaling stream to remote peer via relay
    final context = libp2p.Context(timeout: dialTimeout);
    final signalingStream = await currentHost.newStream(remotePeerId, [
      SignalingProtocol.id,
    ], context);

    final signaling = SignalingProtocol();
    signaling.handleStream(signalingStream as libp2p.P2PStream<Uint8List>);

    // 3. Setup WebRTC PeerConnection
    final pc = createPeerConnection(const ['stun:stun.l.google.com:19302']);

    final completer = Completer<libp2p.Conn>();

    pc.onIceCandidate.listen((candidate) {
      SignalingProtocol.sendMessage(
        signalingStream,
        SignalingMessage(SignalingMessageType.candidate, candidate.candidate),
      );
    });

    signaling.messages.listen((msg) async {
      if (msg.type == SignalingMessageType.answer) {
        await pc.setRemoteDescription('answer', msg.data);
      } else if (msg.type == SignalingMessageType.candidate) {
        await pc.addIceCandidate(RTCIceCandidateInit(msg.data, null, null));
      }
    });

    // 4. Create Offer
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    await SignalingProtocol.sendMessage(
      signalingStream,
      SignalingMessage(SignalingMessageType.offer, offer.sdp),
    );

    // Wait for data channel
    pc.onDataChannel.listen((DataChannelStream channel) {
      if (!completer.isCompleted) {
        completer.complete(
          WebRTCConnection(pc, channel, addr, currentHost.id, remotePeerId),
        );
      }
    });

    return completer.future.timeout(dialTimeout);
  }

  @override
  Future<libp2p_listener.Listener> listen(libp2p.MultiAddr addr) async {
    // Browsers don't listen directly for WebRTC p2p, they reserve on relay
    return WebRTCListener(addr, host);
  }

  @override
  List<String> get protocols => const ['/webrtc'];

  @override
  Future<void> dispose() async {
    // Cleanup if needed
  }
}

/// WebRTC connection implementation for libp2p.
class WebRTCConnection implements libp2p.Conn {
  /// Creates a new [WebRTCConnection].
  WebRTCConnection(
    this._pc,
    this._baseChannel,
    this._remoteAddr,
    this._localPeer,
    this._remotePeer,
  );

  final PeerConnection _pc;
  // ignore: unused_field
  final DataChannelStream _baseChannel;
  final libp2p.MultiAddr _remoteAddr;
  final libp2p.PeerId _localPeer;
  final libp2p.PeerId _remotePeer;

  @override
  libp2p.PeerId get localPeer => _localPeer;

  @override
  libp2p.PeerId get remotePeer => _remotePeer;

  @override
  libp2p.MultiAddr get localMultiaddr => libp2p.MultiAddr('/webrtc');

  @override
  libp2p.MultiAddr get remoteMultiaddr => _remoteAddr;

  @override
  Future<libp2p.P2PStream<Uint8List>> newStream(libp2p.Context context) async {
    // In libp2p WebRTC, we create new DataChannels for each stream
    final channel = await _pc.createDataChannel('stream');
    return channel;
  }

  @override
  Future<List<libp2p.P2PStream<Uint8List>>> get streams => Future.value([]);

  @override
  Future<void> close() async {
    await _pc.close();
  }

  @override
  bool get isClosed => false; // Implement proper check if needed

  @override
  libp2p.ConnStats get stat => throw UnimplementedError();

  @override
  libp2p.ConnScope get scope => throw UnimplementedError();

  @override
  String get id => _remotePeer.toString();

  @override
  Future<libp2p.PublicKey?> get remotePublicKey => Future.value(null);

  @override
  libp2p.ConnState get state => libp2p.ConnState(
    streamMultiplexer: '/webrtc/1.0.0',
    security: '/webrtc/1.0.0',
    transport: 'webrtc',
    usedEarlyMuxerNegotiation: true,
  );
}

/// WebRTC listener implementation for libp2p.
class WebRTCListener implements libp2p_listener.Listener {
  /// Creates a new [WebRTCListener].
  WebRTCListener(this._addr, this._host) {
    final currentHost = _host;
    if (currentHost != null) {
      currentHost.setStreamHandler(SignalingProtocol.id, (
        stream,
        remotePeerId,
      ) async {
        final signaling = SignalingProtocol();
        signaling.handleStream(stream as libp2p.P2PStream<Uint8List>);

        final pc = createPeerConnection(const ['stun:stun.l.google.com:19302']);

        pc.onIceCandidate.listen((candidate) {
          SignalingProtocol.sendMessage(
            stream,
            SignalingMessage(
              SignalingMessageType.candidate,
              candidate.candidate,
            ),
          );
        });

        signaling.messages.listen((msg) async {
          if (msg.type == SignalingMessageType.offer) {
            await pc.setRemoteDescription('offer', msg.data);
            final answer = await pc.createAnswer();
            await pc.setLocalDescription(answer);
            await SignalingProtocol.sendMessage(
              stream,
              SignalingMessage(SignalingMessageType.answer, answer.sdp),
            );
          } else if (msg.type == SignalingMessageType.candidate) {
            await pc.addIceCandidate(RTCIceCandidateInit(msg.data, null, null));
          }
        });

        pc.onDataChannel.listen((DataChannelStream channel) {
          _connController.add(
            WebRTCConnection(
                  pc,
                  channel,
                  stream.conn.remoteMultiaddr,
                  currentHost.id,
                  stream.conn.remotePeer,
                )
                as libp2p.TransportConn,
          );
        });
      });
    }
  }

  final libp2p.MultiAddr _addr;
  final libp2p.Host? _host;
  final StreamController<libp2p.TransportConn> _connController =
      StreamController.broadcast();

  @override
  Future<void> close() async {
    await _connController.close();
  }

  @override
  libp2p.MultiAddr get addr => _addr;

  @override
  Stream<libp2p.TransportConn> get connectionStream => _connController.stream;

  @override
  Future<libp2p.TransportConn?> accept() async {
    return null;
  }

  @override
  bool get isClosed => _connController.isClosed;

  @override
  bool supportsAddr(libp2p.MultiAddr addr) =>
      addr.toString().contains('/webrtc');
}
