import 'dart:typed_data';

/// Abstract class representing platform-specific operations.
///
/// These methods are implemented differently across platforms (VM vs Web)
/// to provide a unified API for file system and system operations.
abstract class IpfsPlatform {
  /// Whether the current platform is Web.
  bool get isWeb;

  /// Whether the current platform is Desktop/Mobile (supports dart:io).
  bool get isIO;

  // --- File System Operations ---

  /// Returns a [Future] that completes when [bytes] are written to a file at [path].
  ///
  /// On VM, this writes to the local file system. On Web, this stores the data
  /// in IndexedDB.
  Future<void> writeBytes(String path, Uint8List bytes);

  /// Returns a [Future] that completes when [content] is written to a file at [path].
  ///
  /// On VM, this writes to the local file system. On Web, this stores the data
  /// in IndexedDB.
  Future<void> writeString(String path, String content);

  /// Returns a [Future] that resolves to the [Uint8List] bytes from a file at [path],
  /// or `null` if the file does not exist.
  Future<Uint8List?> readBytes(String path);

  /// Returns a [Future] that resolves to the string content from a file at [path],
  /// or `null` if the file does not exist.
  Future<String?> readString(String path);

  /// Returns a [Future] that resolves to `true` if a file or directory exists at [path].
  Future<bool> exists(String path);

  /// Returns a [Future] that completes when a file or directory at [path] is deleted.
  Future<void> delete(String path);

  /// Returns a [Future] that completes when a directory is created at [path].
  ///
  /// On Web, directories are often implicit in the key-value storage.
  Future<void> createDirectory(String path);

  /// Returns a [Future] that resolves to the path of a newly created temporary directory
  /// with an optional [prefix].
  Future<String> createTempDirectory([String? prefix]);

  /// Returns a [Future] that resolves to a [List] of filenames/paths in the directory at [path].
  Future<List<String>> listDirectory(String path);

  /// Returns a [Future] that resolves to the size of a file at [path] in bytes.
  Future<int> getLength(String path);

  // --- System Information ---

  /// Returns the name of the operating system.
  String get operatingSystem;

  /// Returns the version of the platform/runtime.
  String get version;

  /// Returns a [Future] that resolves to a password entered by the user.
  ///
  /// Implementation may vary or return `null` if no secure terminal is available.
  Future<String?> promptPassword(String message);

  // --- Network Operations ---

  // Note: HttpServer and Sockets are complex to abstract fully here.
  // Instead, we might expose methods to start services if supported.

  /// Helper to get the path separator for the platform.
  String get pathSeparator;
}

/// Returns the platform-specific implementation of [IpfsPlatform].
///
/// Throws [UnsupportedError] if called from a stub without a proper implementation.
IpfsPlatform getPlatform() => throw UnsupportedError(
  'Cannot create platform without dart:io or dart:html',
);
