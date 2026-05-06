import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:dart_ipfs/src/core/ipfs_node/lifecycle_manager.dart';
import 'package:dart_ipfs/src/core/interfaces/i_lifecycle.dart';

@GenerateNiceMocks([MockSpec<ILifecycle>()])
import 'lifecycle_manager_test.mocks.dart';

void main() {
  group('LifecycleManager', () {
    late LifecycleManager manager;
    late MockILifecycle mockService1;
    late MockILifecycle mockService2;

    setUp(() {
      manager = LifecycleManager();
      mockService1 = MockILifecycle();
      mockService2 = MockILifecycle();
    });

    test('register adds service to list', () {
      manager.register(mockService1);
      manager.register(mockService2);
      expect(manager.isRunning, isFalse);
    });

    test('startAll starts all services in order', () async {
      manager.register(mockService1);
      manager.register(mockService2);

      when(mockService1.start()).thenAnswer((_) async {});
      when(mockService2.start()).thenAnswer((_) async {});

      await manager.startAll();

      expect(manager.isRunning, isTrue);
      verifyInOrder([mockService1.start(), mockService2.start()]);
    });

    test('startAll is idempotent', () async {
      manager.register(mockService1);
      when(mockService1.start()).thenAnswer((_) async {});

      await manager.startAll();
      await manager.startAll(); // Should not throw

      verify(mockService1.start()).called(1);
    });

    test('startAll stops all services if one fails', () async {
      manager.register(mockService1);
      manager.register(mockService2);

      when(mockService1.start()).thenAnswer((_) async {});
      when(mockService2.start()).thenThrow(Exception('Service failed'));
      when(mockService1.stop()).thenAnswer((_) async {});

      await expectLater(() => manager.startAll(), throwsException);
      verify(mockService1.stop()).called(1);
    });

    test('stopAll stops all services in reverse order', () async {
      manager.register(mockService1);
      manager.register(mockService2);

      when(mockService1.stop()).thenAnswer((_) async {});
      when(mockService2.stop()).thenAnswer((_) async {});

      await manager.stopAll();

      verifyInOrder([mockService2.stop(), mockService1.stop()]);
    });

    test('stopAll continues if one service fails to stop', () async {
      manager.register(mockService1);
      manager.register(mockService2);

      when(mockService1.stop()).thenThrow(Exception('Stop failed'));
      when(mockService2.stop()).thenAnswer((_) async {});

      await manager.stopAll(); // Should not throw

      verify(mockService1.stop()).called(1);
      verify(mockService2.stop()).called(1);
    });

    test('register warns when adding service while running', () async {
      manager.register(mockService1);
      when(mockService1.start()).thenAnswer((_) async {});

      await manager.startAll();
      manager.register(mockService2); // Should log warning but not throw

      expect(manager.isRunning, isTrue);
    });

    test('startAll and stopAll with no services', () async {
      // Should not throw when no services are registered
      await manager.startAll();
      expect(manager.isRunning, isTrue);

      await manager.stopAll();
      expect(manager.isRunning, isFalse);
    });

    test('stopAll when not running', () async {
      manager.register(mockService1);
      when(mockService1.stop()).thenAnswer((_) async {});

      await manager.stopAll(); // Should not throw even if not running

      verify(mockService1.stop()).called(1);
      expect(manager.isRunning, isFalse);
    });
  });
}
