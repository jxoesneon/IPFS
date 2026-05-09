import 'dart:async';

import 'package:ipfs_libp2p/dart_libp2p.dart' as libp2p;
import 'package:ipfs_libp2p/p2p/transport/listener.dart' as libp2p_listener;

/// WebTransport listener implementation (stub for now, as browsers only dial).
class WebTransportListener implements libp2p_listener.Listener {
  /// Creates a new [WebTransportListener].
  WebTransportListener(this._addr);

  final libp2p.MultiAddr _addr;
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
      addr.toString().contains('/webtransport');
}
