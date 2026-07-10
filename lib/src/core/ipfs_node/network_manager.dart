// src/core/ipfs_node/network_manager.dart
import 'dart:async';
import 'dart:typed_data';

import '../../protocols/bitswap/bitswap_handler.dart';
import '../../protocols/dht/dht_handler.dart';
import '../../utils/base58.dart';
import '../../utils/logger.dart';
import '../cid.dart';
import '../data_structures/peer.dart';
import '../errors/node_errors.dart';
import '../interfaces/i_lifecycle.dart';
import 'content_routing_handler.dart';
import 'datastore_handler.dart';
import 'network_handler.dart';

/// Manages network-related operations for the IPFS node.
class NetworkManager implements ILifecycle {
  /// Creates a [NetworkManager] with injected dependencies.
  NetworkManager({
    NetworkHandler? networkHandler,
    DatastoreHandler? datastoreHandler,
    DHTHandler? dhtHandler,
    ContentRoutingHandler? contentRoutingHandler,
    BitswapHandler? bitswapHandler,
  }) : _networkHandler = networkHandler,
       _datastoreHandler = datastoreHandler,
       _dhtHandler = dhtHandler,
       _contentRoutingHandler = contentRoutingHandler,
       _bitswapHandler = bitswapHandler,
       _logger = Logger('NetworkManager');

  final NetworkHandler? _networkHandler;
  final DatastoreHandler? _datastoreHandler;
  final DHTHandler? _dhtHandler;
  final ContentRoutingHandler? _contentRoutingHandler;
  final BitswapHandler? _bitswapHandler;
  final Logger _logger;

  @override
  Future<void> start() async {
    _logger.debug('Starting NetworkManager...');

    final handler = _networkHandler;
    if (handler != null) {
      _logger.debug('Starting underlying network handler...');

      await handler.start();
    }
  }

  @override
  Future<void> stop() async {
    _logger.debug('Stopping NetworkManager...');
  }

  /// Returns the peer ID of this node.
  String get peerId {
    if (_networkHandler == null) return 'offline';
    return _networkHandler.peerID;
  }

  /// Returns a list of currently connected peer IDs.
  Future<List<String>> get connectedPeers async {
    try {
      if (_networkHandler != null) {
        return await _networkHandler.listConnectedPeers();
      }
      return [];
    } catch (e, stackTrace) {
      _logger.error('Failed to list connected peers', e, stackTrace);
      return [];
    }
  }

  /// Manually connects to a peer using its [multiaddr].
  Future<void> connectToPeer(String multiaddr) async {
    try {
      if (_networkHandler == null) {
        throw ComponentError('NetworkHandler', 'Required for peer connection');
      }
      await _networkHandler.connectToPeer(multiaddr);
      _logger.info('Connected to peer: $multiaddr');
    } catch (e, stackTrace) {
      _logger.error('Failed to connect to peer $multiaddr', e, stackTrace);
      rethrow;
    }
  }

  /// Gracefully disconnects from a peer identified by [peerIdOrAddr].
  Future<void> disconnectFromPeer(String peerIdOrAddr) async {
    try {
      if (_networkHandler == null) return;
      await _networkHandler.disconnectFromPeer(peerIdOrAddr);
      _logger.info('Disconnected from peer: $peerIdOrAddr');
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to disconnect from peer $peerIdOrAddr',
        e,
        stackTrace,
      );
    }
  }

  /// Resolves a peer ID to its known addresses from the routing table.
  List<String> resolvePeerId(String peerIdStr) {
    try {
      if (_networkHandler == null) return [];
      return _networkHandler.router.resolvePeerId(peerIdStr);
    } catch (e, stackTrace) {
      _logger.error('Failed to resolve peer ID $peerIdStr', e, stackTrace);
      return [];
    }
  }

  /// Finds providers for a given [cid] in the network.
  Future<List<String>> findProviders(String cid) async {
    try {
      if (_datastoreHandler != null) {
        final hasLocal = await _datastoreHandler.hasBlock(cid);
        if (hasLocal) {
          return [peerId];
        }
      }

      final cidObj = CID.decode(cid);
      final providers = <String>{};

      if (_dhtHandler != null) {
        final dhtProviders = await _dhtHandler.findProviders(cidObj);
        for (final p in dhtProviders) {
          providers.add(Base58().encode(Uint8List.fromList(p.peerId)));
        }
      }

      if (_contentRoutingHandler != null) {
        final routingProviders = await _contentRoutingHandler.findProviders(
          cid,
        );
        providers.addAll(routingProviders);
      }

      return providers.toList();
    } catch (e, stackTrace) {
      _logger.error('Error finding providers for CID $cid', e, stackTrace);
      return [];
    }
  }

  /// Requests a specific [cid] from [peer] via Bitswap.
  Future<void> requestBlock(String cid, Peer peer) async {
    try {
      if (_bitswapHandler == null) {
        throw ComponentError(
          'BitswapHandler',
          'Required for requesting blocks',
        );
      }
      if (_datastoreHandler == null) {
        throw ComponentError(
          'DatastoreHandler',
          'Required for storing requested blocks',
        );
      }

      final block = await _bitswapHandler.wantBlock(cid);
      if (block == null) {
        throw Exception('Failed to retrieve block $cid from peer ${peer.id}');
      }
      await _datastoreHandler.putBlock(block);
      _logger.info('Retrieved block $cid via Bitswap');
    } catch (e, stackTrace) {
      _logger.error('Error requesting block $cid', e, stackTrace);
      rethrow;
    }
  }
}
