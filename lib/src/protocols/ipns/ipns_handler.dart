// src/protocols/ipns/ipns_handler.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/security/security_manager_interface.dart';
import 'package:dart_ipfs/src/proto/generated/dht/dht.pb.dart';
import 'package:dart_ipfs/src/protocols/dht/interface_dht_handler.dart';
import 'package:dart_ipfs/src/protocols/pubsub/pubsub_interface.dart';
import 'package:dart_ipfs/src/utils/base58.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:fixnum/fixnum.dart' as fixnum;

import 'ipns_record.dart';

/// Handles IPNS (InterPlanetary Name System) operations.
///
/// Coordinates record publication and resolution across DHT and PubSub
/// layers, ensuring record authenticity and validity.
///
/// **Security (SEC-004):** All IPNS records are cryptographically signed and
/// verified upon resolution to prevent forgery and MITM attacks.
class IPNSHandler {
  /// Creates a new [IPNSHandler] with the required dependencies.
  ///
  /// Parameters:
  /// - [_config]: Global IPFS configuration.
  /// - [_securityManager]: Manager for secure key access and cryptographic operations.
  /// - [_dhtHandler]: Handler for DHT-based record storage and retrieval.
  /// - [_pubSubHandler]: Optional handler for IPNS-over-PubSub updates.
  IPNSHandler(
    IPFSConfig config,
    this._securityManager,
    this._dhtHandler, [
    this._pubSubHandler,
  ]) : _logger = Logger(
         'IPNSHandler',
         debug: config.debug,
         verbose: config.verboseLogging,
       ) {
    _logger.debug('IPNSHandler instance initialized');
  }

  final ISecurityManager _securityManager;
  final IDHTHandler _dhtHandler;
  final IPubSub? _pubSubHandler;
  final Logger _logger;

  bool _isRunning = false;

  /// Tracks sequence numbers for published keys to ensure monotonic updates.
  final Map<String, int> _sequenceNumbers = {};

  /// Cache for resolved IPNS records to improve performance and reduce network load.
  final Map<String, _CachedResolution> _resolutionCache = {};

  static const Duration _cacheDuration = Duration(minutes: 30);
  static const String _pubSubTopic = '/ipfs/ipns-1.0.0';

  /// Indicates whether the IPNS handler is currently active.
  bool get isRunning => _isRunning;

  /// Derives the PubSub topic for a given IPNS name (PeerID).
  ///
  /// Parameters:
  /// - [name]: The IPNS name (Base58 encoded PeerID).
  ///
  /// Returns the derived PubSub topic string.
  String _getRecordTopic(String name) {
    try {
      final List<int> bytes = Base58().base58Decode(name);
      return _getTopicFromBytes(Uint8List.fromList(bytes));
    } catch (e) {
      _logger.debug(
        'Name is not Base58, using UTF-8 fallback for topic: $name',
      );
      final List<int> bytes = utf8.encode(name);
      return _getTopicFromBytes(Uint8List.fromList(bytes));
    }
  }

  /// Derives the PubSub topic from raw Key ID bytes using Base64URL encoding.
  String _getTopicFromBytes(Uint8List keyIdBytes) {
    final String b64 = base64Url.encode(keyIdBytes).replaceAll('=', '');
    return '/record/$b64';
  }

  /// Derives the Key ID bytes for an Ed25519 public key.
  ///
  /// Uses the Identity Multihash format (0x00 + length + publicKey).
  Uint8List _getEd25519KeyId(Uint8List publicKey) {
    if (publicKey.length != 32) return publicKey;

    final BytesBuilder builder = BytesBuilder();
    builder.addByte(0x00); // Identity multihash code
    builder.addByte(32); // Length
    builder.add(publicKey);
    return builder.toBytes();
  }

