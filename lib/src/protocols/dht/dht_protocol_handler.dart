import 'dart:convert';
import 'dart:typed_data';

import '../../core/storage/datastore.dart';
import '../../core/types/p2p_types.dart';
import '../../proto/generated/dht/dht.pb.dart' as dht_pb;
import '../../proto/generated/dht/kademlia.pb.dart' as kad;
import '../../transport/router_interface.dart';
import '../../utils/logger.dart';

import '../ipns/ipns_record.dart';
import 'rate_limiter.dart';

/// Kademlia DHT protocol message handler.
///
/// Handles PING, FIND_NODE, GET_VALUE, and PUT_VALUE messages
/// according to the Kademlia protocol specification.
///
/// An optional [RateLimiter] may be supplied to throttle incoming DHT request
/// traffic and prevent amplification abuse.
class DHTProtocolHandler {
  /// Creates a handler with [_router] and [_storage].
  ///
  /// [rateLimiter] controls how many incoming DHT messages are processed per
  /// time window. When the limit is exceeded, messages are queued; when the
  /// queue is full they are dropped with a warning.
  DHTProtocolHandler(this._router, this._storage, {RateLimiter? rateLimiter})
    : _rateLimiter = rateLimiter,
      _logger = Logger('DHTProtocolHandler') {
    _setupHandlers();
  }

  /// Kademlia protocol ID.
  static const String protocolId = '/ipfs/kad/1.0.0';

  /// Maximum accepted PUT_VALUE record size — mirrors DHTClient's cap so
  /// oversized remote records are rejected before touching storage.
  static const int _maxDhtValueSize = 1024 * 1024;

  final RouterInterface _router;
  final Datastore _storage;
  final RateLimiter? _rateLimiter;
  final Logger _logger;

  void _setupHandlers() {
    _router.registerProtocolHandler(protocolId, _handleDHTMessage);
  }

  /// Handles incoming DHT messages.
  ///
  /// This method decodes the incoming [packet] and dispatches it to the
  /// appropriate handler based on the message type. If a rate limiter is
  /// configured, acquiring a permit may delay or drop the request.
  Future<void> _handleDHTMessage(LibP2PPacket packet) async {
    final rateLimiter = _rateLimiter;
    if (rateLimiter != null) {
      try {
        await rateLimiter.acquire();
      } on RateLimitExceededError {
        _logger.warning(
          'Dropping DHT message from ${packet.srcPeerId}: rate limit queue full',
        );
        return;
      }
    }

    try {
      final message = kad.Message.fromBuffer(packet.datagram);
      final response = await _buildResponse(message, packet.srcPeerId);
      if (response != null) {
        await _router.sendMessage(packet.srcPeerId, response.writeToBuffer());
      }
    } catch (e, st) {
      _logger.error(
        'Error handling DHT message from ${packet.srcPeerId}',
        e,
        st,
      );
    } finally {
      rateLimiter?.release();
    }
  }

  /// Builds the appropriate Kademlia response for [message], or returns null
  /// when the message type is unhandled.
  Future<kad.Message?> _buildResponse(
    kad.Message message,
    String srcPeerId,
  ) async {
    _logger.verbose(
      'Received DHT message of type ${message.type} from $srcPeerId',
    );

    final response = kad.Message();
    switch (message.type) {
      case kad.Message_MessageType.PING:
        response.type = kad.Message_MessageType.PING;
        return response;

      case kad.Message_MessageType.FIND_NODE:
        final closerPeers = await _findClosestPeers(message.key);
        response
          ..type = kad.Message_MessageType.FIND_NODE
          ..closerPeers.addAll(closerPeers);
        return response;

      case kad.Message_MessageType.GET_VALUE:
        final keyStr = utf8.decode(message.key);
        final storageKey = Key('/dht/values/$keyStr');
        final value = await _storage.get(storageKey);
        response.type = kad.Message_MessageType.GET_VALUE;
        if (value != null) {
          response.record = (dht_pb.Record()..value = value);
        } else {
          final closerPeers = await _findClosestPeers(message.key);
          response.closerPeers.addAll(closerPeers);
        }
        return response;

      case kad.Message_MessageType.PUT_VALUE:
        if (message.hasRecord()) {
          // Mirror DHTClient's inbound validation: an /ipns/ record must
          // decode, be signed and unexpired, bind the DHT key derived from
          // its public key, verify its signature, and advance the sequence
          // number past any record already stored for the key. Size/prefix
          // checks alone would let any peer plant forged or stale records —
          // and since registerProtocolHandler is last-registration-wins,
          // this path must be no weaker than the validating client handler.
          final keyBytes = Uint8List.fromList(message.key);
          final value = Uint8List.fromList(message.record.value);
          if (await _validateInboundDhtValue(keyBytes, value)) {
            final keyStr = utf8.decode(message.key, allowMalformed: true);
            final storageKey = Key('/dht/values/$keyStr');
            await _storage.put(storageKey, value);
            _logger.debug('Stored value for key: $keyStr');
          } else {
            _logger.warning(
              'Rejected invalid PUT_VALUE record from $srcPeerId',
            );
          }
        }
        response.type = kad.Message_MessageType.PUT_VALUE;
        return response;

      default:
        _logger.warning(
          'Unhandled DHT message type: ${message.type} from $srcPeerId',
        );
        return null;
    }
  }

