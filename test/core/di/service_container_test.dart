import 'package:dart_ipfs/src/core/di/service_container.dart';
import 'package:get_it/get_it.dart';
import 'package:test/test.dart';

class _ServiceA {
  final String value;
  _ServiceA(this.value);
}

class _ServiceB {
  final int value;
  _ServiceB(this.value);
}

void main() {
  group('ServiceContainer', () {
    setUp(() async {
      await GetIt.instance.reset();
    });

    test('registerSingleton stores and retrieves value', () {
      final container = ServiceContainer();
      container.registerSingleton<_ServiceA>(_ServiceA('first'));
      expect(container.get<_ServiceA>().value, equals('first'));
    });

    test('registerSingleton replaces an existing registration', () {
      final container = ServiceContainer();
      container.registerSingleton<_ServiceA>(_ServiceA('first'));
      container.registerSingleton<_ServiceA>(_ServiceA('second'));
      expect(container.get<_ServiceA>().value, equals('second'));
    });

    test('registerFactory lazily creates the instance', () {
      final container = ServiceContainer();
      var calls = 0;
      container.registerFactory<_ServiceB>(() {
        calls++;
        return _ServiceB(7);
      });
      expect(calls, equals(0));
      expect(container.get<_ServiceB>().value, equals(7));
      // Lazy singleton: subsequent gets reuse the same instance.
      expect(container.get<_ServiceB>().value, equals(7));
      expect(calls, equals(1));
    });

    test('registerFactory replaces an existing factory', () {
      final container = ServiceContainer();
      container.registerFactory<_ServiceB>(() => _ServiceB(1));
      container.registerFactory<_ServiceB>(() => _ServiceB(2));
      expect(container.get<_ServiceB>().value, equals(2));
    });

    test('isRegistered reports registration state', () {
      final container = ServiceContainer();
      expect(container.isRegistered<_ServiceA>(), isFalse);
      container.registerSingleton<_ServiceA>(_ServiceA('x'));
      expect(container.isRegistered<_ServiceA>(), isTrue);
      expect(container.isRegistered(_ServiceA), isTrue);
      expect(container.isRegisteredByType(_ServiceA), isTrue);
      expect(container.isRegisteredByType(_ServiceB), isFalse);
    });
  });
}