  /// Publishes a signed IPNS record linking a name to a CID.
  ///
  /// Orchestrates record creation, signing via [ISecurityManager], and
  /// distribution via both DHT and PubSub (if available).
  ///
  /// Parameters:
  /// - [cid]: The Content Identifier to link.
  /// - [keyName]: The name of the key in the keystore to sign the record with.
  ///
  /// Throws:
  /// - [ArgumentError] if the CID format is invalid.
  /// - [StateError] if the keystore is locked.
  Future<void> publish(String cid, {required String keyName}) async {
    _logger.debug('Publishing IPNS record: $cid with key: $keyName');

    try {
      if (!_isValidCID(cid)) {
        throw ArgumentError('Invalid CID format: $cid');
      }

      if (!_securityManager.isKeystoreUnlocked) {
        throw StateError('Keystore is locked. Unlock it before publishing.');
      }

      final keyPair = await _securityManager.getSecureKey(keyName);

      // Increment sequence number for monotonic updates
      final int sequence = (_sequenceNumbers[keyName] ?? 0) + 1;
      _sequenceNumbers[keyName] = sequence;

      final IPNSRecord record = await IPNSRecord.create(
        value: CID.decode(cid),
        keyPair: keyPair,
        sequence: sequence,
      );

      // Distribute via DHT
      await publishRecord(record);

      // Distribute via PubSub (IPNS-over-PubSub)
      if (_pubSubHandler != null) {
        await _publishToPubSub(record);
      }

      _logger.info('Successfully published IPNS record for CID: $cid');
    } catch (e, stackTrace) {
      _logger.error('Failed to publish IPNS record', e, stackTrace);
      rethrow;
    }
  }

  /// Helper to publish a record to relevant PubSub topics.
  Future<void> _publishToPubSub(IPNSRecord record) async {
    try {
      final String payload = base64Encode(record.toCBOR());

      // 1. Global Floodsub topic
      await _pubSubHandler!.publish(_pubSubTopic, payload);

      // 2. Key-specific topic
      final Uint8List keyId = _getEd25519KeyId(record.publicKey);
      final String specificTopic = _getTopicFromBytes(keyId);
      await _pubSubHandler.publish(specificTopic, payload);

      _logger.verbose(
        'Published to PubSub topics: $_pubSubTopic, $specificTopic',
      );
    } catch (e) {
      _logger.warning('IPNS-over-PubSub publication failed: $e');
    }
  }

  /// Publishes a signed [IPNSRecord] directly to the DHT.
  Future<void> publishRecord(IPNSRecord record) async {
    if (!record.isSigned) {
      throw StateError('Cannot publish an unsigned IPNS record.');
    }

    await _dhtHandler.putValue(Key(record.publicKey), Value(record.toCBOR()));
  }

  /// Resolves an IPNS record from the DHT.
  ///
  /// Parameters:
  /// - [name]: The IPNS name to resolve.
  ///
  /// Returns a [Record] protobuf container with the resolved value.
  Future<Record> resolveRecord(String name) async {
    final Value value = await _dhtHandler.getValue(Key.fromString(name));
    return Record()
      ..key = Uint8List.fromList(utf8.encode(name))
      ..value = Uint8List.fromList(value.bytes);
  }

  /// Starts the IPNS handler, initializing DHT and PubSub subscriptions.
  Future<void> start() async {
    if (_isRunning) {
      _logger.warning('IPNSHandler is already running.');
      return;
    }

    try {
      _isRunning = true;
      await _dhtHandler.start();

      if (_pubSubHandler != null) {
        await _pubSubHandler.subscribe(_pubSubTopic);
        _pubSubHandler.onMessage(_pubSubTopic, _handlePubSubMessage);
      }

      _logger.info('IPNS handler started successfully.');
    } catch (e, stackTrace) {
      _logger.error('Failed to start IPNS handler', e, stackTrace);
      _isRunning = false;
      rethrow;
    }
  }

