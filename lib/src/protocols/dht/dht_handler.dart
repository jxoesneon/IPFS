// src/protocols/dht/dht_handler.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/core/storage/datastore.dart' as ds;
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/proto/generated/dht/common_red_black_tree.pb.dart';
import 'package:dart_ipfs/src/proto/generated/ipns.pb.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_client.dart';
import 'package:dart_ipfs/src/protocols/dht/interface_dht_handler.dart';
import 'package:dart_ipfs/src/storage/hive_datastore.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:dart_ipfs/src/utils/dnslink_resolver.dart';
import 'package:dart_ipfs/src/utils/keystore.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:dart_ipfs/src/utils/private_key.dart';
import 'package:fixnum/fixnum.dart';
import 'package:http/http.dart' as http;

/// Handles DHT operations for an IPFS node.
///
/// **Security (SEC-010):** Provider records are verified before storage
/// to prevent DHT index poisoning attacks.
class DHTHandler implements IDHTHandler {
  /// Creates a new [DHTHandler] with the given [config], [_router], and [networkHandler].
  DHTHandler(
    IPFSConfig config,
    this._router,
    NetworkHandler networkHandler, {
    ds.Datastore? storage,
    DHTClient? client,
    Keystore? keystore,
    http.Client? httpClient,
  }) : _keystore = keystore ?? Keystore(),
       _httpClient = httpClient ?? http.Client(),
       _storage = storage ?? HiveDatastore(config.datastorePath) {
    _logger = Logger('DHTHandler', debug: config.debug);
    if (storage == null) {
      _storage.init();
    }
    dhtClient =
        client ?? DHTClient(networkHandler: networkHandler, router: _router);
  }

  /// The underlying DHT client for network operations.
  late final DHTClient dhtClient;
  final Keystore _keystore;
  final RouterInterface _router;
  final ds.Datastore _storage;
  final http.Client _httpClient;
  late final Logger _logger;

  final Set<String> _activeQueries = {};
  final Map<String, Set<String>> _providers = {};
  static const String _protocolVersion = '1.0.0';

  // SEC-010: Provider verification constants
  /// Maximum providers to store per CID (prevents flooding)
  static const int maxProvidersPerCid = 20;

  /// Rate limit: max provider announcements per peer per minute
  static const int maxProviderAnnouncementsPerMinute = 10;

  /// Track provider announcements per peer for rate limiting
  final Map<String, List<DateTime>> _providerAnnouncements = {};

  /// Starts the DHT client.
  @override
  Future<void> start() async {
    _logger.debug('Starting DHT client...');
    try {
      await dhtClient.start();
      _logger.info('DHT client started successfully');
    } catch (e, st) {
      _logger.error('Error starting DHT client', e, st);
      rethrow;
    }
  }

  /// Stops the DHT client.
  @override
  Future<void> stop() async {
    _logger.debug('Stopping DHT client...');
    try {
      await dhtClient.stop();
      _logger.info('DHT client stopped successfully');
    } catch (e, st) {
      _logger.error('Error stopping DHT client', e, st);
    }
  }

  /// Finds providers for a given CID in the DHT network.
  @override
  Future<List<V_PeerInfo>> findProviders(CID cid) async {
    _logger.debug('Finding providers for CID: $cid');
    try {
      final providers = await dhtClient.findProviders(cid.toString());
      return providers
          .map((peer) => V_PeerInfo()..peerId = peer.value)
          .toList();
    } catch (e, st) {
      _logger.error('Error finding providers for CID: $cid', e, st);
      return [];
    }
  }

  /// Publishes a value to the DHT network under a given key.
  @override
  Future<void> putValue(Key key, Value value) async {
    _logger.debug('Publishing value to DHT for key: $key');
    try {
      final storageKey = ds.Key('/dht/values/${key.toString()}');

      // Store the value bytes directly
      await _storage.put(storageKey, Uint8List.fromList(value.bytes));

      // Update routing table with key information
      final targetPeerId = PeerId(value: key.bytes);
      await handleRoutingTableUpdate(V_PeerInfo()..peerId = targetPeerId.value);
    } catch (e, st) {
      _logger.error('Error publishing value to DHT for key: $key', e, st);
    }
  }

  /// Retrieves a value from the DHT network by its key.
  @override
  Future<Value> getValue(Key key) async {
    _logger.debug('Retrieving value from DHT for key: $key');
    try {
      final storageKey = ds.Key('/dht/values/${key.toString()}');
      final data = await _storage.get(storageKey);
      if (data != null) {
        return Value(data);
      }
      throw Exception('Value not found in local DHT storage');
    } catch (e) {
      _logger.debug('Value not found locally for key: $key');
      rethrow;
    }
  }

