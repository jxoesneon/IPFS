// lib/src/transport/webtransport/webtransport_dialer.dart
import 'dart:async';
import 'package:ipfs_libp2p/dart_libp2p.dart' as libp2p;
import 'webtransport_dialer_stub.dart'
    if (dart.library.js_interop) 'webtransport_dialer_web.dart'
    if (dart.library.io) 'webtransport_dialer_io.dart';

/// Abstract dialer for WebTransport connections.
abstract class WebTransportDialer {
  /// Dials a WebTransport multiaddr and returns a connection.
  Future<libp2p.Conn> dial(libp2p.MultiAddr addr);

  /// Factory for creating the platform-specific dialer.
  factory WebTransportDialer() => createDialer();
}
