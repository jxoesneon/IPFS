// src/protocols/bitswap/ledger.dart
import 'dart:typed_data';
import 'package:dart_ipfs/src/proto/generated/bitswap/bitswap.pb.dart'
    as bitswap;

/// Tracks bandwidth exchange (sent vs received bytes) with a peer.
///
/// BitLedger implements Bitswap's debt-based exchange strategy,
/// where nodes preferentially serve peers who have served them.
/// A positive debt means the local node owes bytes to the peer.
///
/// See also:
/// - [LedgerManager] for managing ledgers across multiple peers
class BitLedger {
  /// Creates a new ledger for tracking bitswap exchanges with a specific peer.
  BitLedger(this.peerId, {this.onBytesChanged});

  /// The peer this ledger tracks.
  final String peerId;

  /// Optional callback invoked with each byte delta recorded —
  /// `(sentDelta, receivedDelta)`. Used by [LedgerManager] to maintain
  /// aggregate totals without rescanning every ledger.
  final void Function(int sentDelta, int receivedDelta)? onBytesChanged;

  /// Total bytes sent to this peer.
  int sentBytes = 0;

  /// Total bytes received from this peer.
  int receivedBytes = 0;

  /// Maximum number of block-data entries retained per ledger; oldest are
  /// evicted first.
  static const int maxBlockDataEntries = 128;

  final Map<String, Uint8List> _blockData = {};

  /// Record bytes sent to the peer.
  void addSentBytes(int bytes) {
    if (bytes < 0) throw ArgumentError('Cannot add negative bytes.');
    sentBytes += bytes;
    onBytesChanged?.call(bytes, 0);
  }

  /// Record bytes received from the peer.
  void addReceivedBytes(int bytes) {
    if (bytes < 0) throw ArgumentError('Cannot add negative bytes.');
    receivedBytes += bytes;
    onBytesChanged?.call(0, bytes);
  }

  /// Get the current debt balance.
  /// Positive values mean the local node owes bytes to the remote peer.
  int getDebt() {
    return sentBytes - receivedBytes;
  }

  /// Add new methods for block data management
  /// Stores block data for a CID.
  void storeBlockData(String cid, Uint8List data) {
    if (!_blockData.containsKey(cid) &&
        _blockData.length >= maxBlockDataEntries) {
      _blockData.remove(_blockData.keys.first);
    }
    _blockData[cid] = data;
  }

  /// Retrieves block data for a CID.
  ///
  /// Throws [StateError] if the block is not found.
  Uint8List getBlockData(String cid) {
    if (!_blockData.containsKey(cid)) {
      throw StateError('Block data not found for CID: $cid');
    }
    return _blockData[cid]!;
  }

  /// Returns whether a block is stored for the given CID.
  bool hasBlock(String cid) {
    return _blockData.containsKey(cid);
  }

  @override
  String toString() {
    return 'Ledger($peerId): sentBytes=$sentBytes, receivedBytes=$receivedBytes, debt=${getDebt()}';
  }

  /// Updates the ledger with a received message
  void receivedMessage(String peerId, bitswap.Message message) {
    // Update received bytes from blocks (Bitswap 1.0)
    for (var blockBytes in message.blocks) {
      addReceivedBytes(blockBytes.length);
    }

    // Update received bytes from payload (Bitswap 1.1)
    for (var block in message.payload) {
      addReceivedBytes(block.data.length);
    }
  }
}

/// Manages multiple [BitLedger] instances for different peers.
class LedgerManager {
  /// Maximum number of peer ledgers retained; oldest entries are evicted.
  static const int maxLedgers = 1024;

  final Map<String, BitLedger> _ledgers = {};
  int _totalSent = 0;
  int _totalReceived = 0;

  /// Retrieve the ledger for a given peer. If it doesn't exist, create it.
  BitLedger getLedger(String peerId) {
    final existing = _ledgers[peerId];
    if (existing != null) return existing;
    if (_ledgers.length >= maxLedgers) {
      final evicted = _ledgers.remove(_ledgers.keys.first);
      if (evicted != null) {
        _totalSent -= evicted.sentBytes;
        _totalReceived -= evicted.receivedBytes;
      }
    }
    return _ledgers.putIfAbsent(
      peerId,
      () => BitLedger(
        peerId,
        onBytesChanged: (sent, received) {
          _totalSent += sent;
          _totalReceived += received;
        },
      ),
    );
  }

  /// Print all ledgers for debugging purposes.
  void printLedgers() {
    _ledgers.forEach((peerId, ledger) {
      // print(ledger);
    });
  }

  /// Clear a specific peer ledger.
  void clearLedger(String peerId) {
    final removed = _ledgers.remove(peerId);
    if (removed != null) {
      _totalSent -= removed.sentBytes;
      _totalReceived -= removed.receivedBytes;
    }
  }

  /// Clear all peer ledgers.
  void clearAllLedgers() {
    _ledgers.clear();
    _totalSent = 0;
    _totalReceived = 0;
  }

  /// Gets the total bandwidth statistics for all ledgers. Totals are
  /// maintained incrementally — this is O(1) even when called per message.
  Map<String, int> getBandwidthStats() {
    return {'sent': _totalSent, 'received': _totalReceived};
  }
}
