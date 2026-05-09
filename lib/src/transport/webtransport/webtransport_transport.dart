import 'dart:async';
import 'dart:typed_data';
import 'package:ipfs_libp2p/dart_libp2p.dart' as libp2p;
import 'package:ipfs_libp2p/p2p/transport/transport.dart' as libp2p_trans;
import 'package:ipfs_libp2p/p2p/transport/listener.dart' as libp2p_listener;
import 'package:ipfs_libp2p/p2p/transport/transport_config.dart' as libp2p_config;
import 'webtransport_dialer.dart';
import 'webtransport_listener.dart';

/// WebTransport implementation of libp2p Transport.
class WebTransportTransport implements libp2p_trans.Transport {
  final WebTransportDialer _dialer = WebTransportDialer();

  WebTransportTransport();

  @override
  libp2p_config.TransportConfig get config => libp2p_config.TransportConfig();

  @override
  bool canDial(libp2p.MultiAddr addr) {
    return addr.toString().contains('/quic-v1/webtransport');
  }

  @override
  bool canListen(libp2p.MultiAddr addr) {
    return canDial(addr);
  }

  @override
  Future<libp2p.Conn> dial(libp2p.MultiAddr addr, {Duration? timeout}) async {
    return _dialer.dial(addr);
  }

  @override
  Future<libp2p_listener.Listener> listen(libp2p.MultiAddr addr) async {
    final listener = WebTransportListener(addr);
    await listener.listen();
    return listener;
  }

  @override
  List<String> get protocols => ['/quic-v1/webtransport'];

  @override
  Future<void> dispose() async {}
}

class WebTransportConnection implements libp2p.Conn {
  final libp2p.MultiAddr _localAddr;
  final libp2p.MultiAddr _remoteAddr;
  final libp2p.PeerId _localPeer;
  final libp2p.PeerId _remotePeer;

  WebTransportConnection(this._localAddr, this._remoteAddr, this._localPeer, this._remotePeer);

  @override
  libp2p.PeerId get localPeer => _localPeer;

  @override
  libp2p.PeerId get remotePeer => _remotePeer;

  @override
  libp2p.MultiAddr get localMultiaddr => _localAddr;

  @override
  libp2p.MultiAddr get remoteMultiaddr => _remoteAddr;

  @override
  Future<libp2p.P2PStream<Uint8List>> newStream(libp2p.Context context) async {
    throw UnimplementedError();
  }

  @override
  Future<List<libp2p.P2PStream>> get streams => Future.value([]);

  @override
  Future<void> close() async {}

  @override
  bool get isClosed => false;

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
    streamMultiplexer: '/quic/1.0.0',
    security: '/quic/1.0.0',
    transport: 'webtransport',
    usedEarlyMuxerNegotiation: true,
  );
}
