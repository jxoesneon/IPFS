// lib/src/protocols/bitswap/ledger.dart

class BitLedger {
  final String peerId;
  int sentBytes = 0;
  int receivedBytes = 0;

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

  @override
  String toString() {
    return 'Ledger($peerId): sentBytes=$sentBytes, receivedBytes=$receivedBytes, debt=${getDebt()}';
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
}
