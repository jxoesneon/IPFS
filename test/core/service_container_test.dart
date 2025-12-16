import 'package:dart_ipfs/src/core/di/service_container.dart';
import 'package:test/test.dart';

class TestService {
  final int value;
  TestService(this.value);
}

void main() {
  group('ServiceContainer', () {
    late ServiceContainer container;

    setUp(() {
      container = ServiceContainer();
    });

    test('should register and retrieve singleton', () {
      final service = TestService(1);
      container.registerSingleton<TestService>(service);

      expect(container.isRegistered(TestService), isTrue);
      expect(container.get<TestService>(), same(service));
      // Repeated access returns same instance
      expect(container.get<TestService>(), same(service));
    });

    test('should register and retrieve factory', () {
      int factoryCallCount = 0;
      container.registerFactory<TestService>(() {
        factoryCallCount++;
        return TestService(factoryCallCount);
      });

      expect(container.isRegistered(TestService), isTrue);
      expect(factoryCallCount, 0); // Lazy

      final instance1 = container.get<TestService>();
      expect(factoryCallCount, 1);
      expect(instance1.value, 1);

      // Subsequent calls return the SAME instance (singleton behavior for factory result)
      // Documentation says: "result is cached as a singleton for subsequent calls"
      final instance2 = container.get<TestService>();
      expect(factoryCallCount, 1); // Should not increase
      expect(instance2, same(instance1));
    });

    test('should throw if service not registered', () {
      expect(() => container.get<TestService>(), throwsA(isA<Exception>()));
      expect(container.isRegistered(TestService), isFalse);
    });

    test('should distinguish between different types', () {
      container.registerSingleton<String>('test');
      container.registerSingleton<int>(123);

      expect(container.get<String>(), 'test');
      expect(container.get<int>(), 123);
    });
  });
}
