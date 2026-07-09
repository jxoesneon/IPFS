// lib/src/services/pinning/remote_pinning_service.dart
//
// Remote Pinning Service manager.
//
// Manages multiple remote pinning service registrations and coordinates
// pin/unpin operations across them. Integrates with the local [PinManager]
// to track which CIDs are pinned remotely.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/data_structures/pin_manager.dart';
import '../../utils/logger.dart';
import 'pinning_service_api.dart';

/// Configuration for a registered pinning service.
class PinningServiceConfig {

  /// Parses from a JSON map.
  factory PinningServiceConfig.fromJson(Map<String, dynamic> json) {
    return PinningServiceConfig(
      name: json['name'] as String,
      endpoint: json['endpoint'] as String,
      token: json['token'] as String,
    );
  }
  /// Creates a [PinningServiceConfig].
  const PinningServiceConfig({
    required this.name,
    required this.endpoint,
    required this.token,
  });

  /// Human-readable name for the service (e.g. "pinata", "filebase").
  final String name;

  /// API endpoint URL.
  final String endpoint;

  /// Authentication token.
  final String token;

  /// Converts to a JSON-serializable map.
  Map<String, dynamic> toJson() => {
    'name': name,
    'endpoint': endpoint,
    'token': token,
  };
}

/// A remote pin tracked by the [RemotePinningService].
class RemotePin {
  /// Creates a [RemotePin].
  RemotePin({
    required this.cid,
    required this.serviceName,
    required this.requestId,
    required this.status,
    this.name,
    this.created,
  });

  /// The CID of the pinned content.
  final String cid;

  /// The name of the pinning service.
  final String serviceName;

  /// The request ID from the pinning service.
  final String requestId;

  /// Current status of the remote pin.
  final PinStatus status;

  /// Optional name for the pin.
  final String? name;

  /// Creation timestamp.
  final String? created;

  /// Converts to a JSON-serializable map.
  Map<String, dynamic> toJson() => {
    'cid': cid,
    'serviceName': serviceName,
    'requestId': requestId,
    'status': status.toApiString(),
    if (name != null) 'name': name,
    if (created != null) 'created': created,
  };
}

/// Manages multiple remote pinning services and coordinates pin operations.
class RemotePinningService {
  /// Creates a [RemotePinningService].
  ///
  /// [pinManager] is the local pin manager for integration.
  /// [configPath] is the path to persist service registrations.
  RemotePinningService({PinManager? pinManager, String? configPath})
    : _pinManager = pinManager,
      _configPath = configPath,
      _logger = Logger('RemotePinningService');

  final PinManager? _pinManager;
  final String? _configPath;
  final Logger _logger;

  /// Registered pinning services, keyed by name.
  final Map<String, PinningServiceConfig> _services = {};

  /// API clients for each registered service.
  final Map<String, PinningServiceAPIClient> _clients = {};

  /// Remote pins tracked by this manager, keyed by "serviceName:requestId".
  final Map<String, RemotePin> _remotePins = {};

  /// Returns the list of registered service configurations.
  List<PinningServiceConfig> get services => _services.values.toList();

  /// Returns the list of registered service names.
  List<String> get serviceNames => _services.keys.toList();

  /// Returns all tracked remote pins.
  List<RemotePin> get remotePins => _remotePins.values.toList();

  /// Returns the local pin manager, if available.
  PinManager? get pinManager => _pinManager;

  /// Registers a pinning service.
  ///
  /// [name] is a unique identifier for the service.
  /// [endpoint] is the API endpoint URL.
  /// [token] is the authentication token.
  void addService({
    required String name,
    required String endpoint,
    required String token,
  }) {
    if (_services.containsKey(name)) {
      throw ArgumentError('Pinning service "$name" is already registered');
    }

    final config = PinningServiceConfig(
      name: name,
      endpoint: endpoint,
      token: token,
    );
    _services[name] = config;
    _clients[name] = PinningServiceAPIClient(endpoint: endpoint, token: token);
    _logger.info('Registered pinning service: $name');
    unawaited(_saveConfig());
  }

  /// Removes a registered pinning service by [name].
  ///
  /// Does not remove pins already created on the remote service.
  void removeService(String name) {
    if (!_services.containsKey(name)) {
      throw ArgumentError('Pinning service "$name" is not registered');
    }
    _clients[name]?.dispose();
    _clients.remove(name);
    _services.remove(name);
    _logger.info('Removed pinning service: $name');
    unawaited(_saveConfig());
  }

  /// Lists registered services.
  List<Map<String, dynamic>> listServices() {
    return _services.values.map((s) => s.toJson()).toList();
  }

  /// Pins content on a remote pinning service.
  ///
  /// [serviceName] specifies which registered service to use.
  /// [cid] is the content identifier to pin.
  /// [name] is an optional human-readable name for the pin.
  /// [origins] are optional multiaddrs for the service to fetch content from.
  Future<RemotePin> pin({
    required String serviceName,
    required String cid,
    String? name,
    List<String> origins = const [],
    Map<String, dynamic> meta = const {},
  }) async {
    final client = _getClient(serviceName);

    _logger.debug('Pinning $cid on service $serviceName');

    final request = PinRequest(
      cid: cid,
      name: name,
      origins: origins,
      meta: meta,
    );

    final response = await client.addPin(request);

    final remotePin = RemotePin(
      cid: cid,
      serviceName: serviceName,
      requestId: response.requestId,
      status: response.status,
      name: name,
      created: response.created,
    );

    final key = '$serviceName:${response.requestId}';
    _remotePins[key] = remotePin;
    await _saveConfig();

    _logger.info(
      'Pinned $cid on $serviceName with request ID ${response.requestId}',
    );

    return remotePin;
  }

