// src/core/errors/ipld_errors.dart

/// Base class for IPLD (InterPlanetary Linked Data) errors.
///
/// IPLD errors occur during encoding, decoding, resolution, and
/// validation of content-addressed data structures.
abstract class IPLDError implements Exception {
  /// Creates a new IPLD error with the given [message].
  IPLDError(this.message);

  /// The error message describing what went wrong.
  final String message;

  @override
  String toString() => message;
}

/// Error during IPLD encoding (e.g., serialization failures).
class IPLDEncodingError extends IPLDError {
  /// Creates an encoding error with the given message.
  IPLDEncodingError(String message) : super('IPLD encoding error: $message');
}

/// Error during IPLD decoding (e.g., parsing failures).
class IPLDDecodingError extends IPLDError {
  /// Creates a decoding error with the given message.
  IPLDDecodingError(String message) : super('IPLD decoding error: $message');
}

/// Error during IPLD path resolution.
class IPLDResolutionError extends IPLDError {
  /// Creates a resolution error with the given message.
  IPLDResolutionError(String message)
    : super('IPLD resolution error: $message');
}

/// Error during IPLD storage operations.
class IPLDStorageError extends IPLDError {
  /// Creates a storage error with the given message.
  IPLDStorageError(String message) : super('IPLD storage error: $message');
}

/// Error during IPLD content validation.
class IPLDValidationError extends IPLDError {
  /// Creates a validation error with the given message.
  IPLDValidationError(String message)
    : super('IPLD validation error: $message');
}

/// Error resolving IPLD links (e.g., broken DAG references).
class IPLDLinkError extends IPLDError {
  /// Creates a link error with the given message.
  IPLDLinkError(String message) : super('IPLD link error: $message');
}

/// Error during IPLD schema validation.
class IPLDSchemaError extends IPLDError {
  /// Creates a schema error with the given message.
  IPLDSchemaError(String message) : super('IPLD schema error: $message');
}

