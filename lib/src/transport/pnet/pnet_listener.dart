// lib/src/transport/pnet/pnet_listener.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:ipfs_libp2p/core/multiaddr.dart';
import 'package:ipfs_libp2p/core/network/transport_conn.dart';
import 'package:ipfs_libp2p/p2p/transport/listener.dart';

import 'pnet_transport_conn.dart';

/// A [Listener] that wraps an underlying listener and applies the PNET
/// handshake to every accepted connection before returning it.
class PnetListener implements Listener {
  /// Creates a PNET-wrapped listener.
  ///
  /// [inner] is the listener whose connections will be upgraded.
  /// [psk] is the 32-byte pre-shared key used for the handshake.
  PnetListener(this.inner, this.psk);

  /// The underlying listener.
  final Listener inner;

  /// The 32-byte pre-shared key.
  final Uint8List psk;

  @override
  MultiAddr get addr => inner.addr;

  @override
  bool get isClosed => inner.isClosed;

  @override
  Stream<TransportConn> get connectionStream => inner.connectionStream.asyncMap(
    (conn) => PnetTransportConn.create(conn, psk, isInitiator: false),
  );

  @override
  Future<TransportConn?> accept() async {
    final conn = await inner.accept();
    if (conn == null) return null;
    return PnetTransportConn.create(conn, psk, isInitiator: false);
  }

  @override
  Future<void> close() => inner.close();

  @override
  bool supportsAddr(MultiAddr addr) => inner.supportsAddr(addr);
}
