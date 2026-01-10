import 'dart:typed_data';

/// Error thrown when a datastore operation fails.
class DatastoreError extends Error {
  /// Creates a datastore error with the given message.
  DatastoreError(this.message);

  /// The error message.
  final String message;
  @override
  String toString() => 'DatastoreError: $message';
}

/// Represents a key in the datastore.
/// Keys are hierarchical path-like strings, e.g., /local/peers/Qm...
class Key {
  /// Creates a key from a path string, cleaning it if needed.
  Key(String s) : _string = _clean(s);

  final String _string;

  /// Returns the cleaned string representation.
  String get string => _string;

  static String _clean(String s) {
    if (s.isEmpty) return '/';
    if (!s.startsWith('/')) s = '/$s';
    if (s.length > 1 && s.endsWith('/')) s = s.substring(0, s.length - 1);
    return s;
  }

  /// Creates a child key under this key.
  Key child(Key child) {
    if (_string == '/') return child;
    return Key('$_string${child._string}');
  }

  /// Returns the parent key.
  Key parent() {
    if (_string == '/') return this;
    final lastSlash = _string.lastIndexOf('/');
    if (lastSlash == 0) return Key('/');
    return Key(_string.substring(0, lastSlash));
  }

  @override
  String toString() => _string;

  @override
  bool operator ==(Object other) => other is Key && other._string == _string;

  @override
  int get hashCode => _string.hashCode;
}

/// A Query object for the datastore.
class Query {
  /// Creates a new query with optional filters.
  Query({this.prefix, this.filters, this.orders, this.limit, this.offset, this.keysOnly = false});

  /// Optional key prefix to filter by.
  final String? prefix;

  /// Optional list of filters to apply.
  final List<QueryFilter>? filters;

  /// Optional ordering for results.
  final List<QueryOrder>? orders;

  /// Maximum number of results.
  final int? limit;

  /// Number of results to skip.
  final int? offset;

  /// If true, only return keys without values.
  final bool keysOnly;
}

/// Interface for filtering query results.
abstract class QueryFilter {
  /// Returns true if the entry should be included.
  bool filter(MapEntry<Key, Uint8List> entry);
}

/// Interface for ordering query results.
abstract class QueryOrder {
  /// Compares two entries for ordering.
  int compare(MapEntry<Key, Uint8List> a, MapEntry<Key, Uint8List> b);
}

/// The entry returned by a query.
class QueryEntry {
  /// Creates a query entry with a key and optional value.
  QueryEntry(this.key, this.value);

  /// The key of this entry.
  final Key key;

  /// The value, null if keysOnly was true.
  final Uint8List? value;
}

/// Abstract interface for a key-value datastore.
abstract class Datastore {
  /// Initialize the datastore (e.g. open database, create directory).
  Future<void> init();

  /// Store the given value at the given key.
  Future<void> put(Key key, Uint8List value);

  /// Get the value stored at the given key.
  Future<Uint8List?> get(Key key);

  /// Check if the given key exists.
  Future<bool> has(Key key);

  /// Delete the value at the given key.
  Future<void> delete(Key key);

  /// Query the datastore.
  Stream<QueryEntry> query(Query q);

  /// Close the datastore.
  Future<void> close();
}
