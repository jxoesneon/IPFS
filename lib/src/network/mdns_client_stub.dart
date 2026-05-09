import 'dart:async';
import 'mdns_client.dart';

/// Stub implementation of the mDNS client for platforms where it's not supported.
class MDnsClientStub implements MDnsClient {
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Stream<T> lookup<T extends ResourceRecord>(
    ResourceRecordQuery query, {
    Duration timeout = const Duration(seconds: 5),
  }) async* {}
  @override
  Future<void> startServer({
    required String serviceType,
    required String instanceName,
    required int port,
    required List<String> txt,
  }) async {}
  @override
  Future<void> announce(
    String serviceType,
    String instanceName,
    int port,
    List<String> txt,
  ) async {}
  @override
  bool get isRunning => false;
}

/// Creates an mDNS client stub.
MDnsClient createMDnsClient({dynamic client, dynamic serverSocket}) => MDnsClientStub();
