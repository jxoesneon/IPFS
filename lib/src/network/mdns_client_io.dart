import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:multicast_dns/multicast_dns.dart' as mdns;
import 'mdns_client.dart';

/// IO implementation of the mDNS client.
class MDnsClientIO implements MDnsClient {
  /// Creates an mDNS client for IO platforms.
  MDnsClientIO({mdns.MDnsClient? client, RawDatagramSocket? serverSocket})
    : _injectedClient = client,
      _serverSocket = serverSocket;

  mdns.MDnsClient? _client;
  final mdns.MDnsClient? _injectedClient;
  bool _isRunning = false;

  @override
  Future<void> start() async {
    if (_isRunning) return;
    _client = _injectedClient ?? mdns.MDnsClient();
    await _client!.start();
    _isRunning = true;
  }

  @override
  Future<void> stop() async {
    if (!_isRunning) return;
    _client?.stop();
    _client = null;
    _isRunning = false;
  }

  @override
  Stream<T> lookup<T extends ResourceRecord>(
    ResourceRecordQuery query, {
    Duration timeout = const Duration(seconds: 5),
  }) async* {
    if (!_isRunning || _client == null) return;

    final queryParameters = mdns.ResourceRecordQuery(
      _getResourceRecordType(query.type),
      query.name,
      1,
    );

    try {
      await for (final record in _client!.lookup(queryParameters).timeout(timeout)) {
        final transformed = _transformRecord<T>(record);
        if (transformed != null) yield transformed;
      }
    } on TimeoutException {
      // Handled as per test requirements for MDNS discovery
    }
  }

  T? _transformRecord<T extends ResourceRecord>(mdns.ResourceRecord raw) {
    if (T == PtrResourceRecord && raw is mdns.PtrResourceRecord) {
      return PtrResourceRecord(raw.name, Duration(milliseconds: raw.validUntil), raw.domainName) as T;
    } else if (T == SrvResourceRecord && raw is mdns.SrvResourceRecord) {
      return SrvResourceRecord(raw.name, Duration(milliseconds: raw.validUntil), raw.target, raw.port, priority: raw.priority, weight: raw.weight) as T;
    } else if (T == TxtResourceRecord && raw is mdns.TxtResourceRecord) {
      return TxtResourceRecord(raw.name, Duration(milliseconds: raw.validUntil), [raw.text]) as T;
    }
    return null;
  }

  int _getResourceRecordType(ResourceRecordType type) {
    switch (type) {
      case ResourceRecordType.ptr: return 12;
      case ResourceRecordType.srv: return 33;
      case ResourceRecordType.txt: return 16;
      case ResourceRecordType.a: return 1;
      case ResourceRecordType.aaaa: return 28;
    }
  }

  RawDatagramSocket? _serverSocket;
  bool _isServerRunning = false;
  final InternetAddress _mdnsGroup = InternetAddress('224.0.0.251');
  final int _mdnsPort = 5353;

  @override
  bool get isRunning => _isRunning;

  @override
  Future<void> startServer({
    required String serviceType,
    required String instanceName,
    required int port,
    required List<String> txt,
  }) async {
    try {
      if (_isServerRunning) return;
      _serverSocket ??= await RawDatagramSocket.bind(InternetAddress.anyIPv4, _mdnsPort, reuseAddress: true);
      _serverSocket!.joinMulticast(_mdnsGroup);
      _serverSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final packet = _serverSocket!.receive();
          if (packet != null) _handlePacket(packet, serviceType, instanceName, port, txt);
        }
      });
      _isServerRunning = true;
    } catch (e) {
      // Log error or handle gracefully
    }
  }

  @override
  Future<void> announce(String serviceType, String instanceName, int port, List<String> txt) async {
    try {
      if (_serverSocket == null) return;
      _sendResponse(serviceType, instanceName, port, txt);
    } catch (e) {
      // Log error or handle gracefully
    }
  }

  void _handlePacket(Datagram packet, String serviceType, String instanceName, int port, List<String> txt) {
    final data = packet.data;
    if (data.length < 12) return;
    int qdCount = (data[4] << 8) | data[5];
    int flags = (data[2] << 8) | data[3];
    if ((flags & 0x8000) != 0) return;
    int offset = 12;
    for (int i = 0; i < qdCount; i++) {
      final result = _readName(data, offset);
      String qName = result.item1;
      offset = result.item2 + 4;
      if (qName.toLowerCase() == '$serviceType.local'.toLowerCase() ||
          qName.toLowerCase() == '$instanceName.local'.toLowerCase()) {
        _sendResponse(serviceType, instanceName, port, txt);
        return;
      }
    }
  }

  void _sendResponse(String serviceType, String instanceName, int port, List<String> txtRecords) {
    final response = BytesBuilder();
    response.add([0, 0, 0x84, 0, 0, 0, 0, 3, 0, 0, 0, 0]);
    _writeName(response, '$serviceType.local');
    response.add([0, 0x0c, 0, 1, 0, 0, 0, 0x78]);
    final ptrData = BytesBuilder();
    _writeName(ptrData, '$instanceName.local');
    response.addByte(0); response.addByte(ptrData.length);
    response.add(ptrData.takeBytes());
    _writeName(response, '$instanceName.local');
    response.add([0, 0x21, 0, 1, 0, 0, 0, 0x78]);
    final srvData = BytesBuilder();
    srvData.add([0, 0, 0, 0, (port >> 8) & 0xFF, port & 0xFF]);
    _writeName(srvData, '$instanceName.local');
    response.addByte(0); response.addByte(srvData.length);
    response.add(srvData.takeBytes());
    _writeName(response, '$instanceName.local');
    response.add([0, 0x10, 0, 1, 0, 0, 0, 0x78]);
    final txtData = BytesBuilder();
    for (final t in txtRecords) {
      final b = t.codeUnits;
      txtData.addByte(b.length); txtData.add(b);
    }
    response.addByte(0); response.addByte(txtData.length);
    response.add(txtData.takeBytes());
    _serverSocket?.send(response.takeBytes(), _mdnsGroup, _mdnsPort);
  }

  void _writeName(BytesBuilder b, String name) {
    for (final p in name.split('.')) { b.addByte(p.length); b.add(p.codeUnits); }
    b.addByte(0);
  }

  _Pair<String, int> _readName(List<int> d, int o) {
    final p = <String>[]; int c = o;
    while (c < d.length) {
      int l = d[c]; if (l == 0) { c++; break; }
      if ((l & 0xC0) == 0xC0) { c += 2; break; }
      c++; if (c + l > d.length) break;
      p.add(String.fromCharCodes(d.sublist(c, c + l))); c += l;
    }
    return _Pair(p.join('.'), c);
  }
}

class _Pair<A, B> { _Pair(this.item1, this.item2); final A item1; final B item2; }

/// Creates an mDNS client for the IO platform.
///
/// Supports injecting a [client] and [serverSocket] for testing purposes.
MDnsClient createMDnsClient({dynamic client, dynamic serverSocket}) =>
    MDnsClientIO(
      client: client as mdns.MDnsClient?,
      serverSocket: serverSocket as RawDatagramSocket?,
    );
