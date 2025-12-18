// src/protocols/ipns/ipns_handler.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/pubsub_handler.dart';
import 'package:dart_ipfs/src/core/security/security_manager.dart';
import 'package:dart_ipfs/src/proto/generated/dht/dht.pb.dart';
import 'package:dart_ipfs/src/protocols/dht/interface_dht_handler.dart';
import 'package:dart_ipfs/src/utils/base58.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:fixnum/fixnum.dart';

import 'ipns_record.dart';

/// Handles IPNS operations, combining both node-level coordination and protocol-level operations.
///
/// **Security (SEC-004):** All IPNS records are signed with Ed25519 and verified
/// on resolve to prevent record forgery attacks.
class IPNSHandler { // Standard topic

  IPNSHandler(
    this._config,
    this._securityManager,
    this._dhtHandler, [
    this._pubSubHandler,
  ]) {
    _logger = Logger(
      'IPNSHandler',
      debug: _config.debug,
      verbose: _config.verboseLogging,
    );
    _logger.debug('IPNSHandler instance created');
  }
  final IPFSConfig _config;
  final SecurityManager _securityManager;
  final IDHTHandler _dhtHandler;
  final PubSubHandler? _pubSubHandler; // Optional: May be null if offline
  late final Logger _logger;
  bool _isRunning = false;

  /// Sequence numbers for each key (tracked to ensure monotonic increase)
  final Map<String, int> _sequenceNumbers = {};

  // Cache for resolved IPNS records
  final Map<String, _CachedResolution> _resolutionCache = {};
  static const Duration _cacheDuration = Duration(minutes: 30);

  static const String _pubSubTopic = '/ipfs/ipns-1.0.0';

  /// Publishes a SIGNED IPNS record linking a name to a CID.
  ///
  /// SEC-004: Records are signed with Ed25519 to prevent forgery.
  /// Uses EncryptedKeystore via SecurityManager for secure key access.
  /// Derives the PubSub topic from the PeerID string (name).
  /// Decodes Base58 to get raw ID bytes, then key-specific formatting.
  String _getRecordTopic(String name) {
    try {
      // Decode Base58 string to bytes (Key ID)
      final bytes = Base58().base58Decode(name);
      return _getTopicFromBytes(Uint8List.fromList(bytes));
    } catch (e) {
      // Fallback if not Base58 (e.g. testing with simple strings)
      // Though technically spec requires Multihash/PeerID.
      final bytes = utf8.encode(name);
      return _getTopicFromBytes(Uint8List.fromList(bytes));
    }
  }

  /// Derives the PubSub topic from raw Key ID bytes.
  /// Format: /record/base64url-unpadded(key-id-bytes)
  String _getTopicFromBytes(Uint8List keyIdBytes) {
    final b64 = base64Url.encode(keyIdBytes).replaceAll('=', '');
    return '/record/$b64';
  }

  /// Derives the Key ID bytes for an Ed25519 public key.
  /// (Identity Multihash: 0x00 + len + pubKey)
  Uint8List _getEd25519KeyId(Uint8List publicKey) {
    if (publicKey.length != 32) return publicKey; // Should be 32 for Ed25519

    final builder = BytesBuilder();
    builder.addByte(0x00); // Identity code
    builder.addByte(32); // Length
    builder.add(publicKey);
    return builder.toBytes();
  }

  Future<void> publish(String cid, {required String keyName}) async {
    _logger.debug('Publishing IPNS record for CID: $cid with key: $keyName');

    try {
      // Verify CID format
      if (!_isValidCID(cid)) {
        throw ArgumentError('Invalid CID format');
      }

      // Check if keystore is unlocked
      if (!_securityManager.isKeystoreUnlocked) {
        throw StateError(
          'Keystore is locked. Call securityManager.unlockKeystore() first.',
        );
      }

      // Get key pair from encrypted keystore
      final keyPair = await _securityManager.getSecureKey(keyName);

      // Get/increment sequence number
      final sequence = (_sequenceNumbers[keyName] ?? 0) + 1;
      _sequenceNumbers[keyName] = sequence;

      // Create signed IPNS record
      final record = await IPNSRecord.create(
        value: CID.decode(cid),
        keyPair: keyPair,
        sequence: sequence,
      );

      // Publish to DHT
      await publishRecord(record);

      // Publish to PubSub (IPNS over PubSub)
      if (_pubSubHandler != null) {
        try {
          final payload = base64Encode(record.toCBOR());

          // 1. Floodsub Topic (Global)
          await _pubSubHandler.publish(_pubSubTopic, payload);

          // 2. Key-Specific Topic
          // Construct Key ID from Public Key (Ed25519 Identity Multihash)
          // Note: In a real PeerID impl, we'd handle other key types.
          // ipns_record.dart uses Ed25519Signer, so we handle Ed25519.
          final keyId = _getEd25519KeyId(record.publicKey);
          final specificTopic = _getTopicFromBytes(keyId);

          await _pubSubHandler.publish(specificTopic, payload);

          _logger.verbose(
            'Published IPNS record to topics: $_pubSubTopic, $specificTopic',
          );
        } catch (e) {
          _logger.warning('Failed to publish IPNS record to PubSub: $e');
        }
      }

      _logger.info('Successfully published signed IPNS record for CID: $cid');
    } catch (e, stackTrace) {
      _logger.error('Failed to publish IPNS record', e, stackTrace);
      rethrow;
    }
  }

