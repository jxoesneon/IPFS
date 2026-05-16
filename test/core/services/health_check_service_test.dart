import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dart_ipfs/src/core/services/health_check_service.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';

import 'health_check_service_test.mocks.dart';

@GenerateMocks([IPFSNode, BlockStore])
void main() {
  late HealthCheckService healthCheckService;
  late MockIPFSNode mockNode;
  late MockBlockStore mockBlockStore;

  setUp(() {
    mockNode = MockIPFSNode();
    mockBlockStore = MockBlockStore();
    healthCheckService = HealthCheckService(mockNode);

    when(mockNode.blockStore).thenReturn(mockBlockStore);
    when(mockNode.peerID).thenReturn('test-peer');
  });

  group('HealthCheckService', () {
    test('checkHealth returns healthy when everything is fine', () async {
      when(mockNode.isRunning).thenReturn(true);
      when(mockNode.peerID).thenReturn('test-peer');
      when(mockNode.getHealthStatus()).thenAnswer(
        (_) async => {
          'network': {'status': 'ok'},
        },
      );
      when(mockNode.connectedPeers).thenAnswer((_) async => []);
      when(
        mockBlockStore.getStatus(),
      ).thenAnswer((_) async => {'total_blocks': 10, 'pinned_blocks': 2});

      final result = await healthCheckService.checkHealth();
      expect(result['status'], equals('healthy'));
      expect(result['peerId'], equals('test-peer'));
      expect(result['metrics']['blocks'], equals(10));
      expect(result['metrics']['pinned'], equals(2));
    });

    test('checkHealth returns starting when node is not running', () async {
      when(mockNode.isRunning).thenReturn(false);
      when(mockNode.getHealthStatus()).thenAnswer((_) async => {});
      when(mockNode.connectedPeers).thenAnswer((_) async => []);
      when(mockBlockStore.getStatus()).thenAnswer((_) async => {});

      final result = await healthCheckService.checkHealth();
      expect(result['status'], equals('starting'));
    });

    test('checkHealth returns degraded when errors are present', () async {
      when(mockNode.isRunning).thenReturn(true);
      when(mockNode.getHealthStatus()).thenAnswer(
        (_) async => {
          'storage': {
            'disk': {'status': 'error', 'message': 'disk full'},
          },
        },
      );
      when(mockNode.connectedPeers).thenAnswer((_) async => []);
      when(mockBlockStore.getStatus()).thenAnswer((_) async => {});

      final result = await healthCheckService.checkHealth();
      expect(result['status'], equals('degraded'));
    });
  });
}
