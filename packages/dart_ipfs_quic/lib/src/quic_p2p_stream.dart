import 'dart:async';
import 'dart:typed_data';

import 'package:ipfs_libp2p/core/network/conn.dart' as libp2p;
import 'package:ipfs_libp2p/core/network/common.dart' as libp2p;
import 'package:ipfs_libp2p/core/network/rcmgr.dart' as libp2p;
import 'package:ipfs_libp2p/core/network/stream.dart' as libp2p;
import 'package:quic_lib/quic_lib.dart' as quic_lib;
import 'package:uuid/uuid.dart';

import 'quic_transport.dart';

/// Adapter interface for the underlying QUIC connection used by [QuicP2PStream].
///
/// This abstraction removes the need for dynamic access to `streamManager` and
/// other QUIC connection internals, and allows tests to inject a fake connection.
abstract class QuicConnectionAdapter {
  /// Returns the QUIC stream with the given [id], or `null` if it does not exist.
  quic_lib.QuicStream? getQuicStream(int id);

  /// Whether the QUIC handshake is complete.
  bool get isEstablished;

  /// Opens a new bidirectional stream and returns its stream ID.
  int openBidirectionalStream();

  /// Closes the underlying connection.
  Future<void> close();
}

/// Internal read request that pairs a completer with the maximum number of
/// bytes the caller asked for, so the pull path can split fresh deliveries.
class _ReadRequest {
  final Completer<Uint8List> completer;
  final int? maxLength;
  _ReadRequest(this.completer, this.maxLength);
}

/// A [P2PStream] implementation backed by a single QUIC bidirectional stream.
///
/// The stream opens a bidirectional QUIC stream via the underlying
/// [QuicConnection]. Writes go to the send side; reads accumulate data from the
/// receive side. The receive stream is created lazily when the peer sends data.
class QuicP2PStream implements libp2p.P2PStream<Uint8List> {
  final QuicConnection _parentConnection;
  final int _streamId;
  final libp2p.Direction _direction;
  final String _id;
  String _protocolId;
  bool _isClosed = false;
  bool _readClosed = false;
  bool _writeClosed = false;

  final _incomingController = StreamController<Uint8List>.broadcast();
  StreamSubscription<Uint8List>? _receiveSubscription;
  final _readBuffer = <Uint8List>[];
  final _readRequests = <_ReadRequest>[];
  Completer<void>? _receiveDone;

  QuicP2PStream(
    this._parentConnection,
    this._streamId,
    this._direction,
    this._protocolId,
  ) : _id = const Uuid().v4() {
    _startReading();
  }

  quic_lib.QuicStream? get _quicStream =>
      _parentConnection.getQuicStream(_streamId);

  void _startReading() {
    _pollForReceiveStream();
  }

  void _pollForReceiveStream() {
    if (_isClosed || _readClosed) return;

    final stream = _quicStream;
    if (stream is quic_lib.QuicReceiveStream) {
      _attachToReceiveStream(stream);
      return;
    }

    // The receive stream is created when the peer sends the first STREAM frame.
    // Poll briefly until it appears.
    Future.delayed(const Duration(milliseconds: 10), _pollForReceiveStream);
  }

  void _attachToReceiveStream(quic_lib.QuicReceiveStream stream) {
    if (_receiveSubscription != null) return;

    _receiveDone = Completer<void>();
    stream.done.whenComplete(() {
      if (!_receiveDone!.isCompleted) _receiveDone!.complete();
    });

    _receiveSubscription = stream.incomingData.listen(
      (data) {
        if (_incomingController.isClosed) return;
        _incomingController.add(Uint8List.fromList(data));
        _readBuffer.add(Uint8List.fromList(data));
        _drainReadBuffer();
      },
      onError: (Object error) {
        if (!_incomingController.isClosed) {
          _incomingController.addError(error);
        }
      },
      onDone: () async {
        await _incomingController.close();
        _drainReadBuffer();
      },
    );
  }

  /// Drains the read buffer to satisfy waiting read requests.
  ///
  /// When a request specifies [maxLength] and the buffered data exceeds it,
  /// only [maxLength] bytes are consumed and the remainder is left in the
  /// buffer for the next read.
  void _drainReadBuffer() {
    if (_readRequests.isEmpty) return;

    var totalLength = 0;
    for (final chunk in _readBuffer) {
      totalLength += chunk.length;
    }
    if (totalLength == 0) {
      // If the receive stream is done and nothing is buffered, complete with empty.
      if (_receiveDone?.isCompleted ?? false) {
        final requests = List<_ReadRequest>.from(_readRequests);
        _readRequests.clear();
        for (final request in requests) {
          request.completer.complete(Uint8List(0));
        }
      }
      return;
    }

    final request = _readRequests.first;
    final maxLength = request.maxLength;
    final takeLength =
        maxLength == null || maxLength > totalLength ? totalLength : maxLength;

    final result = Uint8List(takeLength);
    var offset = 0;
    final remaining = <Uint8List>[];
    for (final chunk in _readBuffer) {
      if (offset >= takeLength) {
        remaining.add(chunk);
        continue;
      }
      final need = takeLength - offset;
      if (chunk.length <= need) {
        result.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      } else {
        result.setRange(offset, takeLength, chunk);
        remaining.add(Uint8List.sublistView(chunk, need));
        offset = takeLength;
      }
    }
    _readBuffer.clear();
    _readBuffer.addAll(remaining);

    _readRequests.removeAt(0);
    request.completer.complete(result);

    // If there is still buffered data and more requests are waiting, drain again.
    if (_readBuffer.isNotEmpty && _readRequests.isNotEmpty) {
      _drainReadBuffer();
    }
  }

