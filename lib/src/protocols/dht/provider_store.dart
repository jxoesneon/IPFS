// src/protocols/dht/provider_store.dart
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/utils/logger.dart';

/// Manages CID provider records in the DHT.
///
/// Maps content CIDs to the set of PeerIDs that provide that content.
class ProviderStore {
  /// Creates a [ProviderStore].
  ProviderStore() : _logger = Logger('ProviderStore');

  final Map<String, Set<PeerId>> _providers = {};
  final Map<String, DateTime> _expiryTimes = {};
  final Logger _logger;

  /// Expiry duration for provider records.
  static const Duration providerExpiry = Duration(hours: 24);

  /// Maximum distinct CIDs tracked. Provider records arrive from
  /// unauthenticated ADD_PROVIDER messages, so the map must stay bounded —
  /// the oldest-inserted CID is evicted when the cap is hit.
  static const int maxProviderCids = 4096;

  /// Maximum providers retained per CID.
  static const int maxProvidersPerCid = 32;

  /// Adds a provider for the given [cid].
  void addProvider(CID cid, PeerId peerId) {
    final cidStr = cid.toString();
    var providers = _providers[cidStr];
    if (providers == null) {
      if (_providers.length >= maxProviderCids) {
        final evicted = _providers.keys.first;
        _providers.remove(evicted);
        _expiryTimes.remove(evicted);
      }
      providers = _providers[cidStr] = <PeerId>{};
    } else {
      // Refresh recency so frequently-queried CIDs are not the first
      // eviction candidates.
      _providers.remove(cidStr);
      _providers[cidStr] = providers;
    }
    if (providers.length < maxProvidersPerCid || providers.contains(peerId)) {
      providers.add(peerId);
    }
    _expiryTimes[cidStr] = DateTime.now().add(providerExpiry);
    _logger.debug('Added provider $peerId for CID $cid');
  }

  /// Returns a list of providers for the given [cid].
  List<PeerId> getProviders(CID cid) {
    final cidStr = cid.toString();
    final providers = _providers[cidStr];
    if (providers == null) return [];

    // Check expiry
    final expiry = _expiryTimes[cidStr];
    if (expiry != null && DateTime.now().isAfter(expiry)) {
      _providers.remove(cidStr);
      _expiryTimes.remove(cidStr);
      return [];
    }

    return providers.toList();
  }

  /// Removes expired provider records.
  void gc() {
    final now = DateTime.now();
    final expiredCids = <String>[];

    _expiryTimes.forEach((cid, expiry) {
      if (now.isAfter(expiry)) {
        expiredCids.add(cid);
      }
    });

    for (final cid in expiredCids) {
      _providers.remove(cid);
      _expiryTimes.remove(cid);
    }

    if (expiredCids.isNotEmpty) {
      _logger.info('Cleaned up ${expiredCids.length} expired provider records');
    }
  }
}
