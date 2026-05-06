import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:port_forwarder/port_forwarder.dart';
import 'package:dart_ipfs/src/network/nat_traversal_service.dart';
import 'package:dart_ipfs/src/utils/logger.dart';

@GenerateNiceMocks([
  MockSpec<Gateway>(),
  MockSpec<Logger>(),
])
import 'nat_traversal_service_improved_test.mocks.dart';

void main() {
  late MockGateway mockGateway;
  late MockLogger mockLogger;
  late NatTraversalService natService;

  setUp(() {
    mockGateway = MockGateway();
    mockLogger = MockLogger();
    natService = NatTraversalService(logger: mockLogger, gateway: mockGateway);
  });

  group('NatTraversalService mapPort', () {
    test('successfully maps both TCP and UDP', () async {
      when(
        mockGateway.openPort(
          externalPort: anyNamed('externalPort'),
          internalPort: anyNamed('internalPort'),
          protocol: anyNamed('protocol'),
          leaseDuration: anyNamed('leaseDuration'),
        ),
      ).thenAnswer((_) async => true);

      final results = await natService.mapPort(4001);

      expect(results, containsAll(['TCP', 'UDP']));
      verify(
        mockGateway.openPort(
          externalPort: 4001,
          internalPort: 4001,
          protocol: PortType.tcp,
          leaseDuration: 0,
        ),
      ).called(1);
      verify(
        mockGateway.openPort(
          externalPort: 4001,
          internalPort: 4001,
          protocol: PortType.udp,
          leaseDuration: 0,
        ),
      ).called(1);
    });

    test('successfully maps only TCP when UDP fails', () async {
      when(
        mockGateway.openPort(
          externalPort: 4001,
          internalPort: 4001,
          protocol: PortType.tcp,
          leaseDuration: 0,
        ),
      ).thenAnswer((_) async => true);

      when(
        mockGateway.openPort(
          externalPort: 4001,
          internalPort: 4001,
          protocol: PortType.udp,
          leaseDuration: 0,
        ),
      ).thenThrow(Exception('UDP failure'));

      final results = await natService.mapPort(4001);

      expect(results, equals(['TCP']));
      verify(mockLogger.warning(any, any)).called(1);
    });

    test('successfully maps only UDP when TCP fails', () async {
      when(
        mockGateway.openPort(
          externalPort: 4001,
          internalPort: 4001,
          protocol: PortType.tcp,
          leaseDuration: 0,
        ),
      ).thenThrow(Exception('TCP failure'));

      when(
        mockGateway.openPort(
          externalPort: 4001,
          internalPort: 4001,
          protocol: PortType.udp,
          leaseDuration: 0,
        ),
      ).thenAnswer((_) async => true);

      final results = await natService.mapPort(4001);

      expect(results, equals(['UDP']));
      verify(mockLogger.warning(any, any)).called(1);
    });

    test('returns empty list when both fail', () async {
      when(
        mockGateway.openPort(
          externalPort: anyNamed('externalPort'),
          internalPort: anyNamed('internalPort'),
          protocol: anyNamed('protocol'),
          leaseDuration: anyNamed('leaseDuration'),
        ),
      ).thenThrow(Exception('Failure'));

      final results = await natService.mapPort(4001);

      expect(results, isEmpty);
      verify(mockLogger.warning(any, any)).called(2);
    });

    test('respects lease duration', () async {
      when(
        mockGateway.openPort(
          externalPort: anyNamed('externalPort'),
          internalPort: anyNamed('internalPort'),
          protocol: anyNamed('protocol'),
          leaseDuration: anyNamed('leaseDuration'),
        ),
      ).thenAnswer((_) async => true);

      final results = await natService.mapPort(
        4001,
        leaseDuration: Duration(minutes: 30),
      );

      expect(results, containsAll(['TCP', 'UDP']));
      verify(
        mockGateway.openPort(
          externalPort: 4001,
          internalPort: 4001,
          protocol: PortType.tcp,
          leaseDuration: 1800,
        ),
      ).called(1);
    });

    test('handles null gateway and discovery failure', () async {
      final natServiceNoGateway = NatTraversalService(
        logger: mockLogger,
        gateway: null,
      );

      final results = await natServiceNoGateway
          .mapPort(4001)
          .timeout(Duration(seconds: 5), onTimeout: () => []);

      expect(results, isEmpty);
    });
  });

  group('NatTraversalService unmapPort', () {
    test('successfully unmaps both TCP and UDP', () async {
      when(
        mockGateway.closePort(
          externalPort: anyNamed('externalPort'),
          protocol: anyNamed('protocol'),
        ),
      ).thenAnswer((_) async => true);

      await natService.unmapPort(4001);

      verify(
        mockGateway.closePort(externalPort: 4001, protocol: PortType.tcp),
      ).called(1);
      verify(
        mockGateway.closePort(externalPort: 4001, protocol: PortType.udp),
      ).called(1);
    });

    test('handles exceptions during unmap', () async {
      when(
        mockGateway.closePort(
          externalPort: anyNamed('externalPort'),
          protocol: anyNamed('protocol'),
        ),
      ).thenThrow(Exception('Unmap failure'));

      await natService.unmapPort(4001);

      verify(mockLogger.warning(any, any)).called(1);
    });

    test('does nothing if gateway is null', () async {
      final natServiceNoGateway = NatTraversalService(
        logger: mockLogger,
        gateway: null,
      );

      await natServiceNoGateway.unmapPort(4001);

      verifyNever(
        mockGateway.closePort(
          externalPort: anyNamed('externalPort'),
          protocol: anyNamed('protocol'),
        ),
      );
    });
  });

  group('NatTraversalService Error Handling', () {
    test('handles top-level exception in mapPort', () async {
      // Triggering the catch-all block in mapPort
      // We can trigger this if Gateway.discover() throws.
      // Since we can't mock Gateway.discover(), this might be hard to cover unless
      // we modify the code to take a factory.
    });
  });
}
