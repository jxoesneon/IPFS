import 'dart:async';
import 'dart:typed_data';
import 'package:dart_ipfs/src/core/data_structures/peer.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/core/types/peer_types.dart';
import 'package:dart_ipfs/src/proto/generated/dht/dht.pb.dart';
import 'package:dart_ipfs/src/protocols/dht/peer_store.dart';
import 'package:dart_ipfs/src/protocols/dht/routing_table.dart';

/// Implementation of the Kademlia DHT protocol following IPFS specs.
class DHTProtocol {
  /// Creates a DHT protocol handler with routing table and peer store.
  DHTProtocol({
    required RoutingTable routingTable,
    required PeerStore peerStore,
    required NetworkHandler network,
  }) : _routingTable = routingTable,
       _peerStore = peerStore,
       _network = network;

  /// Protocol identifier for Kademlia DHT.
  static const String protocolId = '/ipfs/kad/1.0.0';

  /// Number of parallel lookups per query.
  static const int alpha = 3;

  /// Size of k-buckets.
  static const int K = 20;

  final RoutingTable _routingTable;
  final PeerStore _peerStore;
  final NetworkHandler _network;

  /// Finds the closest peers to a given key
  Future<List<PeerId>> findClosestPeers(
    List<int> key, {
    int numPeers = K,
  }) async {
    final closest = _routingTable.getNearestPeers(key, numPeers);
    final results = <PeerId>[];

    // Parallel lookups following Kademlia spec
    final futures = <Future<void>>[];
    for (var i = 0; i < alpha && i < closest.length; i++) {
      futures.add(_queryPeer(closest[i], key));
    }

    await Future.wait(futures);
    return results;
  }

  /// Handles an incoming FindNode request
  Future<FindNodeResponse> handleFindNode(FindNodeRequest request) async {
    final targetPeerId = request.peerId;
    final closestPeers = _routingTable.getNearestPeers(targetPeerId, K);

    // Convert PeerId objects to IPFSPeer objects
    final ipfsPeers = closestPeers.map((peerId) {
      // Get peer from peer store if available
      final peer = _peerStore.getPeer(peerId);

      // If peer exists in store, use its data, otherwise create new with empty addresses
      return peer ??
          IPFSPeer(
            id: peerId,
            addresses: [], // Empty list since peer not in store
            latency: 0, // Default latency
            agentVersion: '', // Default agent version
          );
    }).toList();

    return FindNodeResponse()
      ..closerPeers.addAll(
        ipfsPeers.map(
          (p) => DHTPeer()
            ..id = p.id.value
            ..addrs.addAll(p.addresses.map((a) => a.toString())),
        ),
      );
  }

  /// Queries a peer for nodes closer to the target key
  Future<void> _queryPeer(PeerId peer, List<int> targetKey) async {
    try {
      // Create FindNode request
      final request = FindNodeRequest()..peerId = targetKey;

      // Send request to peer
      final response = await _network.sendRequest(
        peer.toString(),
        protocolId,
        request.writeToBuffer(),
      );

      if (response == null) return;

      // Parse response
      final findNodeResponse = FindNodeResponse.fromBuffer(response);

      // Add closer peers to routing table
      for (var peerInfo in findNodeResponse.closerPeers) {
        final peerId = PeerId(value: Uint8List.fromList(peerInfo.id));
        _routingTable.addPeer(peerId, peerId);

        // Create IPFSPeer object before adding to store
        final ipfsPeer = IPFSPeer(
          id: peerId,
          addresses: peerInfo.addrs
              .map((addr) => parseMultiaddrString(addr))
              .whereType<FullAddress>()
              .toList(),
          latency: 0, // Default latency
          agentVersion: '', // Default agent version
        );

        _peerStore.addPeer(ipfsPeer);
      }
    } catch (e) {
      // print('Error querying peer ${peer.toString()}: $e');
    }
  }

  // Other DHT protocol methods...
}
