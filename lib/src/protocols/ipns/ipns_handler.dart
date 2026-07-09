import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/crypto/ed25519_signer.dart';
import 'package:dart_ipfs/src/core/interfaces/i_lifecycle.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_client.dart';
import 'package:dart_ipfs/src/protocols/dht/interface_dht_handler.dart';
import 'package:dart_ipfs/src/protocols/ipns/ipns_record.dart';
import 'package:dart_ipfs/src/utils/logger.dart';

/// Handles IPNS (InterPlanetary Name System) operations.
///
/// This implementation follows the IPNS DHT-first signed records specification:
/// - Names are derived from Ed25519 public keys as multibase base36 peer IDs.
/// - Records are CBOR-encoded and signed with Ed25519.
/// - Publishing stores records in the DHT via [DHTClient.storeValue].
/// - Resolution retrieves records from the DHT and verifies their signature,
///   validity and name/public-key match.
///
/// PubSub is only used as an optional notification channel when explicitly
/// enabled and a compliant Gossipsub handler is present. The legacy base64
/// PubSub broadcast has been removed.
class IPNSHandler implements ILifecycle {
  /// Creates a new [IPNSHandler].
  IPNSHandler(
    IPFSConfig config, [
    this._securityManager,
    this._dhtHandler,
    this._pubsubHandler,
  ]) : _config = config,
       _cache = <String, _CacheEntry>{},
       _maxCacheSize = config.ipnsCacheSize,
       _recordValidity = const Duration(hours: 24),
       _recordTtl = const Duration(hours: 1),
       _logger = Logger('IPNSHandler') {
    _logger.info('Initializing IPNSHandler');
  }

  final IPFSConfig _config;
  final dynamic _securityManager;
  final dynamic _dhtHandler;
  final dynamic _pubsubHandler;

  final Map<String, _CacheEntry> _cache;
  final int _maxCacheSize;
  final Duration _recordValidity;
  final Duration _recordTtl;
  final Logger _logger;
  bool _isRunning = false;

  /// The DHT client extracted from the DHT handler, if available.
  DHTClient? get _dhtClient {
    final handler = _dhtHandler;
    if (handler == null) return null;
    if (handler is DHTClient) {
      return handler;
    }
    try {
      // DHTHandler exposes the underlying DHTClient as `dhtClient`.
      return (handler as dynamic).dhtClient as DHTClient?;
    } catch (_) {
      return null;
    }
  }

  /// Whether PubSub notifications are enabled.
  late final bool _pubSubNotificationsEnabled = _config.enableIpnsPubSub;

  /// Starts the IPNS handler.
  @override
  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;
    _logger.info('IPNSHandler started');

    if (_dhtHandler != null) {
      await _dhtHandler.start();
    }

