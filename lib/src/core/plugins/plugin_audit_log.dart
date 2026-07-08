// lib/src/core/plugins/plugin_audit_log.dart
//
// Immutable audit log for capability exercises. Every capability attempt is
// recorded with plugin ID, capability name, timestamp, and outcome.

import 'capability_exception.dart';

/// A single audit entry recording a capability exercise attempt.
class PluginAuditEntry {
  /// Creates an audit entry for the given capability exercise attempt.
  PluginAuditEntry({
    required this.pluginId,
    required this.capability,
    required this.timestamp,
    required this.outcome,
    this.reason,
  });

  /// The plugin that attempted the exercise.
  final String pluginId;

  /// The capability that was exercised or attempted.
  final String capability;

  /// UTC timestamp of the attempt.
  final DateTime timestamp;

  /// Outcome: `allowed`, `denied`, `unsigned`, `disabled`, etc.
  final String outcome;

  /// Optional reason or details.
  final String? reason;

  /// Returns this entry as a JSON-serializable map.
  Map<String, dynamic> toJson() => {
    'pluginId': pluginId,
    'capability': capability,
    'timestamp': timestamp.toIso8601String(),
    'outcome': outcome,
    if (reason != null) 'reason': reason,
  };
}

/// Audit log for plugin capability exercises.
///
/// The log is append-only from the plugin host's perspective. Callers can query
/// recent entries by plugin or capability.
class PluginAuditLog {
  final List<PluginAuditEntry> _entries = [];

  /// Records an audit entry.
  void record({
    required String pluginId,
    required String capability,
    required String outcome,
    String? reason,
  }) {
    _entries.add(
      PluginAuditEntry(
        pluginId: pluginId,
        capability: capability,
        timestamp: DateTime.now().toUtc(),
        outcome: outcome,
        reason: reason,
      ),
    );
  }

  /// Records a [CapabilityException] as a denied audit entry.
  void recordException(CapabilityException e) {
    record(
      pluginId: e.pluginId,
      capability: e.capability,
      outcome: e.outcome,
      reason: e.reason,
    );
  }

  /// Returns all recorded entries.
  List<PluginAuditEntry> get entries => List.unmodifiable(_entries);

  /// Returns entries filtered by plugin ID.
  List<PluginAuditEntry> forPlugin(String pluginId) =>
      _entries.where((e) => e.pluginId == pluginId).toList();

  /// Returns entries filtered by capability.
  List<PluginAuditEntry> forCapability(String capability) =>
      _entries.where((e) => e.capability == capability).toList();

  /// Clears all entries. Intended for tests only.
  void clear() => _entries.clear();
}
