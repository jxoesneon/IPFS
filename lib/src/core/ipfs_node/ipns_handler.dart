// src/core/ipfs_node/ipns_handler.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/security/security_manager.dart';
import 'package:dart_ipfs/src/protocols/ipns/ipns_handler.dart' as protocol;

/// Handles IPNS operations at the node level, coordinating between DHT, security,
/// and protocol layers
class IPNSHandler {
  final IPFSConfig _config;
  final SecurityManager _securityManager;
  late final Logger _logger;
  late final protocol.IPNSHandler _protocolHandler;
  bool _isRunning = false;

  // Cache for resolved IPNS records
  final Map<String, _CachedResolution> _resolutionCache = {};
  static const Duration _cacheDuration = Duration(minutes: 30);

  IPNSHandler(this._config, this._securityManager) {
    _logger = Logger('IPNSHandler',
        debug: _config.debug, verbose: _config.verboseLogging);
    _logger.debug('IPNSHandler instance created');
  }

  /// Starts the IPNS handler
  Future<void> start() async {
    if (_isRunning) {
      _logger.warning('IPNSHandler already running');
      return;
    }

    try {
      _logger.debug('Starting IPNSHandler...');
      _isRunning = true;
      _logger.info('IPNSHandler started successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to start IPNSHandler', e, stackTrace);
      rethrow;
    }
  }

  /// Stops the IPNS handler
  Future<void> stop() async {
    if (!_isRunning) {
      _logger.warning('IPNSHandler already stopped');
      return;
    }

    try {
      _logger.debug('Stopping IPNSHandler...');
      _resolutionCache.clear();
      _isRunning = false;
      _logger.info('IPNSHandler stopped successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to stop IPNSHandler', e, stackTrace);
      rethrow;
    }
  }

  /// Publishes an IPNS record linking a name to a CID
  Future<void> publish(String cid, {required String keyName}) async {
    _logger.debug('Publishing IPNS record for CID: $cid with key: $keyName');

    try {
      // Verify CID format
      if (!_isValidCID(cid)) {
        throw ArgumentError('Invalid CID format');
      }

      // Get key from security manager
      final key = await _securityManager.getPrivateKey(keyName);
      if (key == null) {
        throw ArgumentError('Key not found: $keyName');
      }

      // Create and publish record
      final record = await _protocolHandler.createRecord(
        CID.decode(cid),
        key,
      );

      await _protocolHandler.publishRecord(record);
      _logger.info('Successfully published IPNS record for CID: $cid');
    } catch (e, stackTrace) {
      _logger.error('Failed to publish IPNS record', e, stackTrace);
      rethrow;
    }
  }

  /// Resolves an IPNS name to its current CID
  Future<String?> resolve(String name) async {
    _logger.debug('Resolving IPNS name: $name');

    try {
      // Check cache first
      if (_resolutionCache.containsKey(name)) {
        final cached = _resolutionCache[name]!;
        if (!cached.isExpired) {
          _logger.verbose('Returning cached resolution for: $name');
          return cached.cid;
        }
        _resolutionCache.remove(name);
      }

      // Resolve through protocol handler
      final record = await _protocolHandler.resolveRecord(name);
      final resolvedCid = String.fromCharCodes(record.value);

      // Cache the result
      _cacheResolution(name, resolvedCid);

      _logger
          .info('Successfully resolved IPNS name: $name to CID: $resolvedCid');
      return resolvedCid;
    } catch (e, stackTrace) {
      _logger.error('Failed to resolve IPNS name', e, stackTrace);
      return null;
    }
  }

  /// Gets the current status of the IPNS handler
  Future<Map<String, dynamic>> getStatus() async {
    return {
      'running': _isRunning,
      'cache_size': _resolutionCache.length,
      'cache_duration_minutes': _cacheDuration.inMinutes,
    };
  }

  bool _isValidCID(String cid) {
    return cid.isNotEmpty && RegExp(r'^[a-zA-Z0-9]+$').hasMatch(cid);
  }

  void _cacheResolution(String name, String cid) {
    _logger.verbose('Caching IPNS resolution for: $name');
    _resolutionCache[name] = _CachedResolution(
      cid: cid,
      timestamp: DateTime.now(),
    );
  }
}

/// Helper class for caching IPNS resolutions
class _CachedResolution {
  final String cid;
  final DateTime timestamp;

  _CachedResolution({
    required this.cid,
    required this.timestamp,
  });

  bool get isExpired =>
      DateTime.now().difference(timestamp) > IPNSHandler._cacheDuration;
}