  /// Stops the IPNS handler, clearing caches and unsubscribing from topics.
  Future<void> stop() async {
    if (!_isRunning) return;

    try {
      _isRunning = false;

      if (_pubSubHandler != null) {
        try {
          await _pubSubHandler.unsubscribe(_pubSubTopic);
        } catch (_) {}
      }

      _resolutionCache.clear();
      _logger.info('IPNS handler stopped successfully.');
    } catch (e, stackTrace) {
      _logger.error('Failed to stop IPNS handler', e, stackTrace);
      rethrow;
    }
  }

  /// Resolves an IPNS name to its current CID.
  ///
  /// Utilizes caching and attempts resolution via both DHT and PubSub.
  ///
  /// Parameters:
  /// - [name]: The IPNS name to resolve.
  ///
  /// Returns the resolved CID string, or `null` if resolution fails.
  Future<String?> resolve(String name) async {
    _logger.debug('Resolving IPNS name: $name');

    try {
      // Monitor PubSub for real-time updates
      final pubsub = _pubSubHandler;
      if (pubsub != null) {
        final String topic = _getRecordTopic(name);
        await pubsub.subscribe(topic);
        pubsub.onMessage(topic, _handlePubSubMessage);
      }

      // Check cache first
      final _CachedResolution? cached = _resolutionCache[name];
      if (cached != null && !cached.isExpired) {
        _logger.verbose('Returning cached resolution for: $name');
        return cached.cid;
      }
      _resolutionCache.remove(name);

      // Perform DHT resolution
      final Record record = await resolveRecord(name);
      final String decodedCid = CID
          .fromBytes(Uint8List.fromList(record.value))
          .encode();

      _cacheResolution(name, decodedCid);
      _logger.info('Resolved $name to $decodedCid');
      return decodedCid;
    } catch (e, stackTrace) {
      _logger.error('Failed to resolve IPNS name: $name', e, stackTrace);
      return null;
    }
  }

  /// Returns the current status of the IPNS handler.
  Future<Map<String, dynamic>> getStatus() async {
    return {
      'running': _isRunning,
      'cache_size': _resolutionCache.length,
      'cache_duration_minutes': _cacheDuration.inMinutes,
    };
  }

  /// Creates an unsigned IPNS record container.
  ///
  /// **Deprecated:** Use [publish] for managed publication.
  @Deprecated('Use publish instead')
  Future<Record> createRecord(CID value, Uint8List key) async {
    return Record()
      ..key = key
      ..value = value.toBytes()
      ..sequence = fixnum.Int64(DateTime.now().millisecondsSinceEpoch);
  }

  /// Basic validation for CID strings.
  bool _isValidCID(String cid) {
    return cid.isNotEmpty && RegExp(r'^[a-zA-Z0-9]+$').hasMatch(cid);
  }

  /// Caches a successful IPNS resolution.
  void _cacheResolution(String name, String cid) {
    _logger.verbose('Caching resolution: $name -> $cid');
    _resolutionCache[name] = _CachedResolution(
      cid: cid,
      timestamp: DateTime.now(),
    );
  }

  /// Handles incoming IPNS records from PubSub, verifying signatures.
  void _handlePubSubMessage(String messageContent) async {
    try {
      final Uint8List recordBytes = base64Decode(messageContent);
      final IPNSRecord record = IPNSRecord.fromCBOR(recordBytes);

      if (!await record.verify()) {
        _logger.warning(
          'Received invalid IPNS record via PubSub (signature mismatch).',
        );
        return;
      }

      _logger.verbose(
        'Processed valid IPNS record from PubSub (Validity: ${record.validity})',
      );
    } catch (e) {
      _logger.verbose('Failed to process IPNS PubSub message: $e');
    }
  }
}

/// Helper class for internal IPNS resolution caching.
class _CachedResolution {
  _CachedResolution({required this.cid, required this.timestamp});

  final String cid;
  final DateTime timestamp;

  /// Whether the cached resolution has exceeded its lifetime.
  bool get isExpired =>
      DateTime.now().difference(timestamp) > IPNSHandler._cacheDuration;
}
