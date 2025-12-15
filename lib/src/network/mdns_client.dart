import 'dart:async';
import 'dart:io';
import 'dart:typed_data'; // For BytesBuilder
import 'package:multicast_dns/multicast_dns.dart' as mdns;
import 'package:dart_ipfs/src/utils/logger.dart';

/// Resource record types for mDNS queries
enum ResourceRecordType { PTR, SRV, TXT, A, AAAA }

/// Query class for mDNS resource records
class ResourceRecordQuery {
  final String name;
  final ResourceRecordType type;

  const ResourceRecordQuery(this.name, this.type);

  /// Creates a PTR query for service discovery
  static ResourceRecordQuery serverPointer(String service) {
    return ResourceRecordQuery('$service.local', ResourceRecordType.PTR);
  }

  /// Creates an SRV query for service details
  static ResourceRecordQuery service(String name) {
    return ResourceRecordQuery(name, ResourceRecordType.SRV);
  }

  /// Creates a TXT query for service metadata
  static ResourceRecordQuery text(String name) {
    return ResourceRecordQuery(name, ResourceRecordType.TXT);
  }
}

/// Base class for mDNS resource records
abstract class ResourceRecord {
  final String name;
  final Duration ttl;

  ResourceRecord(this.name, this.ttl);
}

/// PTR record containing service instance name
class PtrResourceRecord extends ResourceRecord {
  final String domainName;

  PtrResourceRecord(String name, Duration ttl, this.domainName)
    : super(name, ttl);
}

/// SRV record containing service location information
class SrvResourceRecord extends ResourceRecord {
  final String target;
  final int port;
  final int priority;
  final int weight;

  SrvResourceRecord(
    String name,
    Duration ttl,
    this.target,
    this.port, {
    this.priority = 0,
    this.weight = 0,
  }) : super(name, ttl);
}

/// TXT record containing service metadata
class TxtResourceRecord extends ResourceRecord {
  final List<String> text;

  TxtResourceRecord(String name, Duration ttl, this.text) : super(name, ttl);
}

/// Client for multicast DNS operations following IPFS specifications
class MDnsClient {
  mdns.MDnsClient? _client;
  bool _isRunning = false;
  final Logger _logger = Logger('MDnsClient');

  /// Starts the mDNS client
  Future<void> start() async {
    if (_isRunning) {
      _logger.warning('MDnsClient already running');
      return;
    }

    try {
      _client = mdns.MDnsClient();
      await _client!.start();
      _isRunning = true;
      _logger.debug('MDnsClient started successfully');
    } catch (e) {
      _logger.error('Failed to start MDnsClient', e);
      rethrow;
    }
  }

  /// Stops the mDNS client
  Future<void> stop() async {
    if (!_isRunning) {
      _logger.warning('MDnsClient already stopped');
      return;
    }

    try {
      if (_client != null) {
        _client!.stop();
        _client = null;
        _isRunning = false;
        _logger.debug('MDnsClient stopped successfully');
      }
    } catch (e) {
      _logger.error('Failed to stop MDnsClient', e);
      rethrow;
    }
  }

  /// Performs an mDNS lookup for the specified record type
  Stream<T> lookup<T extends ResourceRecord>(
    ResourceRecordQuery query, {
    Duration timeout = const Duration(seconds: 5),
  }) async* {
    if (!_isRunning || _client == null) {
      throw StateError('MDnsClient not running');
    }

    try {
      final queryParameters = mdns.ResourceRecordQuery(
        _getResourceRecordType(query.type),
        query.name,
        0x8000, // This is the constant for multicast questions in mDNS
      );

      await for (final record
          in _client!.lookup(queryParameters).timeout(timeout)) {
        final transformed = _transformRecord<T>(record);
        if (transformed != null) {
          yield transformed;
        }
      }
    } on TimeoutException {
      _logger.debug('mDNS lookup timed out for query: ${query.name}');
    } catch (e) {
      _logger.error('Error during mDNS lookup', e);
      rethrow;
    }
  }