  /// Resolves an IPNS name to its corresponding CID using alternative methods if necessary.
  ///
  /// This method first attempts to resolve the name via the DHT. If that fails,
  /// it falls back to using a public IPNS resolver.
  ///
  /// Throws an [ArgumentError] if the [ipnsName] is invalid.
  /// Throws an [Exception] if the resolution fails across all methods.
  Future<String> resolveIPNS(String ipnsName) async {
    if (!isValidPeerID(ipnsName)) {
      throw ArgumentError('Invalid IPNS name: $ipnsName');
    }

    _logger.debug('Resolving IPNS name: $ipnsName');
    String? resolvedCid;
    try {
      final value = await getValue(Key.fromString(ipnsName));
      resolvedCid = value.toString();
    } catch (e) {
      _logger.debug(
        'IPNS resolution via DHT failed for $ipnsName, trying fallback',
      );
    }

    // If resolution via DHT fails, use a public IPNS resolver
    if (resolvedCid == null) {
      try {
        final url = Uri.parse('https://ipfs.io/ipns/$ipnsName');
        final response = await _httpClient
            .get(url)
            .timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          resolvedCid = extractCIDFromResponse(response.body);
          if (resolvedCid != null) {
            _logger.debug(
              'Resolved IPNS name $ipnsName using public resolver: $resolvedCid',
            );
          } else {
            throw Exception(
              'Failed to extract CID from public resolver response',
            );
          }
        } else {
          throw Exception(
            'Public resolver returned status code ${response.statusCode}',
          );
        }
      } catch (e, st) {
        _logger.error('Error resolving IPNS name using public resolver', e, st);
        throw Exception('Failed to resolve IPNS name using all methods.');
      }
    }