  /// Unpins content from a remote pinning service.
  ///
  /// [serviceName] specifies which registered service to use.
  /// [requestId] is the pin request ID returned by the service.
  Future<void> unpin({
    required String serviceName,
    required String requestId,
  }) async {
    final client = _getClient(serviceName);

    _logger.debug('Unpinning request $requestId on service $serviceName');

    await client.removePin(requestId);

    final key = '$serviceName:$requestId';
    _remotePins.remove(key);
    await _saveConfig();

    _logger.info('Unpinned request $requestId on $serviceName');
  }

  /// Syncs the status of a remote pin from the pinning service.
  ///
  /// Returns the updated [RemotePin].
  Future<RemotePin> syncPin({
    required String serviceName,
    required String requestId,
  }) async {
    final client = _getClient(serviceName);

    final response = await client.getPin(requestId);

    final key = '$serviceName:$requestId';
    final existing = _remotePins[key];

    final updated = RemotePin(
      cid: response.pin.cid,
      serviceName: serviceName,
      requestId: response.requestId,
      status: response.status,
      name: existing?.name ?? response.pin.name,
      created: response.created,
    );

    _remotePins[key] = updated;
    await _saveConfig();

    return updated;
  }

  /// Syncs all tracked remote pins.
  Future<List<RemotePin>> syncAll() async {
    final results = <RemotePin>[];
    final keys = _remotePins.keys.toList();

    for (final key in keys) {
      final pin = _remotePins[key]!;
      try {
        final updated = await syncPin(
          serviceName: pin.serviceName,
          requestId: pin.requestId,
        );
        results.add(updated);
      } catch (e) {
        _logger.warning('Failed to sync pin $key: $e');
      }
    }

    return results;
  }

  /// Lists remote pins, optionally filtered by service name or status.
  List<RemotePin> listRemotePins({String? serviceName, PinStatus? status}) {
    return _remotePins.values.where((pin) {
      if (serviceName != null && pin.serviceName != serviceName) return false;
      if (status != null && pin.status != status) return false;
      return true;
    }).toList();
  }

  /// Lists pins from the remote service (queries the service directly).
  Future<PinListResponse> listServicePins(
    String serviceName, {
    PinListFilter? filter,
  }) async {
    final client = _getClient(serviceName);
    return client.listPins(filter: filter);
  }

  /// Returns true if a service with [name] is registered.
  bool hasService(String name) => _services.containsKey(name);

  /// Returns the [PinningServiceAPIClient] for [serviceName].
  PinningServiceAPIClient getClient(String serviceName) =>
      _getClient(serviceName);

  PinningServiceAPIClient _getClient(String serviceName) {
    final client = _clients[serviceName];
    if (client == null) {
      throw ArgumentError(
        'Pinning service "$serviceName" is not registered. '
        'Available services: ${_services.keys.toList()}',
      );
    }
    return client;
  }

  /// Loads service configurations and tracked pins from the config path.
  Future<void> load() async {
    if (_configPath == null) return;

    try {
      final file = File(_configPath);
      if (!await file.exists()) return;

      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      // Load services
      final servicesRaw = data['services'] as List? ?? [];
      for (final serviceRaw in servicesRaw) {
        final config = PinningServiceConfig.fromJson(
          serviceRaw as Map<String, dynamic>,
        );
        _services[config.name] = config;
        _clients[config.name] = PinningServiceAPIClient(
          endpoint: config.endpoint,
          token: config.token,
        );
      }

      // Load remote pins
      final pinsRaw = data['remotePins'] as List? ?? [];
      for (final pinRaw in pinsRaw) {
        final pinMap = pinRaw as Map<String, dynamic>;
        final pin = RemotePin(
          cid: pinMap['cid'] as String,
          serviceName: pinMap['serviceName'] as String,
          requestId: pinMap['requestId'] as String,
          status: PinStatus.fromString(pinMap['status'] as String?),
          name: pinMap['name'] as String?,
          created: pinMap['created'] as String?,
        );
        _remotePins['${pin.serviceName}:${pin.requestId}'] = pin;
      }

      _logger.info(
        'Loaded ${_services.length} services and ${_remotePins.length} remote pins',
      );
    } catch (e) {
      _logger.error('Failed to load remote pinning config: $e');
    }
  }

  /// Saves service configurations and tracked pins to the config path.
  Future<void> _saveConfig() async {
    if (_configPath == null) return;

    try {
      final data = {
        'services': _services.values.map((s) => s.toJson()).toList(),
        'remotePins': _remotePins.values.map((p) => p.toJson()).toList(),
      };

      final file = File(_configPath);
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      _logger.error('Failed to save remote pinning config: $e');
    }
  }

  /// Disposes all resources.
  void dispose() {
    for (final client in _clients.values) {
      client.dispose();
    }
    _clients.clear();
  }
}