  /// Whether [key] is an IPNS record key (`'/ipns/' + identity multihash`).
  static bool _isIpnsKey(Uint8List key) {
    const prefix = '/ipns/';
    if (key.length <= prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (key[i] != prefix.codeUnitAt(i)) return false;
    }
    return true;
  }

  /// Validates an inbound PUT_VALUE record before storage.
  ///
  /// Mirrors `DHTClient._validateInboundDhtValue`: `/ipns/` records must
  /// decode, be signed, be unexpired, verify their signature, match the DHT
  /// key derived from their public key, and carry a sequence number higher
  /// than any record already stored for the key.
  Future<bool> _validateInboundDhtValue(Uint8List key, Uint8List value) async {
    if (value.isEmpty || value.length > _maxDhtValueSize) return false;
    if (!_isIpnsKey(key)) return false;

    // Kubo-style records omit the embedded public key; recover it from the
    // DHT key itself ('/ipns/' + identity multihash of the public key).
    final recoveredKey = ipnsPublicKeyFromDhtKey(key);
    if (recoveredKey == null) return false;

    IPNSRecord record;
    try {
      record = IPNSRecord.decode(value, publicKey: recoveredKey);
    } catch (_) {
      return false;
    }
    if (!record.isSigned || record.isExpired) return false;

    // The record's public key must derive the very key it was stored under.
    final expectedKey = ipnsDhtKey(record.publicKey);
    if (expectedKey.length != key.length) return false;
    for (var i = 0; i < key.length; i++) {
      if (expectedKey[i] != key[i]) return false;
    }

    if (!await record.verify()) return false;

    // A stored record with an equal or higher sequence wins.
    final keyStr = utf8.decode(key, allowMalformed: true);
    final existing = await _storage.get(Key('/dht/values/$keyStr'));
    if (existing != null) {
      try {
        final stored = IPNSRecord.decode(Uint8List.fromList(existing));
        if (record.sequence <= stored.sequence) return false;
      } catch (_) {
        // Undecodable stored bytes do not block a valid record.
      }
    }
    return true;
  }

  /// Finds the closest peers to a given [key].
  ///
  /// Uses the DHT routing table to perform true Kademlia XOR distance-based
  /// peer selection. Falls back to connected peers if routing table is not available.
  Future<List<kad.Peer>> _findClosestPeers(
    List<int> key, {
    int numPeers = 20,
  }) async {
    // Try to use the DHT routing table for true distance-based selection
    final routingTable = _router.dhtRoutingTable;
    if (routingTable != null) {
      try {
        final closestPeerIds = routingTable.findClosestPeersToKey(
          key,
          k: numPeers,
        );
        return closestPeerIds
            .map((peerId) => kad.Peer()..id = peerId.value)
            .toList();
      } catch (e) {
        _logger.warning(
          'Failed to use DHT routing table, falling back to connected peers: $e',
        );
      }
    }

    // Fallback: Get connected peers from router interface
    // This is a simplification; true Kademlia would use XOR distance to key
    final connectedPeers = _router.connectedPeers.take(numPeers);

    // Convert to List<kad.Peer>
    return connectedPeers
        .map((peerId) => kad.Peer()..id = utf8.encode(peerId))
        .toList();
  }
}