    return resolvedCid;
  }

  /// Publishes an IPNS record for a given [cid] using the private key identified by [keyName].
  ///
  /// The [keyName] must correspond to a key pair stored in the keystore.
  ///
  /// Throws an [ArgumentError] if the [cid] is invalid.
  Future<void> publishIPNS(String cid, {required String keyName}) async {
    _logger.debug('Publishing IPNS record for CID $cid with key $keyName');
    try {
      // Get the IPNS key pair from the keystore
      final keyPair = _keystore.getKeyPair(keyName);

      // Parse private key for signing
      final privateKey = IPFSPrivateKey.fromString(keyPair.privateKey);

      if (!isValidCID(cid)) {
        throw ArgumentError('Invalid CID: $cid');
      }

      // Create IPNS Entry
      final valuePath = utf8.encode('/ipfs/$cid');

      // Validity: RFC3339 format, 24 hours from now
      final validityDate = DateTime.now()
          .add(const Duration(hours: 24))
          .toUtc();
      final validity = utf8.encode(validityDate.toIso8601String());
      final validityType = IpnsEntry_ValidityType.EOL;

      // Sequence: fetch existing record and increment
      var sequence = Int64(0);
      try {
        final existingValue = await getValue(Key.fromString(keyPair.publicKey));
        final existingEntry = IpnsEntry.fromBuffer(existingValue.bytes);
        sequence = existingEntry.sequence + 1;
      } catch (e) {
        sequence = Int64(1);
      }

      final ttl = Int64(3600); // 1 hour

      final dataToSign = BytesBuilder();
      dataToSign.add(valuePath);
      dataToSign.add(validity);
      dataToSign.add(utf8.encode('EOL'));

      final signature = privateKey.sign(dataToSign.toBytes());

      final entry = IpnsEntry()
        ..value = valuePath
        ..validity = validity
        ..validityType = validityType
        ..sequence = sequence
        ..ttl = ttl
        ..signature = signature;

      // Serialize entry
      final entryBytes = entry.writeToBuffer();

      await putValue(Key.fromString(keyPair.publicKey), Value(entryBytes));
      _logger.info('Successfully published IPNS record for CID: $cid');
    } catch (e, st) {
      _logger.error('Error publishing IPNS record', e, st);
    }
  }

  /// Validates if a given string is a valid CID.
  bool isValidCID(String cid) =>
      cid.isNotEmpty && RegExp(r'^[a-zA-Z0-9]+$').hasMatch(cid);

  /// Validates if a given string is a valid peer ID.
  bool isValidPeerID(String peerId) =>
      peerId.isNotEmpty && RegExp(r'^[a-zA-Z0-9]+$').hasMatch(peerId);

  /// Extracts a CID from an HTTP response body.
  String? extractCIDFromResponse(String responseBody) {
    final match = RegExp(
      r'Qm[1-9A-HJ-NP-Za-km-z]{44}',
    ).firstMatch(responseBody);
    return match?.group(0);
  }

  /// Returns the underlying P2P router.
  RouterInterface get router => _router;

  /// Finds a peer in the DHT network by its [PeerId].
  @override
  Future<List<V_PeerInfo>> findPeer(PeerId id) async {
    _logger.debug('Finding peer: $id');
    try {
      final peer = await dhtClient.findPeer(id);
      if (peer != null) {
        return [V_PeerInfo()..peerId = peer.value];
      }
      return [];
    } catch (e, st) {
      _logger.error('Error finding peer $id', e, st);
      return [];
    }
  }

  /// Announces that this node provides content for the given [cid].
  @override
  Future<void> provide(CID cid) async {
    _logger.debug('Announcing as provider for CID: $cid');
    try {
      await dhtClient.addProvider(cid.toString(), _router.peerID);
    } catch (e, st) {
      _logger.error('Error providing CID: $cid', e, st);
    }
  }

  /// Handles routing table updates when peer information changes.
  @override
  Future<void> handleRoutingTableUpdate(V_PeerInfo peer) async {
    _logger.debug('Updating routing table for peer: ${peer.peerId}');
    try {
      await dhtClient.kademliaRoutingTable.updatePeer(peer);
    } catch (e, st) {
      _logger.error(
        'Error updating routing table for peer: ${peer.peerId}',
        e,
        st,
      );
      rethrow;
    }
  }

  /// Handles requests from peers to provide content.
  ///
  /// **Security (SEC-010):** Verifies provider requests before storage:
  /// - Rate limits provider announcements per peer
  /// - Limits max providers per CID
  /// - Logs suspicious activity
  @override
  Future<void> handleProvideRequest(CID cid, PeerId provider) async {
    final providerStr = provider.toString();
    final cidStr = cid.toString();

    try {
      // SEC-010: Rate limit check
      final now = DateTime.now();
      final announcements = _providerAnnouncements[providerStr] ?? [];

      // Remove old announcements (older than 1 minute)
      announcements.removeWhere((time) => now.difference(time).inSeconds > 60);

      if (announcements.length >= maxProviderAnnouncementsPerMinute) {
        _logger.warning(
          'SEC-010: Rate limit exceeded for provider $providerStr '
          '(${announcements.length} announcements/min)',
        );
        return; // Reject - rate limit exceeded
      }

      // SEC-010: Max providers per CID check
      final existingProviders = _providers[cidStr] ?? <String>{};
      if (existingProviders.length >= maxProvidersPerCid &&
          !existingProviders.contains(providerStr)) {
        _logger.warning(
          'SEC-010: Max providers ($maxProvidersPerCid) reached for CID $cidStr',
        );
        return; // Reject - too many providers
      }

      // Track this announcement
      announcements.add(now);
      _providerAnnouncements[providerStr] = announcements;

      // Track provider locally
      existingProviders.add(providerStr);
      _providers[cidStr] = existingProviders;

      // Add to DHT
      await dhtClient.addProvider(cidStr, providerStr);
      _logger.verbose('Added verified provider $providerStr for CID $cidStr');
    } catch (e, st) {
      _logger.error('Error handling provide request', e, st);
    }
  }

  /// Resolves a DNSLink for the given [domainName] to its corresponding CID.
  ///
  /// This method first attempts to resolve the DNSLink via the DHT. If that fails,
  /// it falls back to using the standard DNSLink resolver.
  Future<String?> resolveDNSLink(String domainName) async {
    _logger.debug('Resolving DNSLink for domain: $domainName');
    try {
      // First try using the DHT network to resolve the DNSLink
      final dnsKey = Key.fromString('dnslink:$domainName');
      try {
        final value = await getValue(dnsKey);
        final cid = extractCIDFromResponse(value.toString());
        if (cid != null) {
          _logger.debug(
            'Resolved DNSLink for domain $domainName to CID via DHT: $cid',
          );
          return cid;
        }
      } catch (_) {
        _logger.debug(
          'DNSLink resolution via DHT failed for $domainName, trying resolver',
        );
      }

      // If DHT resolution fails, try using DNSLinkResolver
      final resolvedCid = await DNSLinkResolver.resolve(domainName);
      if (resolvedCid != null) {
        _logger.debug(
          'Resolved DNSLink for domain $domainName via resolver: $resolvedCid',
        );
        return resolvedCid;
      }

      _logger.warning('Failed to resolve DNSLink for domain: $domainName');
      return null;
    } catch (e, st) {
      _logger.error('Error resolving DNSLink for domain $domainName', e, st);
      return null;
    }
  }

  /// Returns the underlying datastore.
  ds.Datastore get storage => _storage;

  /// Returns the current status of the DHT handler as a map.
  ///
  /// If the DHT client is not initialized, returns a status indicating it is disabled.
  Future<Map<String, dynamic>> getStatus() async {
    if (!dhtClient.isInitialized) {
      return {
        'status': 'disabled',
        'active_queries': 0,
        'routing_table_size': 0,
        'total_providers': 0,
        'protocol_version': _protocolVersion,
      };
    }

    return {
      'status': 'active',
      'active_queries': _activeQueries.length,
      'routing_table_size': dhtClient.kademliaRoutingTable.peerCount,
      'total_providers': _providers.length,
      'protocol_version': _protocolVersion,
    };
  }
}
