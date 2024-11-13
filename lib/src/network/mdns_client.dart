// src/network/mdns_client.dart
import 'dart:async';
import 'package:multicast_dns/multicast_dns.dart' as mdns;
import 'package:dart_ipfs/src/utils/logger.dart';

/// Resource record types for mDNS queries
enum ResourceRecordType {
  PTR,
  SRV,
  TXT,
  A,
  AAAA,
}

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
  Stream<T> lookup<T extends ResourceRecord>(ResourceRecordQuery query,
      {Duration timeout = const Duration(seconds: 5)}) async* {
    if (!_isRunning || _client == null) {
      throw StateError('MDnsClient not running');
    }

    try {
      final queryParameters = mdns.ResourceRecordQuery(
          _getResourceRecordType(query.type),
          query.name,
          0x8000 // This is the constant for multicast questions in mDNS
          );

      await for (final record
          in _client!.lookup(queryParameters).timeout(timeout)) {
        final transformed = _transformRecord<T>(record);
        if (transformed != null) {
          yield transformed;
        }
      }
    } on TimeoutException {
      _logger.warning('mDNS lookup timed out for query: ${query.name}');
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
        ) as T;
      } else if (T == SrvResourceRecord && raw is mdns.SrvResourceRecord) {
        return SrvResourceRecord(
          raw.name,
          Duration(milliseconds: raw.validUntil),
          raw.target,
          raw.port,
          priority: raw.priority,
          weight: raw.weight,
        ) as T;
      } else if (T == TxtResourceRecord && raw is mdns.TxtResourceRecord) {
        return TxtResourceRecord(
          raw.name,
          Duration(milliseconds: raw.validUntil),
          [raw.text],
        ) as T;
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

  bool get isRunning => _isRunning;
}
