// src/core/unixfs/unixfs_errors.dart
import 'dart:core';

/// Thrown when UnixFS path resolution fails because of a malformed path,
/// a missing link, or an attempt to escape the resolution root.
class PathResolutionError implements Exception {
  /// Creates a new [PathResolutionError] with the given [message].
  PathResolutionError(this.message);

  /// Human-readable description of the resolution failure.
  final String message;

  @override
  String toString() => 'PathResolutionError: $message';
}

/// Thrown when a cycle is detected while traversing a UnixFS DAG.
class DAGCycleError implements Exception {
  /// Creates a new [DAGCycleError] with the given [message].
  DAGCycleError(this.message);

  /// Human-readable description of the cycle.
  final String message;

  @override
  String toString() => 'DAGCycleError: $message';
}

/// Thrown when a symlink cycle is detected during UnixFS path resolution.
class SymlinkCycleError implements Exception {
  /// Creates a new [SymlinkCycleError] with the given [message].
  SymlinkCycleError(this.message);

  /// Human-readable description of the symlink cycle.
  final String message;

  @override
  String toString() => 'SymlinkCycleError: $message';
}