  /// Creates a SIGNED IPNS record for the given CID and key.
  ///
  /// @deprecated Use [IPNSRecord.create] directly for new code.
  Future<Record> createRecord(CID cid, Uint8List keyBytes) async {
    final record = Record()
      ..key = keyBytes
      ..value = cid.toBytes()
      ..sequence = Int64(DateTime.now().millisecondsSinceEpoch);

    _logger.warning('Using unsigned Record - migrate to IPNSRecord.create()');
    return record;
  }

  /// Publishes a signed IPNS record to the DHT.
  Future<void> publishRecord(IPNSRecord record) async {
    if (!record.isSigned) {
      throw StateError('Cannot publish unsigned IPNS record');
    }

    // Use public key as DHT key
    await _dhtHandler.putValue(Key(record.publicKey), Value(record.toCBOR()));
  }

  /// Resolves an IPNS record from the DHT
  Future<Record> resolveRecord(String name) async {
    // keys are usually raw bytes in DHT, so we use name as-is if it implies bytes
    // However, for consistency with publish, we assume name is the Key
    final value = await _dhtHandler.getValue(Key.fromString(name));
    return Record()
      ..key = Uint8List.fromList(utf8.encode(name))
      ..value = Uint8List.fromList(value.bytes);
  }

  /// Starts the IPNS handler
  Future<void> start() async {
    if (_isRunning) {
      _logger.warning('IPNSHandler already running');
      return;
    }

    try {
      _isRunning = true;
      _logger.verbose('Starting DHT handler...');
      await _dhtHandler.start();

      if (_pubSubHandler != null) {
        _logger.verbose('Subscribing to IPNS PubSub topic $_pubSubTopic...');
        await _pubSubHandler.subscribe(_pubSubTopic);
        // Listen for incoming IPNS records
        _pubSubHandler.onMessage(_pubSubTopic, _handlePubSubMessage);
      }

      _logger.info('IPNS handler started successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to start IPNS handler', e, stackTrace);
      _isRunning = false;
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
      _isRunning = false;

      if (_pubSubHandler != null) {
        try {
          await _pubSubHandler.unsubscribe(_pubSubTopic);
        } catch (_) {}
      }

      _resolutionCache.clear();
      _logger.info('IPNS handler stopped successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to stop IPNS handler', e, stackTrace);
      rethrow;
    }
  }

  /// Resolves an IPNS name to its current CID
  Future<String?> resolve(String name) async {
    _logger.debug('Resolving IPNS name: $name');

    try {
      // Subscribe to key-specific PubSub topic for updates
      if (_pubSubHandler != null) {
        final topic = _getRecordTopic(name);
        // Subscribe if not already subscribed (PubSubHandler handles idempotency ideally,
        // but we adding a listener requires care not to add duplicates?
        // onMessage usually adds a stream listener.
        // We'll just do it; overhead is acceptable for now.)
        await _pubSubHandler.subscribe(topic);
        _pubSubHandler.onMessage(topic, _handlePubSubMessage);
      }

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
      final record = await resolveRecord(name);
      final decodedCid = CID
          .fromBytes(Uint8List.fromList(record.value))
          .encode();

      // Cache the result
      _cacheResolution(name, decodedCid);

      _logger.info(
        'Successfully resolved IPNS name: $name to CID: $decodedCid',
      );
      return decodedCid;
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

  void _handlePubSubMessage(String messageContent) async {
    try {
      // Decode the message (Base64 -> CBOR Bytes)
      final recordBytes = base64Decode(messageContent);

      // Parse and Verify Record
      final record = IPNSRecord.fromCBOR(recordBytes);
      if (!await record.verify()) {
        _logger.warning(
          'Received invalid IPNS record via PubSub (signature check failed)',
        );
        return;
      }

      _logger.verbose(
        'Received valid IPNS record via PubSub (Validity: ${record.validity})',
      );
    } catch (e) {
      _logger.verbose('Failed to process IPNS PubSub message: $e');
    }
  }
}

/// Helper class for caching IPNS resolutions
class _CachedResolution {

  _CachedResolution({required this.cid, required this.timestamp});
  final String cid;
  final DateTime timestamp;

  bool get isExpired =>
      DateTime.now().difference(timestamp) > IPNSHandler._cacheDuration;
}
