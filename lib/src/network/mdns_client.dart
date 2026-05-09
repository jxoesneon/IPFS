import 'dart:async';

import 'mdns_client_stub.dart'
    if (dart.library.io) 'mdns_client_io.dart'
    if (dart.library.html) 'mdns_client_web.dart' as platform;

/// Base class for mDNS resource records.
abstract class ResourceRecord {
  /// Creates a resource record with [name] and time-to-live [ttl].
  ResourceRecord(this.name, this.ttl);

  /// The domain name of this record.
  final String name;

  /// Time-to-live for this record.
  final Duration ttl;
}

/// PTR record containing service instance name.
class PtrResourceRecord extends ResourceRecord {
  /// Creates a PTR record.
  PtrResourceRecord(super.name, super.ttl, this.domainName);

  /// The domain name this pointer resolves to.
  final String domainName;
}

/// SRV record containing service location information.
class SrvResourceRecord extends ResourceRecord {
  /// Creates an SRV record.
  SrvResourceRecord(
    super.name,
    super.ttl,
    this.target,
    this.port, {
    this.priority = 0,
    this.weight = 0,
  });

  /// The target hostname.
  final String target;

  /// The port number.
  final int port;

  /// Service priority (lower is higher priority).
  final int priority;

  /// Server weight for load balancing.
  final int weight;
}

/// TXT record containing service metadata.
class TxtResourceRecord extends ResourceRecord {
  /// Creates a TXT record.
  TxtResourceRecord(super.name, super.ttl, this.text);

  /// The text entries in this record.
  final List<String> text;
}

/// Query types for mDNS.
enum ResourceRecordType {
  /// Pointer record.
  ptr,

  /// Service record.
  srv,

  /// Text record.
  txt,

  /// IPv4 address record.
  a,

  /// IPv6 address record.
  aaaa
}

/// Query class for mDNS resource records.
class ResourceRecordQuery {
  /// Creates a new [ResourceRecordQuery] with [name] and [type].
  const ResourceRecordQuery(this.name, this.type);

  /// The name to query.
  final String name;

  /// The type of record to query.
  final ResourceRecordType type;

  /// Creates a PTR query for the given [service].
  static ResourceRecordQuery serverPointer(String service) =>
      ResourceRecordQuery('$service.local', ResourceRecordType.ptr);

  /// Creates an SRV query for the given [name].
  static ResourceRecordQuery service(String name) =>
      ResourceRecordQuery(name, ResourceRecordType.srv);

  /// Creates a TXT query for the given [name].
  static ResourceRecordQuery text(String name) =>
      ResourceRecordQuery(name, ResourceRecordType.txt);
}

/// Abstract client for multicast DNS operations.
abstract class MDnsClient {
  /// Creates a new [MDnsClient] using the platform-specific implementation.
  factory MDnsClient({dynamic client, dynamic serverSocket}) =>
      platform.createMDnsClient(client: client, serverSocket: serverSocket);

  /// Starts the mDNS client.
  Future<void> start();

  /// Stops the mDNS client.
  Future<void> stop();

  /// Performs a lookup for resource records matching [query].
  Stream<T> lookup<T extends ResourceRecord>(
    ResourceRecordQuery query, {
    Duration timeout = const Duration(seconds: 5),
  });

  /// Starts an mDNS server to respond to queries.
  Future<void> startServer({
    required String serviceType,
    required String instanceName,
    required int port,
    required List<String> txt,
  });

  /// Announces a service via mDNS.
  Future<void> announce(
    String serviceType,
    String instanceName,
    int port,
    List<String> txt,
  );

  /// Returns true if the client is currently running.
  bool get isRunning;
}
