import 'dart:typed_data';

/// Abstract class representing platform-specific operations.
abstract class IpfsPlatform {
  /// Whether the current platform is Web.
  bool get isWeb;

  /// Whether the current platform is Desktop/Mobile (supports dart:io).
  bool get isIO;

  // --- File System Operations ---

  /// Writes bytes to a file at [path].
  Future<void> writeBytes(String path, Uint8List bytes);

  /// Reads bytes from a file at [path].
  Future<Uint8List?> readBytes(String path);

  /// Checks if a file or directory exists at [path].
  Future<bool> exists(String path);

  /// Deletes a file or directory at [path].
  Future<void> delete(String path);

  /// Creates a directory at [path].
  Future<void> createDirectory(String path);

  /// Lists files in a directory at [path].
  /// Returns a list of filenames/paths.
  Future<List<String>> listDirectory(String path);

  // --- Network Operations ---

  // Note: HttpServer and Sockets are complex to abstract fully here.
  // Instead, we might expose methods to start services if supported.

  /// Helper to get the path separator for the platform.
  String get pathSeparator;
}

/// Returns the platform implementation (stub throws).
IpfsPlatform getPlatform() => throw UnsupportedError(
  'Cannot create platform without dart:io or dart:html',
);
