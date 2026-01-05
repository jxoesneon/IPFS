import 'dart:async';
import 'dart:io';
import 'package:dart_ipfs/src/network/nat_traversal_service.dart';
import 'package:port_forwarder/port_forwarder.dart';
import 'package:test/test.dart';

class MockGateway implements Gateway {
  final List<Map<String, dynamic>> openPorts = [];
  final List<Map<String, dynamic>> closedPorts = [];
  bool? shouldThrow;

  @override
  Future<bool> openPort({
    required int externalPort,
    int? internalPort,
    int? leaseDuration,
    required PortType protocol,
    String? portDescription,
  }) async {
    if (shouldThrow == true) throw Exception('Mock Gateway Error');
    openPorts.add({
      'external': externalPort,
      'internal': internalPort ?? externalPort,
      'protocol': protocol,
    });
    return true;
  }

  @override
  Future<bool> closePort({
    required int externalPort,
    required PortType protocol,
  }) async {
    if (shouldThrow == true) throw Exception('Mock Gateway Error');
    closedPorts.add({'external': externalPort, 'protocol': protocol});
    return true;
  }

  @override
  Future<InternetAddress> get externalAddress async =>
      InternetAddress('1.2.3.4');

  @override
  InternetAddress get internalAddress => InternetAddress('192.168.1.2');

  @override
  Future<bool> isMapped({
    required int externalPort,
    required PortType protocol,
  }) async {
    return true;
  }

  @override
  GatewayType get type => GatewayType.upnp;
}

void main() {
  group('NatTraversalService', () {
    late NatTraversalService service;
    late MockGateway mockGateway;

    setUp(() {
      mockGateway = MockGateway();
      service = NatTraversalService(gateway: mockGateway);
    });

    test('mapPort successfully maps TCP and UDP', () async {
      final results = await service.mapPort(4001);

      expect(results, contains('TCP'));
      expect(results, contains('UDP'));
      expect(mockGateway.openPorts.length, 2);

      final tcpMap = mockGateway.openPorts.firstWhere(
        (p) => p['protocol'] == PortType.tcp,
      );
      expect(tcpMap['external'], 4001);
    });

    test('mapPort handles failures gracefully', () async {
      mockGateway.shouldThrow = true;
      final results = await service.mapPort(5001);

      expect(results, isEmpty);
    });

    test('unmapPort closes both protocols', () async {
      await service.unmapPort(4001);

      expect(mockGateway.closedPorts.length, 2);
      // Verify one TCP and one UDP closure
      expect(
        mockGateway.closedPorts.any((p) => p['protocol'] == PortType.tcp),
        isTrue,
      );
      expect(
        mockGateway.closedPorts.any((p) => p['protocol'] == PortType.udp),
        isTrue,
      );
    });
  });
}
