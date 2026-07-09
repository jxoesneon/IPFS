import 'dart:async';

import 'package:ipfs_libp2p/core/multiaddr.dart' as libp2p;
import 'package:ipfs_libp2p/core/network/transport_conn.dart' as libp2p;
import 'package:ipfs_libp2p/p2p/transport/listener.dart' as libp2p;
import 'package:quic_lib/libp2p.dart' as quic_lib;

import 'quic_transport.dart';

/// libp2p [Listener] implementation that wraps a [quic_lib] incoming
/// connection stream.
class QuicListener implements libp2p.Listener {
  final Stream<quic_lib.Libp2pQuicConnection> _stream;
  final libp2p.MultiAddr _addr;
  final libp2p.MultiAddr _localAddr;
  StreamSubscription<quic_lib.Libp2pQuicConnection>? _subscription;
  final _pending = <quic_lib.Libp2pQuicConnection>[];
  final _pendingController = StreamController<libp2p.TransportConn>.broadcast();
  bool _closed = false;

  /// Creates a listener around [stream].
  QuicListener({
    required Stream<quic_lib.Libp2pQuicConnection> stream,
    required libp2p.MultiAddr addr,
    required libp2p.MultiAddr localAddr,
  })  : _stream = stream,
        _addr = addr,
        _localAddr = localAddr {
    _subscription = _stream.listen(
      (conn) {
        final adapter = QuicConnection(
          conn,
          localAddr: _localAddr,
          remoteAddr: _addr,
          isServer: true,
        );
        _pending.add(conn);
        _pendingController.add(adapter);
      },
      onError: (Object error) {
        _pendingController.addError(error);
      },
      onDone: () {
        if (!_pendingController.isClosed) {
          _pendingController.close();
        }
      },
    );
  }

  @override
  libp2p.MultiAddr get addr => _addr;

  @override
  Stream<libp2p.TransportConn> get connectionStream =>
      _pendingController.stream;

  @override
  bool get isClosed => _closed;

  @override
  Future<libp2p.TransportConn?> accept() async {
    if (_closed) return null;
    if (_pending.isNotEmpty) {
      final conn = _pending.removeAt(0);
      return QuicConnection(
        conn,
        localAddr: _localAddr,
        remoteAddr: _addr,
        isServer: true,
      );
    }
    try {
      final conn = await _stream.first;
      return QuicConnection(
        conn,
        localAddr: _localAddr,
        remoteAddr: _addr,
        isServer: true,
      );
    } on StateError {
      return null;
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _subscription?.cancel();
    _subscription = null;
    if (!_pendingController.isClosed) {
      await _pendingController.close();
    }
  }

  @override
  bool supportsAddr(libp2p.MultiAddr addr) {
    final hasIP = addr.hasProtocol('ip4') || addr.hasProtocol('ip6');
    final hasUDP = addr.hasProtocol('udp');
    final hasQuic = addr.hasProtocol('quic-v1') || addr.hasProtocol('quic');
    return hasIP && hasUDP && hasQuic;
  }
}
