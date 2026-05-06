// src/core/di/service_container.dart
import 'package:get_it/get_it.dart';

/// Service container for dependency injection.
class ServiceContainer {
  final GetIt _getIt = GetIt.instance;

  /// Registers a service in the container as a singleton.
  void registerSingleton<T extends Object>(T service) {
    if (_getIt.isRegistered<T>()) {
      _getIt.unregister<T>();
    }
    _getIt.registerSingleton<T>(service);
  }

  /// Registers a factory for a service.
  void registerFactory<T extends Object>(T Function() factory) {
    if (_getIt.isRegistered<T>()) {
      _getIt.unregister<T>();
    }
    _getIt.registerLazySingleton<T>(factory);
  }

  /// Retrieves a service from the container.
  T get<T extends Object>() {
    return _getIt.get<T>();
  }

  /// Checks if a service is registered.
  bool isRegistered<T extends Object>([Type? type]) {
    if (type != null) {
      return _getIt.isRegistered(type: type);
    }
    return _getIt.isRegistered<T>();
  }

  /// Checks if a service is registered by type.
  bool isRegisteredByType(Type type) {
    return _getIt.isRegistered(type: type);
  }
}
