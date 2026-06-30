import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:ipfs_libp2p/core/multiaddr.dart' as libp2p;
import 'package:ipfs_libp2p/core/network/conn.dart' as libp2p;
import 'package:ipfs_libp2p/core/network/transport_conn.dart' as libp2p;
import 'package:ipfs_libp2p/core/network/rcmgr.dart' as libp2p;
import 'package:ipfs_libp2p/core/network/common.dart' as libp2p;
import 'package:ipfs_libp2p/core/network/context.dart' as libp2p;
import 'package:ipfs_libp2p/core/network/stream.dart' as libp2p;
import 'package:ipfs_libp2p/core/peer/peer_id.dart' as libp2p;
import 'package:ipfs_libp2p/core/crypto/keys.dart' as libp2p;
import 'package:ipfs_libp2p/p2p/transport/listener.dart' as libp2p;
import 'package:ipfs_libp2p/p2p/transport/transport.dart' as libp2p;
import 'package:ipfs_libp2p/p2p/transport/transport_config.dart' as libp2p;
import 'package:quic_lib/quic_lib.dart' as quic_lib;
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';

import 'quic_listener.dart';
import 'quic_p2p_stream.dart';

final _log = Logger('QuicTransport');

/// libp2p [Transport] implementation backed by the pure-Dart [quic_lib]
/// package.
///
/// This adapter lets [Libp2pRouter] register a QUIC transport, advertise
/// `/udp/.../quic-v1` listen addresses, and dial/accept QUIC connections
/// without requiring native FFI libraries.
class QuicTransport implements libp2p.Transport {
  static const _supportedProtocols = [
    '/ip4/udp/quic-v1',
    '/ip6/udp/quic-v1',
  ];

  final quic_lib.Libp2pQuicTransport _delegate;
  bool _closed = false;

  @override
  final libp2p.TransportConfig config;

  /// Creates a new QUIC transport.
  ///
  /// [config] defaults to [libp2p.TransportConfig.defaultConfig].
  QuicTransport({libp2p.TransportConfig? config})
      : config = config ?? libp2p.TransportConfig.defaultConfig,
        _delegate = quic_lib.Libp2pQuicTransport();

  @override
  List<String> get protocols => _supportedProtocols;

  @override
  bool canDial(libp2p.MultiAddr addr) => _isQuicAddr(addr);

  @override
  bool canListen(libp2p.MultiAddr addr) => _isQuicAddr(addr);

  static bool _isQuicAddr(libp2p.MultiAddr addr) {
    final hasIP = addr.hasProtocol('ip4') || addr.hasProtocol('ip6');
    final hasUDP = addr.hasProtocol('udp');
    final hasQuic = addr.hasProtocol('quic-v1');
    final hasCircuit = addr.hasProtocol('p2p-circuit');
    return hasIP && hasUDP && hasQuic && !hasCircuit;
  }

  @override
  Future<libp2p.TransportConn> dial(libp2p.MultiAddr addr,
      {Duration? timeout}) async {
    if (_closed) {
      throw StateError('QuicTransport is closed');
    }
    _log.fine('Dialing QUIC address $addr');

    final quicAddr = quic_lib.Multiaddr.parse(addr.toString());
    final conn = await _delegate.dial(quicAddr);

    return QuicConnection(
      conn,
      localAddr: _toIpfsMultiaddr(quicAddr),
      remoteAddr: addr,
      isServer: false,
    );
  }

  @override
  Future<libp2p.Listener> listen(libp2p.MultiAddr addr) async {
    if (_closed) {
      throw StateError('QuicTransport is closed');
    }
    _log.fine('Listening on QUIC address $addr');

    final quicAddr = quic_lib.Multiaddr.parse(addr.toString());
    final stream = await _delegate.listen(quicAddr);

    return QuicListener(
      stream: stream,
      addr: addr,
      localAddr: addr,
    );
  }

  @override
  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    await _delegate.close();
  }

  /// Converts a [quic_lib.Multiaddr] to a [libp2p.MultiAddr].
  static libp2p.MultiAddr _toIpfsMultiaddr(quic_lib.Multiaddr addr) {
    return libp2p.MultiAddr(addr.toString());
  }
}

/// Adapter implementing [libp2p.TransportConn] around a [quic_lib]
/// [Libp2pQuicConnection].
///
/// This is a foundation-level implementation. The QUIC handshake and stream
/// multiplexing are handled internally by [quic_lib]; this adapter exposes the
/// connection lifecycle and metadata required by the libp2p transport
/// interface.
class QuicConnection implements libp2p.TransportConn {
  final quic_lib.Libp2pQuicConnection _delegate;
  final libp2p.MultiAddr _localAddr;
  final libp2p.MultiAddr _remoteAddr;
  final bool _isServer;
  final String _id;
  final libp2p.PeerId _localPeer;
  bool _closed = false;

  static libp2p.PeerId _placeholderPeerId() {
    // Placeholder identity used by the raw transport until the security layer
    // establishes the real peer ID. This is consistent with the TCP transport.
    return libp2p.PeerId.fromMultihash(
      Uint8List.fromList([0x12, 0x20, ...List<int>.filled(32, 0)]),
    );
  }