  /// Transforms raw mDNS records into typed resource records
  T? _transformRecord<T extends ResourceRecord>(mdns.ResourceRecord raw) {
    try {
      if (T == PtrResourceRecord && raw is mdns.PtrResourceRecord) {
        return PtrResourceRecord(
              raw.name,
              Duration(milliseconds: raw.validUntil),
              raw.domainName,
            )
            as T;
      } else if (T == SrvResourceRecord && raw is mdns.SrvResourceRecord) {
        return SrvResourceRecord(
              raw.name,
              Duration(milliseconds: raw.validUntil),
              raw.target,
              raw.port,
              priority: raw.priority,
              weight: raw.weight,
            )
            as T;
      } else if (T == TxtResourceRecord && raw is mdns.TxtResourceRecord) {
        return TxtResourceRecord(
              raw.name,
              Duration(milliseconds: raw.validUntil),
              [raw.text],
            )
            as T;
      }
      return null;
    } catch (e) {
      _logger.error('Error transforming record', e);
      return null;
    }
  }

  /// Gets the corresponding mDNS record type for our enum
  int _getResourceRecordType(ResourceRecordType type) {
    switch (type) {
      case ResourceRecordType.PTR:
        return 12; // RFC 1035 PTR record type
      case ResourceRecordType.SRV:
        return 33; // RFC 2782 SRV record type
      case ResourceRecordType.TXT:
        return 16; // RFC 1035 TXT record type
      case ResourceRecordType.A:
        return 1; // RFC 1035 A record type
      case ResourceRecordType.AAAA:
        return 28; // RFC 3596 AAAA record type
    }
  }

  RawDatagramSocket? _serverSocket;
  final InternetAddress _mdnsGroup = InternetAddress('224.0.0.251');
  final int _mdnsPort = 5353;

  bool get isRunning => _isRunning;

