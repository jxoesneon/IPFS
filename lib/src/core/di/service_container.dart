// src/core/di/service_container.dart

/// A factory function that creates instances of type [T].
typedef Factory<T> = T Function();

/// A lightweight dependency injection container for managing service lifecycles.
///
/// ServiceContainer provides a simple IoC (Inversion of Control) mechanism
/// for registering and resolving dependencies throughout the IPFS node.
/// It supports both singleton instances and lazy factory creation.
///
/// **Singleton Registration:**
/// ```dart
/// final container = ServiceContainer();
/// container.registerSingleton<Logger>(Logger());
///
/// // Always returns the same instance
/// final logger = container.get<Logger>();
/// ```
///
/// **Factory Registration:**
/// ```dart
/// container.registerFactory<HttpClient>(() => HttpClient());
///
/// // Creates instance on first access, then returns singleton
/// final client = container.get<HttpClient>();
/// ```
///
/// See also:
/// - [IPFSNodeBuilder] which uses this container for node construction
class ServiceContainer {
  final Map<Type, dynamic> _services = {};
  final Map<Type, Factory<dynamic>> _factories = {};

  /// Registers a singleton instance of type [T].
  ///
  /// The same [instance] will be returned for all subsequent [get] calls.
  void registerSingleton<T>(T instance) {
    _services[T] = instance;
  }

  /// Registers a factory function for type [T].
  ///
  /// The factory is invoked lazily on first [get] call, and the result
  /// is cached as a singleton for subsequent calls.
  void registerFactory<T>(Factory<T> factory) {
    _factories[T] = factory;
  }

  /// Retrieves the registered service of type [T].
  ///
  /// Throws [Exception] if no service of type [T] is registered.
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

  /// Returns `true` if a service of the given [type] is registered.
  bool isRegistered(Type type) {
    return _services.containsKey(type) || _factories.containsKey(type);
  }
}