  /// Creates a QUIC connection adapter.
  QuicConnection(
    this._delegate, {
    required libp2p.MultiAddr localAddr,
    required libp2p.MultiAddr remoteAddr,
    required bool isServer,
  })  : _localAddr = localAddr,
        _remoteAddr = remoteAddr,
        _isServer = isServer,
        _id = const Uuid().v4(),
        _localPeer = _placeholderPeerId();

  @override
  String get id => _id;

  @override
  bool get isClosed => _closed;

  /// The underlying [quic_lib] connection object.
  Object get quicConnection => _delegate.quicConnection;

  @override
  libp2p.PeerId get localPeer => _localPeer;

  @override
  libp2p.PeerId get remotePeer {
    final quicPeerId = _delegate.peerId;
    if (quicPeerId != null) {
      return libp2p.PeerId.fromString(quicPeerId.toBase58());
    }
    throw StateError(
      'Remote PeerId not yet established for this QUIC connection. '
      'Call verifyPeer() after the handshake completes.',
    );
  }

  @override
  Future<libp2p.PublicKey?> get remotePublicKey async {
    // The public key is embedded in the libp2p TLS extension; it is extracted
    // by verifyPeerCertificate() after the handshake completes. Return null
    // until verification has been performed.
    return null;
  }

  /// Validates that the peer's selected ALPN is acceptable and a [PeerId] has
  /// been derived.
  ///
  /// Returns true when the ALPN matches and a peer identity is present.
  /// This is a foundation-level check; a future iteration will also verify
  /// the libp2p TLS extension in the peer's certificate.
  bool verifyPeer() {
    _delegate.validateAlpn();
    return _delegate.peerId != null;
  }

  /// Verifies the peer's certificate using the libp2p TLS extension.
  ///
  /// [certBytes] is the raw DER-encoded X.509 certificate received from the
  /// peer during the TLS handshake. When [expectedPeerId] is provided, the
  /// derived peer identity must match it.
  ///
  /// Returns true if the certificate contains the libp2p extension, the
  /// signature is valid, and the derived peer identity matches
  /// [expectedPeerId] (when given).
  Future<bool> verifyPeerCertificate(
    List<int> certBytes, {
    quic_lib.PeerId? expectedPeerId,
  }) async {
    final backend = quic_lib.DefaultCryptoBackend();
    return _delegate.verifyPeerCertificate(
      certBytes,
      expectedPeerId: expectedPeerId,
      backend: backend,
    );
  }

  @override
  libp2p.MultiAddr get localMultiaddr => _localAddr;

  @override
  libp2p.MultiAddr get remoteMultiaddr => _remoteAddr;

  @override
  libp2p.ConnState get state => const libp2p.ConnState(
        streamMultiplexer: '',
        security: '/tls/1.3',
        transport: 'quic-v1',
        usedEarlyMuxerNegotiation: false,
      );

  @override
  libp2p.ConnStats get stat => _QuicConnStats(
        stats: libp2p.Stats(
          direction:
              _isServer ? libp2p.Direction.inbound : libp2p.Direction.outbound,
          opened: DateTime.now(),
        ),
        numStreams: 0,
      );

  @override
  libp2p.ConnScope get scope => libp2p.NullScope();

  @override
  Future<libp2p.P2PStream> newStream(libp2p.Context context) async {
    final quicConn = _delegate.quicConnection;
    if (quicConn is! quic_lib.QuicConnection) {
      throw StateError('Underlying QUIC connection is not a QuicConnection');
    }
    // Wait for the handshake to complete before opening a stream.
    while (!quicConn.isEstablished) {
      await Future.delayed(const Duration(milliseconds: 10));
    }
    final streamId = quicConn.openBidirectionalStream();
    return QuicP2PStream(
      this,
      streamId,
      libp2p.Direction.outbound,
      '',
    );
  }

  @override
  Future<List<libp2p.P2PStream>> get streams async {
    final quicConn = _delegate.quicConnection;
    if (quicConn is! quic_lib.QuicConnection) {
      return [];
    }
    final result = <libp2p.P2PStream>[];
    for (final stream in quicConn.streamManager.streams) {
      if (stream is quic_lib.QuicReceiveStream) {
        result.add(QuicP2PStream(
          this,
          stream.streamId,
          libp2p.Direction.inbound,
          '',
        ));
      }
    }
    return result;
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _delegate.close();
  }

  @override
  Future<Uint8List> read([int? length]) async {
    // Raw transport reads are not used for QUIC because the handshake is
    // performed inside the QUIC crypto frame stream.
    throw UnsupportedError(
      'QuicConnection does not support raw transport reads; use streams.',
    );
  }

  @override
  Future<void> write(Uint8List data) async {
    // Raw transport writes are not used for QUIC because the handshake is
    // performed inside the QUIC crypto frame stream.
    throw UnsupportedError(
      'QuicConnection does not support raw transport writes; use streams.',
    );
  }

  @override
  Socket get socket => throw UnsupportedError(
        'QuicConnection does not expose a dart:io Socket; it is backed by QUIC streams.',
      );

  @override
  void setReadTimeout(Duration timeout) {
    // QUIC deadlines are managed by the connection's recovery machinery.
  }

  @override
  void setWriteTimeout(Duration timeout) {
    // QUIC deadlines are managed by the connection's recovery machinery.
  }

  @override
  void notifyActivity() {
    // No-op: the QUIC connection tracks activity internally.
  }
}

class _QuicConnStats extends libp2p.ConnStats {
  const _QuicConnStats({required super.stats, required super.numStreams});
}
