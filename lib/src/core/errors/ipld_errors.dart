// src/core/errors/ipld_errors.dart
abstract class IPLDError implements Exception {
  final String message;
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
