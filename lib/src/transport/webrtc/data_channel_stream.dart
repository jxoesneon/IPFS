import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'package:ipfs_libp2p/dart_libp2p.dart' as libp2p;

abstract class DataChannelStream implements libp2p.P2PStream<Uint8List> {
  final ListQueue<int> _readBuffer = ListQueue<int>();
  Completer<void>? _readCompleter;
  bool _isClosed = false;
  String? _protocol;
  final bool _isIncoming;

  DataChannelStream({bool incoming = false}) : _isIncoming = incoming;

  @override
  libp2p.P2PStream<Uint8List> get incoming => this;

  @override
  bool get isWritable => !_isClosed;
  
  @override
  String protocol() => _protocol ?? '';
  
  @override
  Future<void> setProtocol(String protocol) async {
    _protocol = protocol;
  }

  @override
  bool get isClosed => _isClosed;

  @override
  libp2p.Conn get conn => throw UnimplementedError();

  String get label;

  void onMessage(Uint8List data) {
    _readBuffer.addAll(data);
    if (_readCompleter != null && !_readCompleter!.isCompleted) {
      _readCompleter!.complete();
    }
  }

  void onClosed() {
    _isClosed = true;
    if (_readCompleter != null && !_readCompleter!.isCompleted) {
      _readCompleter!.complete();
    }
  }

  @override
  Future<Uint8List> read([int? maxLength]) async {
    final length = maxLength ?? _readBuffer.length;
    if (length == 0) {
       if (_isClosed && _readBuffer.isEmpty) return Uint8List(0);
       while (_readBuffer.isEmpty && !_isClosed) {
         _readCompleter = Completer<void>();
         await _readCompleter!.future;
       }
       return Uint8List(0);
    }
    
    if (_isClosed && _readBuffer.isEmpty) return Uint8List(0);

    while (_readBuffer.length < length && !_isClosed) {
      _readCompleter = Completer<void>();
      await _readCompleter!.future;
    }
    
    if (_readBuffer.isEmpty) return Uint8List(0);

    final resultLen = _readBuffer.length < length ? _readBuffer.length : length;
    final result = Uint8List(resultLen);
    for (var i = 0; i < resultLen; i++) {
      result[i] = _readBuffer.removeFirst();
    }
    return result;
  }

  @override
  Future<void> write(Uint8List data);

  @override
  Future<void> close() async {
    _isClosed = true;
  }

  @override
  Future<void> reset() async {
    _isClosed = true;
  }

  @override
  String id() => label;

  @override
  libp2p.StreamManagementScope scope() => throw UnimplementedError();

  @override
  Future<void> closeRead() async {}

  @override
  Future<void> closeWrite() async {
    await close();
  }

  @override
  libp2p.StreamStats stat() => throw UnimplementedError();

  @override
  Future<void> setDeadline(DateTime? deadline) async {}

  @override
  Future<void> setReadDeadline(DateTime? deadline) async {}

  @override
  Future<void> setWriteDeadline(DateTime? deadline) async {}
}
