import 'dart:typed_data';

/// Error thrown when a datastore operation fails.
class DatastoreError extends Error {
  DatastoreError(this.message);
  final String message;
  @override
  String toString() => 'DatastoreError: $message';
}

/// Represents a key in the datastore.
/// Keys are hierarchical path-like strings, e.g., /local/peers/Qm...
class Key {

  Key(String s) : _string = _clean(s);
  final String _string;

  String get string => _string;

  static String _clean(String s) {
    if (s.isEmpty) return '/';
    if (!s.startsWith('/')) s = '/$s';
    if (s.length > 1 && s.endsWith('/')) s = s.substring(0, s.length - 1);
    return s;
  }

  Key child(Key child) {
    if (_string == '/') return child;
    return Key('$_string${child._string}');
  }

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

  Query({
    this.prefix,
    this.filters,
    this.orders,
    this.limit,
    this.offset,
    this.keysOnly = false,
  });
  final String? prefix;
  final List<QueryFilter>? filters;
  final List<QueryOrder>? orders;
  final int? limit;
  final int? offset;
  final bool keysOnly;
}

abstract class QueryFilter {
  bool filter(MapEntry<Key, Uint8List> entry);
}

abstract class QueryOrder {
  int compare(MapEntry<Key, Uint8List> a, MapEntry<Key, Uint8List> b);
}

/// The entry returned by a query.
class QueryEntry { // Null if keysOnly

  QueryEntry(this.key, this.value);
  final Key key;
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
