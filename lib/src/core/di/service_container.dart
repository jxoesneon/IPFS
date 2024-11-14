// src/core/di/service_container.dart
typedef Factory<T> = T Function();

class ServiceContainer {
  final Map<Type, dynamic> _services = {};
  final Map<Type, Factory> _factories = {};

  void registerSingleton<T>(T instance) {
    _services[T] = instance;
  }

  void registerFactory<T>(Factory<T> factory) {
    _factories[T] = factory;
  }

  T get<T>() {
    if (_services.containsKey(T)) {
      return _services[T] as T;
    }
    if (_factories.containsKey(T)) {
      final instance = _factories[T]!() as T;
      _services[T] = instance;
      return instance;
    }
    throw Exception('Service not registered: $T');
  }

  bool isRegistered(Type type) {
    return _services.containsKey(type) || _factories.containsKey(type);
  }
}
