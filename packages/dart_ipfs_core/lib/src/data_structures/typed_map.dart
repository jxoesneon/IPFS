// lib/src/data_structures/typed_map.dart

/// An immutable, type-safe wrapper around a plain [Map<String, dynamic>].
///
/// Provides helper accessors for common IPLD/IPFS value types while keeping
/// the underlying map immutable from the public API.
class TypedMap {
  /// Creates an immutable view of the given [map].
  ///
  /// The entries are copied.
  TypedMap(Map<String, dynamic> map) : _map = Map.unmodifiable(Map.from(map));

  final Map<String, dynamic> _map;

  /// Returns the value for [key] cast to [T], or [defaultValue] if missing or
  /// not of type [T].
  T get<T>(String key, T defaultValue) {
    final value = _map[key];
    if (value is T) return value;
    return defaultValue;
  }

  /// Returns the raw value for [key].
  dynamic operator [](String key) => _map[key];

  /// Returns an unmodifiable view of the underlying map.
  Map<String, dynamic> toMap() => _map;

  /// Returns true if the map contains [key].
  bool containsKey(String key) => _map.containsKey(key);

  /// The number of entries in the map.
  int get length => _map.length;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TypedMap &&
          runtimeType == other.runtimeType &&
          _map == other._map;

  @override
  int get hashCode => _map.hashCode;
}