  quic_lib.QuicSendStream? get _sendStream {
    final stream = _quicStream;
    if (stream is quic_lib.QuicSendStream) return stream;
    return null;
  }

  @override
  String id() => _id;

  @override
  String protocol() => _protocolId;

  @override
  Future<void> setProtocol(String id) async {
    _protocolId = id;
  }

  @override
  libp2p.StreamStats stat() => libp2p.StreamStats(
        direction: _direction,
        opened: DateTime.now(),
        limited: false,
        extra: {'quicStreamId': _streamId},
      );

  @override
  libp2p.Conn get conn => _parentConnection;

  @override
  libp2p.StreamManagementScope scope() => libp2p.NullScope();

  @override
  Future<Uint8List> read([int? maxLength]) async {
    if (_isClosed) {
      throw StateError('Stream is closed');
    }

    // Wait for receive stream to be ready.
    while (!_isClosed && !_readClosed) {
      final stream = _quicStream;
      if (stream is quic_lib.QuicReceiveStream) {
        if (_receiveSubscription == null) {
          _attachToReceiveStream(stream);
        }
        break;
      }
      await Future.delayed(const Duration(milliseconds: 5));
    }

    if (_isClosed || _readClosed) {
      throw StateError('Stream is closed');
    }

    // If data is already buffered, return it immediately.
    var bufferedLength = 0;
    for (final chunk in _readBuffer) {
      bufferedLength += chunk.length;
    }
    if (bufferedLength > 0) {
      final targetLength = maxLength ?? bufferedLength;
      final takeLength =
          targetLength > bufferedLength ? bufferedLength : targetLength;
      final result = Uint8List(takeLength);
      var offset = 0;
      final remaining = <Uint8List>[];
      for (final chunk in _readBuffer) {
        if (offset >= takeLength) {
          remaining.add(chunk);
          continue;
        }
        final need = takeLength - offset;
        if (chunk.length <= need) {
          result.setRange(offset, offset + chunk.length, chunk);
          offset += chunk.length;
        } else {
          result.setRange(offset, takeLength, chunk);
          remaining.add(Uint8List.sublistView(chunk, need));
          offset = takeLength;
        }
      }
      _readBuffer.clear();
      _readBuffer.addAll(remaining);
      return result;
    }

    // Wait for next chunk.
    final completer = Completer<Uint8List>();
    _readRequests.add(_ReadRequest(completer, maxLength));

    // Set up a one-time listener if not already attached.
    _receiveSubscription ??=
        (_quicStream as quic_lib.QuicReceiveStream?)?.incomingData.listen(
      (data) {
        if (_incomingController.isClosed) return;
        _incomingController.add(Uint8List.fromList(data));
        _readBuffer.add(Uint8List.fromList(data));
        _drainReadBuffer();
      },
      onDone: _drainReadBuffer,
    );

    return completer.future;
  }

  @override
  Future<void> write(Uint8List data) async {
    if (_isClosed || _writeClosed) {
      throw StateError('Stream is closed for writing');
    }
    final sendStream = _sendStream;
    if (sendStream == null) {
      throw StateError('No send stream available for stream $_streamId');
    }
    sendStream.write(Uint8List.fromList(data));
  }

  @override
  libp2p.P2PStream<Uint8List> get incoming => this;

  /// A Dart [Stream] of incoming data for this QUIC stream.
  Stream<Uint8List> get stream => _incomingController.stream;

  @override
  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;
    _readClosed = true;
    _writeClosed = true;
    await closeWrite();
    await closeRead();
    await _receiveSubscription?.cancel();
    _receiveSubscription = null;
    if (!_incomingController.isClosed) {
      await _incomingController.close();
    }
  }

  @override
  Future<void> closeWrite() async {
    if (_writeClosed) return;
    _writeClosed = true;
    _sendStream?.close();
  }

  @override
  Future<void> closeRead() async {
    if (_readClosed) return;
    _readClosed = true;
    await _receiveSubscription?.cancel();
    _receiveSubscription = null;
    if (!_incomingController.isClosed) {
      await _incomingController.close();
    }
  }

  @override
  Future<void> reset() async {
    if (_isClosed) return;
    _sendStream?.reset();
    final stream = _quicStream;
    if (stream is quic_lib.QuicReceiveStream) {
      stream.reset();
    }
    await close();
  }

  @override
  Future<void> setDeadline(DateTime? time) async {
    // QUIC does not expose per-stream deadlines through this API.
  }

  @override
  Future<void> setReadDeadline(DateTime time) async {}

  @override
  Future<void> setWriteDeadline(DateTime time) async {}

  @override
  bool get isClosed => _isClosed;

  @override
  bool get isWritable => !_isClosed && !_writeClosed;
}
