// lib/src/transport/webtransport/webtransport_dialer_io.dart
import 'dart:async';
import 'package:ipfs_libp2p/dart_libp2p.dart' as libp2p;
import 'webtransport_dialer.dart';

/// Factory for IO-specific dialer.
WebTransportDialer createDialer() => WebTransportDialerIO();

/// IO-specific WebTransport dialer (placeholder).
class WebTransportDialerIO implements WebTransportDialer {
  @override
  Future<libp2p.Conn> dial(libp2p.MultiAddr addr) async {
    // Standard Dart/IO doesn't have a native WebTransport API yet.
    // This would likely use a package or FFI to a QUIC library.
    throw UnimplementedError('WebTransport IO dialer not implemented');
  }
}
