// lib/src/transport/pnet/pnet_transport_wrapper.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:ipfs_libp2p/core/multiaddr.dart';
import 'package:ipfs_libp2p/core/network/transport_conn.dart';
import 'package:ipfs_libp2p/p2p/transport/listener.dart';
import 'package:ipfs_libp2p/p2p/transport/transport.dart';
import 'package:ipfs_libp2p/p2p/transport/transport_config.dart';

import 'pnet_listener.dart';
import 'pnet_transport_conn.dart';

/// A [Transport] wrapper that upgrades every TCP connection with the libp2p
/// private-network (PNET) nonce handshake and XSalsa20 stream encryption.
///
/// The wrapper delegates transport discovery ([protocols], [canDial], [canListen])
/// and lifecycle ([dispose]) to the inner transport, while returning
/// [PnetTransportConn] instances from [dial] and [PnetListener] instances from
/// [listen].
class PnetTransportWrapper implements Transport {
  /// Creates a PNET transport wrapping [inner] with the given [psk].
  ///
  /// [psk] must be a 32-byte pre-shared key.
  PnetTransportWrapper({required this.inner, required this.psk});

  /// The underlying transport (typically TCP).
  final Transport inner;

  /// The 32-byte pre-shared key.
  final Uint8List psk;

  @override
  TransportConfig get config => inner.config;

  @override
  Future<TransportConn> dial(MultiAddr addr, {Duration? timeout}) async {
    final rawConn = await inner.dial(addr, timeout: timeout);
    final transportConn = rawConn is TransportConn
        ? rawConn
        : throw StateError(
            'PnetTransportWrapper can only wrap transports that return '
            'TransportConn instances',
          );
    return PnetTransportConn.create(transportConn, psk, isInitiator: true);
  }

  @override
  Future<Listener> listen(MultiAddr addr) async {
    final rawListener = await inner.listen(addr);
    return PnetListener(rawListener, psk);
  }

  @override
  List<String> get protocols => inner.protocols;

  @override
  bool canDial(MultiAddr addr) => inner.canDial(addr);

  @override
  bool canListen(MultiAddr addr) => inner.canListen(addr);

  @override
  Future<void> dispose() => inner.dispose();
}
