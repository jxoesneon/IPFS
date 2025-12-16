/// A priority-ordered list of blocks that a peer wants to receive.
///
/// Each CID in the wantlist has an associated priority (higher = more urgent).
/// Used in the Bitswap protocol to communicate block requests to peers.
///
/// Example:
/// ```dart
/// final wantlist = Wantlist();
/// wantlist.add(cid, priority: 10);
/// if (wantlist.contains(otherCid)) {
///   // print('Priority: ${wantlist.getPriority(otherCid)}');
/// }
/// ```
class Wantlist {
  /// Map of CIDs to their priority levels.
  final Map<String, int> _entries = {};

  /// Creates a new empty Wantlist.
  Wantlist();

  /// Adds a CID to the wantlist with optional priority
  void add(String cid, {int priority = 1}) {
    if (priority < 0) {
      throw ArgumentError('Priority must be non-negative');
    }
    _entries[cid] = priority;
  }

  /// Removes a CID from the wantlist
  void remove(String cid) {
    _entries.remove(cid);
  }

  /// Gets the priority for a CID
  /// Returns null if the CID is not in the wantlist
  int? getPriority(String cid) {
    return _entries[cid];
  }

  /// Checks if a CID is in the wantlist
  bool contains(String cid) {
    return _entries.containsKey(cid);
  }

  /// Gets all entries in the wantlist
  Map<String, int> get entries => Map.unmodifiable(_entries);

  /// Gets the number of entries in the wantlist
  int get length => _entries.length;

  /// Clears all entries from the wantlist
  void clear() {
    _entries.clear();
  }

  /// Creates a Wantlist from a map of CIDs to priorities
  factory Wantlist.fromMap(Map<String, int> entries) {
    final wantlist = Wantlist();
    entries.forEach((cid, priority) {
      wantlist.add(cid, priority: priority);
    });
    return wantlist;
  }

  /// Converts the wantlist to a map representation
  Map<String, int> toMap() {
    return Map.from(_entries);
  }

  @override
  String toString() {
    return 'Wantlist{entries: $_entries}';
  }
}
