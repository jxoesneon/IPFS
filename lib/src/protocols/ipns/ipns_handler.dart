import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/protocols/ipns/ipns_record.dart';
import 'package:dart_ipfs/src/utils/logger.dart';

/// Handles IPNS (InterPlanetary Name System) operations.
///
/// Supported backends:
/// - DHT (Distributed Hash Table)
/// - PubSub (for real-time updates)
class IPNSHandler {
  /// Creates a new [IPNSHandler].
  IPNSHandler(
    this._config, [
    this._securityManager,
    this._dhtHandler,
    this._pubsubHandler,
  ]) : _cache = <String, IPNSRecord>{},
       _maxCacheSize = _config.ipnsCacheSize,
       _logger = Logger('IPNSHandler') {
    _logger.info('Initializing IPNSHandler');
  }

  // ignore: unused_field
  final IPFSConfig _config;
  // ignore: unused_field
  final dynamic _securityManager;
  // ignore: unused_field
  final dynamic _dhtHandler;
  // ignore: unused_field
  final dynamic _pubsubHandler;

  final Map<String, IPNSRecord> _cache;
  final int _maxCacheSize;
  final Logger _logger;

  /// Resolves an IPNS [name] to its corresponding CID.
  Future<String> resolve(String name) async {
    _logger.debug('Resolving IPNS name: $name');

    // Check cache first
    if (_cache.containsKey(name)) {
      final record = _cache[name]!;
      if (!record.isExpired) {
        _logger.verbose('IPNS cache hit for: $name');
        // Move to end (MRU)
        _cache.remove(name);
        _cache[name] = record;
        return utf8.decode(record.value);
      }
      _cache.remove(name);
    }

    // Resolve via DHT (Mocked for now)
    final resolvedCid = await _resolveViaDHT(name);

    // Cache the result
    _addToCache(
      name,
      IPNSRecord.internal(
        value: Uint8List.fromList(utf8.encode(resolvedCid)),
        validity: DateTime.now().add(const Duration(hours: 1)),
      ),
    );

    return resolvedCid;
  }

  /// Publishes a [cid] to IPNS under the given [name].
  Future<void> publish(String name, String cid, {String? keyName}) async {
    _logger.info('Publishing IPNS record: $name -> $cid (key: $keyName)');

    // Implementation for publishing to DHT
    await _publishToDHT(name, cid);

    // Update cache
    _addToCache(
      name,
      IPNSRecord.internal(
        value: Uint8List.fromList(utf8.encode(cid)),
        validity: DateTime.now().add(const Duration(hours: 24)),
      ),
    );
  }

  void _addToCache(String name, IPNSRecord record) {
    if (_cache.length >= _maxCacheSize) {
      final firstKey = _cache.keys.first;
      _cache.remove(firstKey);
      _logger.verbose('Evicted oldest IPNS cache entry: $firstKey');
    }
    _cache[name] = record;
  }

  Future<String> _resolveViaDHT(String name) async {
    // Mock DHT resolution
    return 'QmResolvedCid';
  }

  Future<void> _publishToDHT(String name, String cid) async {
    // Mock DHT publish
  }

  /// Returns the current status of the IPNS handler.
  Future<Map<String, dynamic>> getStatus() async {
    return {'cache_size': _cache.length, 'max_cache_size': _maxCacheSize};
  }
}
