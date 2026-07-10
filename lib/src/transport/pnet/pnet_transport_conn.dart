// lib/src/transport/pnet/pnet_transport_conn.dart
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cipherlib/cipherlib.dart' show Nonce64, XSalsa20;
import 'package:ipfs_libp2p/core/crypto/keys.dart';
import 'package:ipfs_libp2p/core/multiaddr.dart';
import 'package:ipfs_libp2p/core/network/conn.dart' show ConnState, ConnStats;
import 'package:ipfs_libp2p/core/network/context.dart';
import 'package:ipfs_libp2p/core/network/rcmgr.dart' show ConnScope;
import 'package:ipfs_libp2p/core/network/stream.dart' show P2PStream;
import 'package:ipfs_libp2p/core/network/transport_conn.dart';
import 'package:ipfs_libp2p/core/peer/peer_id.dart';

const _nonceSize = 24;
const _blockSize = 64;

/// Stateful XSalsa20 keystream helper.
///
/// Because [XSalsa20.convert] does not carry state between calls, this helper
/// tracks the byte offset and recreates the cipher with the correct 64-bit
/// block counter for each chunk. Any intra-block offset is handled by
/// encrypting a leading run of zero bytes and discarding the corresponding
/// keystream prefix.
class _PnetCipher {
  _PnetCipher(Uint8List psk, Uint8List nonce) : _psk = psk, _nonce = nonce;

  final Uint8List _psk;
  final Uint8List _nonce;
  int _offset = 0;

  Uint8List process(Uint8List data) {
    if (data.isEmpty) return data;

    final blockCounter = _offset ~/ _blockSize;
    final intraBlockOffset = _offset % _blockSize;
    final cipher = XSalsa20(_psk, _nonce, Nonce64.int64(blockCounter));

    final Uint8List encrypted;
    if (intraBlockOffset == 0) {
      encrypted = cipher.convert(data);
    } else {
      // Skip the first [intraBlockOffset] bytes of the keystream by
      // encrypting zeros, then encrypt the actual payload.
      final combined = Uint8List(intraBlockOffset + data.length);
      combined.setAll(intraBlockOffset, data);
      final out = cipher.convert(combined);
      encrypted = out.sublist(intraBlockOffset);
    }

    _offset += data.length;
    return encrypted;
  }
}

/// A [TransportConn] that wraps an underlying transport connection and
/// encrypts/decrypts all traffic using the libp2p private-network (PNET)
/// handshake.
///
/// The handshake is performed once during construction/factory methods:
/// - The initiator (outbound dialer) writes its 24-byte nonce then reads the
///   peer's 24-byte nonce.
/// - The responder (inbound listener) reads the peer's 24-byte nonce then
///   writes its own 24-byte nonce.
///
/// Outbound traffic is encrypted with [XSalsa20] using the local nonce; inbound
/// traffic is decrypted with [XSalsa20] using the remote nonce.
class PnetTransportConn implements TransportConn {
  PnetTransportConn._(
    this._inner,
    Uint8List psk,
    Uint8List localNonce,
    Uint8List remoteNonce,
  ) : _outbound = _PnetCipher(psk, localNonce),
      _inbound = _PnetCipher(psk, remoteNonce);

  /// Creates a new PNET-wrapped connection after performing the handshake.
  ///
  /// [inner] is the raw transport connection to wrap.
  /// [psk] is the 32-byte pre-shared key.
  /// [isInitiator] determines the handshake role: `true` for outbound dials,
  /// `false` for inbound accepts.
  static Future<PnetTransportConn> create(
    TransportConn inner,
    Uint8List psk, {
    required bool isInitiator,
  }) async {
    final localNonce = Uint8List.fromList(
      List<int>.generate(_nonceSize, (_) => _secureRandom.nextInt(256)),
    );

    late final Uint8List remoteNonce;
    if (isInitiator) {
      await inner.write(localNonce);
      final remoteBytes = await inner.read(_nonceSize);
      if (remoteBytes.length != _nonceSize) {
        throw StateError(
          'PNET handshake failed: expected $_nonceSize byte nonce, '
          'got ${remoteBytes.length}',
        );
      }
      remoteNonce = remoteBytes;
    } else {
      final remoteBytes = await inner.read(_nonceSize);
      if (remoteBytes.length != _nonceSize) {
        throw StateError(
          'PNET handshake failed: expected $_nonceSize byte nonce, '
          'got ${remoteBytes.length}',
        );
      }
      remoteNonce = remoteBytes;
      await inner.write(localNonce);
    }

    return PnetTransportConn._(inner, psk, localNonce, remoteNonce);
  }

  final TransportConn _inner;
  final _PnetCipher _outbound;
  final _PnetCipher _inbound;

  static final Random _secureRandom = Random.secure();

  @override
  Future<Uint8List> read([int? length]) async {
    final encrypted = await _inner.read(length);
    return _inbound.process(encrypted);
  }

  @override
  Future<void> write(Uint8List data) async {
    final encrypted = _outbound.process(data);
    await _inner.write(encrypted);
  }

  // --------------------------------------------------------------------------
  // TransportConn delegation
  // --------------------------------------------------------------------------

  @override
  Socket get socket => _inner.socket;

  @override
  void setReadTimeout(Duration timeout) => _inner.setReadTimeout(timeout);

  @override
  void setWriteTimeout(Duration timeout) => _inner.setWriteTimeout(timeout);

  @override
  void notifyActivity() => _inner.notifyActivity();

  // --------------------------------------------------------------------------
  // Conn delegation
  // --------------------------------------------------------------------------

  @override
  Future<void> close() => _inner.close();

  @override
  String get id => _inner.id;

  @override
  // ignore: strict_raw_type
  Future<P2PStream> newStream(Context context) => _inner.newStream(context);

  @override
  // ignore: strict_raw_type
  Future<List<P2PStream>> get streams => _inner.streams;

  @override
  bool get isClosed => _inner.isClosed;

  @override
  PeerId get localPeer => _inner.localPeer;

  @override
  PeerId get remotePeer => _inner.remotePeer;

  @override
  Future<PublicKey?> get remotePublicKey => _inner.remotePublicKey;

  @override
  ConnState get state => _inner.state;

  @override
  MultiAddr get localMultiaddr => _inner.localMultiaddr;

  @override
  MultiAddr get remoteMultiaddr => _inner.remoteMultiaddr;

  @override
  ConnStats get stat => _inner.stat;

  @override
  ConnScope get scope => _inner.scope;
}
