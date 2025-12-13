// src/core/errors/ipld_errors.dart

/// Base class for IPLD (InterPlanetary Linked Data) errors.
///
/// IPLD errors occur during encoding, decoding, resolution, and
/// validation of content-addressed data structures.
abstract class IPLDError implements Exception {
  /// The error message describing what went wrong.
  final String message;

  /// Creates a new IPLD error with the given [message].
  IPLDError(this.message);

  @override
  String toString() => message;
}

class IPLDEncodingError extends IPLDError {
  IPLDEncodingError(String message) : super('IPLD encoding error: $message');
}

class IPLDDecodingError extends IPLDError {
  IPLDDecodingError(String message) : super('IPLD decoding error: $message');
}

class IPLDResolutionError extends IPLDError {
  IPLDResolutionError(String message)
      : super('IPLD resolution error: $message');
}

class IPLDStorageError extends IPLDError {
  IPLDStorageError(String message) : super('IPLD storage error: $message');
}

class IPLDValidationError extends IPLDError {
  IPLDValidationError(String message)
      : super('IPLD validation error: $message');
}

class IPLDLinkError extends IPLDError {
  IPLDLinkError(String message) : super('IPLD link error: $message');
}

class IPLDSchemaError extends IPLDError {
  IPLDSchemaError(String message) : super('IPLD schema error: $message');
}
