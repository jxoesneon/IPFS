/// Error classes for IPFS Node lifecycle and management.
library;

/// Base class for all IPFS Node related errors.
abstract class IPFSNodeError extends StateError {
  /// Creates an [IPFSNodeError] with the given [message].
  IPFSNodeError(super.message, {this.details});

  /// Optional details about the error.
  final Object? details;

  @override
  String toString() =>
      'IPFSNodeError: $message${details != null ? ' ($details)' : ''}';
}

/// Error thrown when node initialization fails.
class NodeInitializationError extends IPFSNodeError {
  /// Creates a [NodeInitializationError].
  NodeInitializationError(super.message, {super.details});
}

/// Error thrown when node startup fails.
class NodeStartupError extends IPFSNodeError {
  /// Creates a [NodeStartupError].
  NodeStartupError(super.message, {super.details});
}

/// Error thrown when node shutdown fails.
class NodeShutdownError extends IPFSNodeError {
  /// Creates a [NodeShutdownError].
  NodeShutdownError(super.message, {super.details});
}

/// Error thrown when a required component is missing or fails.
class ComponentError extends IPFSNodeError {
  /// Creates a [ComponentError] for the given [component].
  ComponentError(this.component, super.message, {super.details});

  /// The component that failed.
  final String component;

  @override
  String toString() =>
      'ComponentError ($component): $message${details != null ? ' ($details)' : ''}';
}

/// Error thrown when the node is in an invalid state for an operation.
class NodeStateError extends IPFSNodeError {
  /// Creates a [NodeStateError].
  NodeStateError(super.message, {super.details});
}
