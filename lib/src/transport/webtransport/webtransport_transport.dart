import 'dart:async';

import 'package:ipfs_libp2p/dart_libp2p.dart' as libp2p;
import 'package:ipfs_libp2p/p2p/transport/listener.dart' as libp2p_listener;
import 'package:ipfs_libp2p/p2p/transport/transport.dart' as libp2p_trans;
import 'package:ipfs_libp2p/p2p/transport/transport_config.dart'
    as libp2p_config;

import 'webtransport_dialer.dart';
import 'webtransport_listener.dart';

/// WebTransport transport implementation for libp2p.
class WebTransportTransport implements libp2p_trans.Transport {
  /// Creates a new [WebTransportTransport].
  WebTransportTransport();

  @override
  libp2p_config.TransportConfig get config => libp2p_config.TransportConfig();

  @override
  bool canDial(libp2p.MultiAddr addr) {
    return addr.toString().contains('/webtransport');
  }

  @override
  bool canListen(libp2p.MultiAddr addr) {
    return canDial(addr);
  }

  @override
  Future<libp2p.Conn> dial(libp2p.MultiAddr addr, {Duration? timeout}) async {
    final dialer = createWebTransportDialer();
    final dialTimeout = timeout ?? const Duration(seconds: 30);
    return dialer.dial(addr).timeout(dialTimeout);
  }

  @override
  Future<libp2p_listener.Listener> listen(libp2p.MultiAddr addr) async {
    return WebTransportListener(addr);
  }

  @override
  List<String> get protocols => const ['/webtransport'];

  @override
  Future<void> dispose() async {}
}
