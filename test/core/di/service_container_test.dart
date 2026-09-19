import 'package:dart_ipfs/src/core/di/service_container.dart';
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

    test('containers are isolated scopes — no shared registry', () {
      final first = ServiceContainer();
      final second = ServiceContainer();

      first.registerSingleton<_ServiceA>(_ServiceA('scoped'));

      expect(first.isRegistered<_ServiceA>(), isTrue);
      // A different container must not see registrations made elsewhere:
      // this is what keeps two IPFSNodes' services from cross-wiring.
      expect(second.isRegistered<_ServiceA>(), isFalse);
      expect(() => second.get<_ServiceA>(), throwsStateError);

      second.registerSingleton<_ServiceA>(_ServiceA('other'));
      expect(first.get<_ServiceA>().value, equals('scoped'));
      expect(second.get<_ServiceA>().value, equals('other'));
    });
  });
}