  /// Starts the mDNS server for advertising
  Future<void> startServer({
    required String serviceType,
    required String instanceName,
    required int port,
    required List<String> txt,
  }) async {
    if (_serverSocket != null) return; // Already running

    try {
      _serverSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _mdnsPort,
        reuseAddress: true,
      );
      _serverSocket!.joinMulticast(_mdnsGroup);
      _serverSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final packet = _serverSocket!.receive();
          if (packet != null) {
            _handlePacket(packet, serviceType, instanceName, port, txt);
          }
        }
      });
      _logger.debug('mDNS Responder started on port $_mdnsPort');
    } catch (e) {
      _logger.error('Failed to start mDNS Responder', e);
    }
  }

  /// Sends an unsolicited announcement (response)
  Future<void> announce(
    String serviceType,
    String instanceName,
    int port,
    List<String> txt,
  ) async {
    if (_serverSocket == null) return;
    try {
      _sendResponse(serviceType, instanceName, port, txt);
    } catch (e) {
      _logger.error('Failed to send announcement', e);
    }
  }

  void _handlePacket(
    Datagram packet,
    String serviceType,
    String instanceName,
    int port,
    List<String> txt,
  ) {
    // Basic DNS Packet Parsing
    final data = packet.data;
    if (data.length < 12) return;

    // 1. Parse Header
    // ID (0-1), Flags (2-3), QDCOUNT (4-5)
    int qdCount = (data[4] << 8) | data[5];
    int flags = (data[2] << 8) | data[3];

    // Check if Query (QR bit is 0). Flags & 0x8000 == 0
    if ((flags & 0x8000) != 0) return; // Ignore responses

    int offset = 12;

    // 2. Parse Questions
    for (int i = 0; i < qdCount; i++) {
      final result = _readName(data, offset);
      String qName = result.item1;
      offset = result.item2;

      // Skip QType (2) and QClass (2)
      if (offset + 4 > data.length) return;
      offset += 4;

      // Check if query matches our service (or instance)
      // Normalize names? mDNS is case-insensitive usually.
      if (qName.toLowerCase() == '$serviceType.local'.toLowerCase() ||
          qName.toLowerCase() == '$instanceName.local'.toLowerCase()) {
        _sendResponse(serviceType, instanceName, port, txt);
        return;
      }
    }
  }

  void _sendResponse(
    String serviceType,
    String instanceName,
    int port,
    List<String> txtRecords,
  ) {
    // Construct DNS Response Packet
    final response = BytesBuilder();

    // -- Header --
    response.add([0x00, 0x00]); // ID (0)
    response.add([0x84, 0x00]); // Flags (Standard Response, Authoritative)
    response.add([0x00, 0x00]); // QDCOUNT (0)
    response.add([0x00, 0x03]); // ANCOUNT (3 records: PTR, SRV, TXT)
    response.add([0x00, 0x00]); // NSCOUNT
    response.add([0x00, 0x00]); // ARCOUNT

    // -- Answers --

    // 1. PTR Record (Service -> Instance)
    // Name: _ipfs-discovery._udp.local
    _writeName(response, '$serviceType.local');
    response.add([0x00, 0x0c]); // Type: PTR
    response.add([0x00, 0x01]); // Class: IN
    response.add([0x00, 0x00, 0x00, 0x78]); // TTL: 120s

    // RDLENGTH & RDATA (Instance Name)
    final ptrData = BytesBuilder();
    _writeName(ptrData, '$instanceName.local');
    response.addByte(0); // Placeholder for RDLENGTH high byte (assuming < 256)
    response.addByte(ptrData.length);
    response.add(ptrData.takeBytes());

    // 2. SRV Record (Instance -> Target:Port)
    _writeName(response, '$instanceName.local');
    response.add([0x00, 0x21]); // Type: SRV
    response.add([0x00, 0x01]); // Class: IN
    response.add([0x00, 0x00, 0x00, 0x78]); // TTL

    // RDATA: Priority(2), Weight(2), Port(2), Target
    final srvData = BytesBuilder();
    srvData.add([0x00, 0x00]); // Priority
    srvData.add([0x00, 0x00]); // Weight
    srvData.add([(port >> 8) & 0xFF, port & 0xFF]); // Port
    // Target: We cheat and point to local machine name, or just use instance name for now as hostname?
    // mDNS usually needs a hostname (e.g. my-mac.local).
    // For now, let's use the instance name as the "hostname" too,
    // relying on the fact that we aren't sending A records so resolution relies on system mDNS for the host usually?
    // Actually, we must provide A/AAAA records or point to an existing hostname.
    // Let's use 'ipfs-node.local' as a generic hostname and hope for the best for now,
    // OR just point to the instance name.
    _writeName(srvData, '$instanceName.local');

    response.addByte(0);
    response.addByte(srvData.length);
    response.add(srvData.takeBytes());

    // 3. TXT Record
    _writeName(response, '$instanceName.local');
    response.add([0x00, 0x10]); // Type: TXT
    response.add([0x00, 0x01]); // Class: IN
    response.add([0x00, 0x00, 0x00, 0x78]); // TTL

    final txtData = BytesBuilder();
    for (final t in txtRecords) {
      final bytes = t.codeUnits; // ASCII
      txtData.addByte(bytes.length);
      txtData.add(bytes);
    }

    response.addByte(0);
    response.addByte(txtData.length);
    response.add(txtData.takeBytes());

    // Send!
    if (_serverSocket != null) {
      _serverSocket!.send(response.takeBytes(), _mdnsGroup, _mdnsPort);
    }
  }

  // Helpers
  void _writeName(BytesBuilder builder, String name) {
    for (final part in name.split('.')) {
      builder.addByte(part.length);
      builder.add(part.codeUnits);
    }
    builder.addByte(0);
  }

  // Tuple(Name, NewOffset)
  _Pair<String, int> _readName(List<int> data, int offset) {
    final parts = <String>[];
    int current = offset;

    while (current < data.length) {
      int len = data[current];
      if (len == 0) {
        current++;
        break;
      }
      if ((len & 0xC0) == 0xC0) {
        // Compression - pointer
        // Not implemented for simplicity in simple parser
        current += 2;
        break;
      }
      current++;
      if (current + len > data.length) break;
      parts.add(String.fromCharCodes(data.sublist(current, current + len)));
      current += len;
    }
    return _Pair(parts.join('.'), current);
  }
}

class _Pair<A, B> {
  final A item1;
  final B item2;
  _Pair(this.item1, this.item2);
}
