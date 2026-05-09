import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'package:ipfs_libp2p/dart_libp2p.dart' as libp2p;
import 'webtransport_dialer.dart';
import 'multiaddr_parser.dart';

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
      serverCertificateHashes: info.certHashes.map((h) {
        final hash = web.WebTransportHash();
        hash.algorithm = 'sha-256';
        hash.value = Uint8List(32).toJS;
        return hash;
      }).toList().toJS as JSArray<web.WebTransportHash>,
    );

    final transport = web.WebTransport(url, options);
    await transport.ready.toDart;

    final p2pPart = addr.toString().split('/p2p/').last;
    final remotePeerId = libp2p.PeerId.fromString(p2pPart);

    return WebTransportConnectionWeb(
        transport, addr, await libp2p.PeerId.random(), remotePeerId);
  }
}

/// Web implementation of a WebTransport connection.
class WebTransportConnectionWeb implements libp2p.Conn {
  final web.WebTransport _transport;
  final libp2p.MultiAddr _remoteAddr;
  final libp2p.PeerId _localPeer;
  final libp2p.PeerId _remotePeer;

  /// Creates a new [WebTransportConnectionWeb].
  WebTransportConnectionWeb(
      this._transport, this._remoteAddr, this._localPeer, this._remotePeer);

  @override
  libp2p.PeerId get localPeer => _localPeer;

  @override
  libp2p.PeerId get remotePeer => _remotePeer;

  @override
  libp2p.MultiAddr get localMultiaddr =>
      libp2p.MultiAddr('/ip4/127.0.0.1/udp/0/quic-v1/webtransport');

  @override
  libp2p.MultiAddr get remoteMultiaddr => _remoteAddr;

  @override
  Future<libp2p.P2PStream<Uint8List>> newStream(libp2p.Context context) async {
    final webStream = await _transport.createBidirectionalStream().toDart;
    return WebTransportStreamWeb(
        this, webStream as web.WebTransportBidirectionalStream);
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
  final WebTransportConnectionWeb _conn;
  final web.WebTransportBidirectionalStream _webStream;
  String? _proto;

  /// Creates a new [WebTransportStreamWeb].
  WebTransportStreamWeb(this._conn, this._webStream);

  @override
  Future<void> write(Uint8List data) async {
    final writer = (_webStream.writable as web.WritableStream).getWriter();
    await (writer as web.WritableStreamDefaultWriter).write(data.toJS).toDart;
    (writer as web.WritableStreamDefaultWriter).releaseLock();
  }

  @override
  Future<Uint8List> read([int? len]) async {
    final reader = (_webStream.readable as web.ReadableStream).getReader();
    final result =
        await (reader as web.ReadableStreamDefaultReader).read().toDart;
    (reader as web.ReadableStreamDefaultReader).releaseLock();

    if (result == null || result.done) return Uint8List(0);
    final value = result.value as JSArrayBuffer;
    return value.toDart.asUint8List();
  }

  @override
  Future<void> close() async {
    await (_webStream.writable as web.WritableStream).close().toDart;
  }

  @override
  Future<void> reset() async {
    await (_webStream.writable as web.WritableStream).abort().toDart;
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

  @override
  Stream<Uint8List> get stream => throw UnimplementedError();

  @override
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
