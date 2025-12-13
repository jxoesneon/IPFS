import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/peer.dart';
import 'package:dart_ipfs/src/core/ipfs_node/mdns_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/routing_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/auto_nat_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/dns_link_handler.dart';
import 'package:dart_ipfs/src/network/mdns_client.dart';
import 'package:dart_ipfs/src/routing/content_routing.dart';
import 'package:test/test.dart';

// Mocks
class MockConfig extends IPFSConfig {
  MockConfig()
      : super(
            network: NetworkConfig(bootstrapPeers: []),
            debug: false,
            verboseLogging: false);
}

class MockNetworkHandler implements NetworkHandler {
  bool canConnect = true;
  bool dialbackResult = true;
  int testPort1 = 0;
  int testPort2 = 0;

  @override
  Future<bool> canConnectDirectly(String multiaddr) async => canConnect;

  @override
  @override
  Future<String> testConnection({required int sourcePort}) async => 'Success';

  @override
  Future<bool> testDialback() async => dialbackResult;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = '{"Path": "/ipfs/QmResolved"}';
    return http.StreamedResponse(Stream.value(body.codeUnits), 200);
  }
}

class MockContentRouting implements ContentRouting {
  bool started = false;
  @override
  Future<void> start() async {
    started = true;
  }

  @override
  Future<void> stop() async {
    started = false;
  }

  @override
  Future<List<String>> findProviders(String cid) async {
    if (cid == 'QmFound') return ['Peer1'];
    return [];
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockMDnsClient implements MDnsClient {
  bool started = false;
  @override
  Future<void> start(
      {InternetAddress? address, NetworkInterface? interface}) async {
    started = true;
  }

  @override
  Future<void> stop() async {
    started = false;
  }

  @override
  Stream<T> lookup<T extends ResourceRecord>(ResourceRecordQuery query,
      {Duration? timeout}) {
    return Stream.empty();
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('RoutingHandler', () {
    late RoutingHandler handler;
    late MockContentRouting mockContentRouting;

    setUp(() {
      mockContentRouting = MockContentRouting();
      handler = RoutingHandler(MockConfig(), MockNetworkHandler(),
          contentRouting: mockContentRouting);
    });

    test('start/stop delegates to ContentRouting', () async {
      await handler.start();
      expect(mockContentRouting.started, isTrue);
      await handler.stop();
      expect(mockContentRouting.started, isFalse);
    });

    test('findProviders delegates', () async {
      final providers = await handler.findProviders('QmFound');
      expect(providers, ['Peer1']);
      final empty = await handler.findProviders('QmMissing');
      expect(empty, isEmpty);
    });
  });

  group('MDNSHandler', () {
    late MDNSHandler handler;
    late MockMDnsClient mockClient;
    setUp(() {
      mockClient = MockMDnsClient();
      handler = MDNSHandler(MockConfig(), mdnsClient: mockClient);
    });
    test('start/stop delegates to MDnsClient', () async {
      await handler.start();
      expect(mockClient.started, isTrue);
      await handler.stop();
      expect(mockClient.started, isFalse);
    });
    test('status report', () async {
      final status = await handler.getStatus();
      expect(status['running'], isFalse);
      await handler.start();
      final statusRunning = await handler.getStatus();
      expect(statusRunning['running'], isTrue); // Mock start logic
    });
  });

  group('AutoNATHandler', () {
    late AutoNATHandler handler;
    late MockNetworkHandler network;
    setUp(() {
      network = MockNetworkHandler();
      handler = AutoNATHandler(MockConfig(), network);
    });
    test('start/stop', () async {
      await handler.start();
      final status = await handler.getStatus();
      expect(status['running'], isTrue);
      await handler.stop();
      final stopped = await handler.getStatus();
      expect(stopped['running'], isFalse);
    });
  });

  group('DNSLinkHandler', () {
    late DNSLinkHandler handler;
    late MockClient client;
    setUp(() {
      client = MockClient();
      handler = DNSLinkHandler(MockConfig(), client: client);
    });
    test('resolve uses client', () async {
      await handler.start();
      final cid = await handler.resolve('example.com');
      expect(cid, '/ipfs/QmResolved');
      await handler.stop();
    });
  });
}
