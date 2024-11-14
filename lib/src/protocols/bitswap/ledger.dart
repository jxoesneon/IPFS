// src/protocols/bitswap/ledger.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:dart_ipfs/src/proto/generated/bitswap/bitswap.pb.dart'
    as bitswap;
// lib/src/protocols/bitswap/ledger.dart

class BitLedger {
  final String peerId;
  int sentBytes = 0;
  int receivedBytes = 0;
  final Map<String, Uint8List> _blockData = {};

  /// Create a new ledger for tracking bitswap exchanges with a specific peer.
  BitLedger(this.peerId);

  /// Record bytes sent to the peer.
  void addSentBytes(int bytes) {
    if (bytes < 0) throw ArgumentError('Cannot add negative bytes.');
    sentBytes += bytes;
  }

  /// Record bytes received from the peer.
  void addReceivedBytes(int bytes) {
    if (bytes < 0) throw ArgumentError('Cannot add negative bytes.');
    receivedBytes += bytes;
  }

  /// Get the current debt balance.
  /// Positive values mean the local node owes bytes to the remote peer.
  int getDebt() {
    return sentBytes - receivedBytes;
  }

  /// Add new methods for block data management
  void storeBlockData(String cid, Uint8List data) {
    _blockData[cid] = data;
  }

  Uint8List getBlockData(String cid) {
    if (!_blockData.containsKey(cid)) {
      throw StateError('Block data not found for CID: $cid');
    }
    return _blockData[cid]!;
  }

  bool hasBlock(String cid) {
    return _blockData.containsKey(cid);
  }

  @override
  String toString() {
    return 'Ledger($peerId): sentBytes=$sentBytes, receivedBytes=$receivedBytes, debt=${getDebt()}';
  }

  /// Updates the ledger with a received message
  void receivedMessage(String peerId, bitswap.Message message) {
    // Update received bytes from blocks
    for (var block in message.blocks) {
      addReceivedBytes(block.data.length);
    }

    // Store any new blocks
    for (var block in message.blocks) {
      if (block.data.isNotEmpty) {
        storeBlockData(
            base64.encode(block.cid), Uint8List.fromList(block.data));
      }
    }
  }
}

/// Class for managing multiple ledgers
class LedgerManager {
  final Map<String, BitLedger> _ledgers = {};

  /// Retrieve the ledger for a given peer. If it doesn't exist, create it.
  BitLedger getLedger(String peerId) {
    return _ledgers.putIfAbsent(peerId, () => BitLedger(peerId));
  }

  /// Print all ledgers for debugging purposes.
  void printLedgers() {
    _ledgers.forEach((peerId, ledger) {
      print(ledger);
    });
  }

  /// Clear a specific peer ledger.
  void clearLedger(String peerId) {
    _ledgers.remove(peerId);
  }

  /// Clear all peer ledgers.
  void clearAllLedgers() {
    _ledgers.clear();
  }

  /// Gets the total bandwidth statistics for all ledgers
  Map<String, int> getBandwidthStats() {
    int totalSent = 0;
    int totalReceived = 0;

    for (final ledger in _ledgers.values) {
      totalSent += ledger.sentBytes;
      totalReceived += ledger.receivedBytes;
    }

    return {'sent': totalSent, 'received': totalReceived};
  }
}
