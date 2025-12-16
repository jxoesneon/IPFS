import 'package:dart_ipfs/src/protocols/bitswap/message.dart';

/// A priority-ordered list of blocks that a peer wants to receive.
///
/// Each CID in the wantlist has an associated priority and want type.
/// Used in the Bitswap protocol to communicate block requests to peers.
class Wantlist {
  /// Map of CIDs to their entries.
  final Map<String, WantlistEntry> _entries = {};

  /// Creates a new empty Wantlist.
  Wantlist();

  /// Adds a CID to the wantlist with optional parameters
  void add(
    String cid, {
    int priority = 1,
    WantType wantType = WantType.block,
    bool sendDontHave = false,
  }) {
    if (priority < 0) {
      throw ArgumentError('Priority must be non-negative');
    }
    _entries[cid] = WantlistEntry(
      cid: cid,
      priority: priority,
      wantType: wantType,
      sendDontHave: sendDontHave,
    );
  }

  /// Removes a CID from the wantlist
  void remove(String cid) {
    _entries.remove(cid);
  }

  /// Gets the entry for a CID
  WantlistEntry? getEntry(String cid) {
    return _entries[cid];
  }

  /// Checks if a CID is in the wantlist
  bool contains(String cid) {
    return _entries.containsKey(cid);
  }

  /// Gets all entries in the wantlist
  Map<String, WantlistEntry> get entries => Map.unmodifiable(_entries);

  /// Gets the number of entries in the wantlist
  int get length => _entries.length;

  /// Clears all entries from the wantlist
  void clear() {
    _entries.clear();
  }

  @override
  String toString() {
    return 'Wantlist{entries: $_entries}';
  }
}
