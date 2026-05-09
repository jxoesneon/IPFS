// ignore_for_file: prefer_const_constructors
import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:ipfs_libp2p/dart_libp2p.dart' as libp2p;
import 'package:web/web.dart' as web;

import 'multiaddr_parser.dart';
import 'webtransport_dialer.dart';

/// Creates a web-specific WebTransport dialer.
WebTransportDialer createDialer() => WebTransportDialerWeb();

/// Web implementation of [WebTransportDialer] using the browser's WebTransport API.
class WebTransportDialerWeb implements WebTransportDialer {
  @override
  Future<libp2p.Conn> dial(libp2p.MultiAddr addr) async {
    final info = WebTransportMultiaddrParser.parse(addr);
    if (info == null) {
      throw ArgumentError('Invalid WebTransport multiaddr: $addr');
    }

    final url = 'https://${info.ip}:${info.port}';

    // Configure WebTransport with serverCertificateHashes if provided
    final options = web.WebTransportOptions(
      serverCertificateHashes: info.certHashes
          .map((h) {
            final hash = web.WebTransportHash();
            hash.algorithm = 'sha-256';
            hash.value = Uint8List(32).toJS;
            return hash;
          })
          .toList()
          .toJS,
    );

    final transport = web.WebTransport(url, options);
    await transport.ready.toDart;

    final p2pPart = addr.toString().split('/p2p/').last;
    final remotePeerId = libp2p.PeerId.fromString(p2pPart);

    return WebTransportConnectionWeb(
      transport,
      addr,
      await libp2p.PeerId.random(),
      remotePeerId,
    );
  }
}

/// Web implementation of a WebTransport connection.
class WebTransportConnectionWeb implements libp2p.Conn {
  /// Creates a new [WebTransportConnectionWeb].
  WebTransportConnectionWeb(
    this._transport,
    this._remoteAddr,
    this._localPeer,
    this._remotePeer,
  );

  final web.WebTransport _transport;
  final libp2p.MultiAddr _remoteAddr;
  final libp2p.PeerId _localPeer;
  final libp2p.PeerId _remotePeer;

  @override
  libp2p.PeerId get localPeer => _localPeer;

  @override
  libp2p.PeerId get remotePeer => _remotePeer;

  @override
  // ignore: prefer_const_constructors
  libp2p.MultiAddr get localMultiaddr =>
      libp2p.MultiAddr('/ip4/127.0.0.1/udp/0/quic-v1/webtransport');

  @override
  libp2p.MultiAddr get remoteMultiaddr => _remoteAddr;

  @override
  Future<libp2p.P2PStream<Uint8List>> newStream(libp2p.Context context) async {
    final webStream = await _transport.createBidirectionalStream().toDart;
    return WebTransportStreamWeb(this, webStream);
  }

  @override
  Future<void> close() async {
    _transport.close();
  }

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

  @override
  Future<List<libp2p.P2PStream<Uint8List>>> get streams => Future.value([]);
}

/// Web implementation of a WebTransport stream.
class WebTransportStreamWeb implements libp2p.P2PStream<Uint8List> {
  /// Creates a new [WebTransportStreamWeb].
  WebTransportStreamWeb(this._conn, this._webStream);

  final WebTransportConnectionWeb _conn;
  final JSObject _webStream;
  String? _proto;

  @override
  Future<void> write(Uint8List data) async {
    final dynamic stream = _webStream;
    final writer = stream.writable.getWriter();
    await writer.write(data.toJS).toDart;
    writer.releaseLock();
  }

  @override
  Future<Uint8List> read([int? len]) async {
    final dynamic stream = _webStream;
    final reader = stream.readable.getReader();
    final result = await reader.read().toDart;
    reader.releaseLock();

    final value = result.value as JSArrayBuffer;
    return value.toDart.asUint8List();
  }

  @override
  Future<void> close() async {
    final dynamic stream = _webStream;
    await stream.writable.close().toDart;
  }

  @override
  Future<void> reset() async {
    final dynamic stream = _webStream;
    await stream.writable.abort().toDart;
  }

  @override
  String protocol() => _proto ?? '';

  @override
  libp2p.Conn get conn => _conn;

  @override
  bool get isClosed => false;

  @override
  String id() => 'wt-stream';

  @override
  libp2p.StreamManagementScope scope() => throw UnimplementedError();

  @override
  Future<void> closeRead() async {}

  @override
  Future<void> closeWrite() async {
    await close();
  }

  /// Gets the stream.
  Stream<Uint8List> get stream => throw UnimplementedError();

  /// Flushes the stream.
  Future<void> flush() async {}

  @override
  Future<void> setDeadline(DateTime? deadline) async {}

  @override
  Future<void> setReadDeadline(DateTime? deadline) async {}

  @override
  Future<void> setWriteDeadline(DateTime? deadline) async {}

  @override
  Future<void> setProtocol(String protocol) async {
    _proto = protocol;
  }

  @override
  libp2p.StreamStats stat() => throw UnimplementedError();

  @override
  libp2p.P2PStream<Uint8List> get incoming => this;

  @override
  bool get isWritable => true;
}
