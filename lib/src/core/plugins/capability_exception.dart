// lib/src/core/plugins/capability_exception.dart
//
// Exception thrown when a plugin attempts to exercise a capability it has not
// been granted. This is the primary enforcement signal for the deny-by-default
// capability model.

/// Exception thrown when a plugin exercises (or attempts to exercise) a
/// capability outside its granted set.
class CapabilityException implements Exception {
  /// Creates a [CapabilityException] for the given [pluginId], [capability],
  /// and [outcome], with an optional [reason].
  CapabilityException(
    this.pluginId,
    this.capability,
    this.outcome, {
    this.reason,
  });

  /// The plugin that caused the violation.
  final String pluginId;

  /// The capability that was attempted.
  final String capability;

  /// The outcome/result of the attempted exercise (e.g. `denied`).
  final String outcome;

  /// Optional human-readable reason.
  final String? reason;

  @override
  String toString() =>
      'CapabilityException: plugin=$pluginId capability=$capability '
      'outcome=$outcome${reason != null ? ' reason=$reason' : ''}';
}