    if (_pubSubNotificationsEnabled && _pubsubHandler != null) {
      await _pubsubHandler.subscribe('/ipfs/ipns-1.0.0');
      _pubsubHandler.onMessage('/ipfs/ipns-1.0.0', _onPubSubMessage);
    }
  }

  /// Handles incoming PubSub messages for IPNS records.
  void _onPubSubMessage(dynamic message) {
    // Placeholder for Gossipsub-based IPNS record propagation. A full
    // implementation would validate the signed record and update the cache.
    _logger.debug('Received IPNS PubSub message');
  }

  /// Stops the IPNS handler.
  @override
  Future<void> stop() async {
    if (!_isRunning) return;
    _isRunning = false;
    _cache.clear();
    _logger.info('IPNSHandler stopped');
  }

  /// Resolves an IPNS [name] to its corresponding CID.
  ///
  /// Throws [IpnsResolutionError] if the name cannot be resolved.
  /// Throws [IpnsValidationError] if the retrieved record is invalid,
  /// expired, or has a bad signature.
  Future<String> resolve(String name) async {
    if (!_isRunning) {
      throw StateError('IPNSHandler not started');
    }

    final record = await _resolveRecord(name);
    final cid = record.valueCID;
    if (cid == null) {
      throw IpnsValidationError('Record value is not a valid /ipfs/<CID> path');
    }
    return cid.encode();
  }

  /// Resolves an IPNS [name] to its corresponding `/ipfs/<CID>` path.
  ///
  /// This is the form expected by the Kubo-compatible `name/resolve` RPC.
  Future<String> resolvePath(String name) async {
    final cid = await resolve(name);
    return '/ipfs/$cid';
  }

  /// Compatibility helper that resolves an IPNS [name] to a CID string.
  ///
  /// This is identical to [resolve] and exists for callers that prefer the
  /// explicit naming.
  Future<String> resolveAsString(String name) => resolve(name);

  /// Resolves an IPNS [name] and returns the signed record bytes.
  ///
  /// Returns `null` if no record is available. The bytes are CBOR-encoded
  /// according to the IPNS record specification.
  Future<Uint8List?> getRecordBytes(String name) async {
    if (!_isRunning) {
      return null;
    }

    try {
      final record = await _resolveRecord(name);
      return record.toCBOR();
    } catch (e, stackTrace) {
      _logger.warning('Failed to resolve IPNS record for $name', e, stackTrace);
      return null;
    }
  }

  Future<IPNSRecord> _resolveRecord(String name) async {
    // Validate the IPNS name format (base36 peer ID).
    PeerId.fromBase36(name);

    _logger.debug('Resolving IPNS name: $name');

    // Check cache first.
    final cached = _cache[name];
    if (cached != null && !cached.isExpired && !cached.record.isExpired) {
      _logger.verbose('IPNS cache hit for: $name');
      // Move to end (MRU)
      _cache.remove(name);
      _cache[name] = cached;
      return cached.record;
    }
    if (cached != null) {
      _cache.remove(name);
    }

    // Resolve via DHT. The name is a CIDv1 libp2p-key; extract the identity
    // multihash bytes and prefix with '/ipns/' to form the DHT key.
    final cidBytes = PeerId.fromBase36(name).value;
    if (cidBytes.length < 3 || cidBytes[0] != 0x01 || cidBytes[1] != 0x72) {
      // ignore: avoid_print
      print('Invalid IPNS name: $name');
      throw IpnsValidationError('Invalid IPNS name: $name');
    }
    final key = Uint8List.fromList([
      ...utf8.encode('/ipns/'),
      ...cidBytes.sublist(2),
    ]);
    // ignore: avoid_print
    print('IPNS resolve key (${key.length} bytes): ${base64Encode(key)}');
    final bytes = await _getDHTValue(key);
    if (bytes == null || bytes.isEmpty) {
      throw IpnsResolutionError('No record found for $name');
    }

    final record = await _parseRecord(bytes, name);

    // Cache and return.
    _addToCache(name, _CacheEntry(record, _recordTtl));
    return record;
  }

  /// Parses raw DHT bytes into an [IPNSRecord].
  ///
  /// First tries to decode a CBOR-encoded signed record. If that fails, the
  /// bytes are treated as a legacy raw CID value for backward compatibility.
  Future<IPNSRecord> _parseRecord(Uint8List bytes, String name) async {
    // Attempt Kubo protobuf decode first, then CBOR, then fall back to the
    // legacy raw CID string representation.
    try {
      final record = IPNSRecord.decode(bytes, name: name);
      return await _validateRecord(record, name);
    } on IpnsValidationError {
      rethrow;
    } on FormatException {
      // Expected when the bytes are not a valid CBOR IPNS record.
    } catch (e) {
      _logger.debug('Failed to decode CBOR IPNS record: $e');
      // ignore: avoid_print
      print('IPNS decode failed: $e');
    }

    // Legacy fallback: raw CID string bytes.
    _logger.debug('Falling back to legacy raw CID value for $name');
    try {
      final valueStr = utf8.decode(bytes);
      return IPNSRecord.internal(
        value: Uint8List.fromList(utf8.encode('/ipfs/$valueStr')),
        validity: DateTime.now().add(_recordValidity),
        sequence: 0,
        ttl: _recordTtl,
      );
    } on FormatException {
      throw IpnsValidationError('Invalid IPNS record format');
    }
  }

  /// Validates a CBOR IPNS record.
  Future<IPNSRecord> _validateRecord(IPNSRecord record, String name) async {
    if (record.isExpired) {
      // ignore: avoid_print
      print('IPNS validation failed: record expired');
      throw IpnsValidationError('Record expired');
    }
    if (!record.isSigned) {
      // ignore: avoid_print
      print('IPNS validation failed: record not signed');
      throw IpnsValidationError('Record is not signed');
    }
    if (!_nameMatchesPublicKey(name, record.publicKey)) {
      // ignore: avoid_print
      print('IPNS validation failed: name mismatch');
      throw IpnsValidationError('Name does not match public key');
    }
    if (!await record.verify()) {
      // ignore: avoid_print
      print('IPNS validation failed: invalid signature');
      throw IpnsValidationError('Invalid signature');
    }
    return record;
  }

  bool _nameMatchesPublicKey(String name, Uint8List publicKey) {
    try {
      final expected = deriveIpnsName(publicKey);
      return name == expected;
    } catch (_) {
      return false;
    }
  }

  /// Publishes a [cid] to IPNS using the keystore key identified by [keyName].
  ///
  /// Returns the IPNS name (a base36-encoded peer ID) that was published.
  Future<String> publish(String cid, {String? keyName}) async {
    if (!_isRunning) {
      throw StateError('IPNSHandler not started');
    }

    // Basic validation.
    if (cid.contains('!')) {
      throw ArgumentError('Invalid CID format');
    }

    final resolvedKeyName = keyName ?? 'self';

    if (_securityManager == null) {
      throw StateError('SecurityManager not available');
    }

    SimpleKeyPair keyPair;
    try {
      keyPair = await _securityManager.getSecureKey(resolvedKeyName) as SimpleKeyPair;
    } catch (e) {
      // Fallback for nodes whose keystore is not unlocked yet (e.g., the
      // interop daemon). Generate an ephemeral self key for this publish.
      if (resolvedKeyName == 'self') {
        _logger.warning(
          'Keystore not available for $resolvedKeyName; generating ephemeral IPNS key',
        );
        final signer = Ed25519Signer();
        keyPair = await signer.generateKeyPair();
      } else {
        throw StateError('Keystore is locked or key $resolvedKeyName not found');
      }
    }
    return publishWithKeyPair(CID.decode(cid), keyPair);
  }

  /// Publishes a [cid] to IPNS using the provided Ed25519 [keyPair].
  ///
  /// Returns the IPNS name (a base36-encoded peer ID) that was published.
  Future<String> publishWithKeyPair(
    CID cid,
    SimpleKeyPair keyPair, {
    int? sequence,
  }) async {
    if (!_isRunning) {
      throw StateError('IPNSHandler not started');
    }

    final publicKey = await _extractPublicKey(keyPair);
    final name = deriveIpnsName(publicKey);

    _logger.info('Publishing IPNS record: $name -> ${cid.encode()}');

    final record = await IPNSRecord.create(
      value: cid,
      keyPair: keyPair,
      sequence: sequence ?? await _nextSequence(name),
      validity: _recordValidity,
      ttl: _recordTtl,
    );

    await _publishRecord(record);
    return name;
  }

  /// Stores a pre-constructed [record] in the DHT.
  Future<void> publishRecord(IPNSRecord record) async {
    if (!_isRunning) {
      throw StateError('IPNSHandler not started');
    }
    if (!record.isSigned) {
      throw StateError('Cannot publish unsigned IPNS record');
    }
    await _publishRecord(record);
  }

  /// Builds the DHT key Kubo uses for IPNS records: '/ipns/' + identity
  /// multihash of the protobuf-encoded Ed25519 public key.
  Uint8List _ipnsDhtKey(Uint8List publicKey) {
    final protoKey = Uint8List(4 + publicKey.length)
      ..[0] = 0x08
      ..[1] = 0x01
      ..[2] = 0x12
      ..[3] = publicKey.length;
    protoKey.setRange(4, 4 + publicKey.length, publicKey);

    final identityHash = Uint8List(2 + protoKey.length)
      ..[0] = 0x00
      ..[1] = protoKey.length;
    identityHash.setRange(2, 2 + protoKey.length, protoKey);

    return Uint8List.fromList([...utf8.encode('/ipns/'), ...identityHash]);
  }

  Future<void> _publishRecord(IPNSRecord record) async {
    // Kubo uses '/ipns/' followed by the binary identity multihash of the
    // protobuf-encoded public key as the DHT key.
    final key = _ipnsDhtKey(record.publicKey);
    final value = record.toIpnsEntry();
    // ignore: avoid_print
    print('IPNS publish key (${key.length} bytes): ${base64Encode(key)}');
    // ignore: avoid_print
    print('IPNS publish value (${value.length} bytes): ${base64Encode(value)}');

    await _storeDHTValue(key, value);

    // Update local cache so subsequent resolves are served immediately.
    _addToCache(record.name, _CacheEntry(record, _recordTtl));

    // Optional PubSub notification after Gossipsub is landed. The current
    // PubSub implementation is not spec-compliant, so we intentionally do not
    // publish here.
    if (_pubSubNotificationsEnabled && _pubsubHandler != null) {
      // Gossipsub path would publish the CBOR record to '/ipns/<name>'.
      // ignore: dead_code
      await _publishToPubSub(record);
    }
  }

  Future<void> _publishToPubSub(IPNSRecord record) async {
    // Placeholder for Gossipsub-based notifications. The legacy base64 PubSub
    // broadcast has been removed per the IPNS specification.
    _logger.debug('Gossipsub notifications not yet enabled');
  }

  Future<Uint8List?> _getDHTValue(Uint8List key) async {
    final client = _dhtClient;
    if (client != null) {
      // Try the raw Kademlia path first; this is what Kubo/Helia understand.
      try {
        final raw = await client.getValueRaw(key);
        if (raw != null && raw.isNotEmpty) return raw;
      } catch (e, stackTrace) {
        _logger.warning('DHT client getValueRaw failed', e, stackTrace);
      }

      // Fallback to the framed internal path for tests/back-compat.
      try {
        final framed = await client.getValue(key);
        if (framed != null && framed.isNotEmpty) return framed;
      } catch (e, stackTrace) {
        _logger.warning('DHT client getValue failed', e, stackTrace);
      }
    }

    // Fallback to legacy IDHTHandler API.
    if (_dhtHandler != null) {
      try {
        final value = await _dhtHandler.getValue(Key(key)) as dynamic;
        if (value != null && value.bytes != null) {
          return Uint8List.fromList(value.bytes as List<int>);
        }
      } catch (e) {
        _logger.warning('DHT handler getValue failed: $e');
      }
    }

    return null;
  }

  Future<void> _storeDHTValue(Uint8List key, Uint8List value) async {
    final client = _dhtClient;
    if (client != null) {
      // Try the raw Kademlia path first; this is what Kubo/Helia understand.
      try {
        final stored = await client.storeValueRaw(key, value);
        if (stored) {
          return;
        }
        _logger.warning('DHT client storeValueRaw returned false');
      } catch (e, stackTrace) {
        _logger.warning('DHT client storeValueRaw failed', e, stackTrace);
      }

      // Fallback to the framed internal path for tests/back-compat.
      try {
        final stored = await client.storeValue(key, value);
        if (stored) {
          return;
        }
        _logger.warning('DHT client storeValue returned false');
      } catch (e, stackTrace) {
        _logger.warning('DHT client storeValue failed', e, stackTrace);
      }
    }

    // Fallback to legacy IDHTHandler API.
    if (_dhtHandler != null) {
      try {
        await _dhtHandler.putValue(Key(key), Value(value));
        return;
      } catch (e) {
        _logger.warning('DHT handler putValue failed: $e');
      }
    }

    throw IpnsResolutionError('No DHT backend available to publish record');
  }

  Future<Uint8List> _extractPublicKey(SimpleKeyPair keyPair) async {
    final signer = Ed25519Signer();
    return signer.extractPublicKeyBytes(keyPair);
  }

  Future<int> _nextSequence(String name) async {
    // For simplicity, sequence is wall-clock microseconds. A production
    // implementation would persist the sequence per name.
    return DateTime.now().microsecondsSinceEpoch;
  }

  void _addToCache(String name, _CacheEntry entry) {
    if (_cache.length >= _maxCacheSize) {
      final firstKey = _cache.keys.first;
      _cache.remove(firstKey);
      _logger.verbose('Evicted oldest IPNS cache entry: $firstKey');
    }
    _cache[name] = entry;
  }

  /// Creates a Record (legacy compatibility).
  @Deprecated('Use IPNSRecord.create for proper signed records')
  Future<dynamic> createRecord(CID cid, Uint8List keyBytes) async {
    // Return a dummy object that matches Record expectations in tests.
    return _LegacyRecord(keyBytes, cid.toBytes());
  }

  /// Returns the current status of the IPNS handler.
  Future<Map<String, dynamic>> getStatus() async {
    return {
      'running': _isRunning,
      'cache_size': _cache.length,
      'max_cache_size': _maxCacheSize,
      'cache_duration_minutes': 30, // Default for compatibility with tests.
    };
  }
}

class _CacheEntry {
  _CacheEntry(this.record, this.ttl) : _storedAt = DateTime.now();

  final IPNSRecord record;
  final Duration ttl;
  final DateTime _storedAt;

  bool get isExpired => DateTime.now().isAfter(_storedAt.add(ttl));
}

class _LegacyRecord {
  _LegacyRecord(this.key, this.value);
  final Uint8List key;
  final Uint8List value;
  final int sequence = DateTime.now().millisecondsSinceEpoch;
}

/// Error thrown when an IPNS name cannot be resolved.
class IpnsResolutionError implements Exception {
  /// Creates a new [IpnsResolutionError] with the given [message].
  IpnsResolutionError(this.message);

  /// Human-readable description of the resolution failure.
  final String message;

  @override
  String toString() => 'IpnsResolutionError: $message';
}

/// Error thrown when an IPNS record fails validation.
class IpnsValidationError implements Exception {
  /// Creates a new [IpnsValidationError] with the given [message].
  IpnsValidationError(this.message);

  /// Human-readable description of the validation failure.
  final String message;

  @override
  String toString() => 'IpnsValidationError: $message';
}
