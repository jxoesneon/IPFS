// lib/src/core/plugins/capability_registry.dart
//
// Deny-by-default capability registry with audit logging. The registry knows
// the canonical set of capabilities for Phase 1 and can gate service calls.

import 'capability_exception.dart';
import 'plugin_audit_log.dart';

/// Deny-by-default registry for plugin capabilities.
class CapabilityRegistry {
  /// Creates a registry with the optional [auditLog] and [knownCapabilities].
  CapabilityRegistry({
    PluginAuditLog? auditLog,
    Set<String>? knownCapabilities,
  })  : _auditLog = auditLog ?? PluginAuditLog(),
        _knownCapabilities = knownCapabilities ?? _defaultCapabilities;

  final PluginAuditLog _auditLog;
  final Set<String> _knownCapabilities;

  /// Canonical Phase 1 capability set.
  static Set<String> get _defaultCapabilities => {
    'blockstore.read',
    'blockstore.write',
    'network.bitswap.observe',
    'metrics.emit',
    'gateway.observe',
    'pin.add',
  };

  /// Returns `true` if [capability] is known to the host.
  bool isKnown(String capability) => _knownCapabilities.contains(capability);

  /// Returns the list of capabilities from [requested] that are unknown.
  List<String> unknownCapabilities(List<String> requested) =>
      requested.where((c) => !_knownCapabilities.contains(c)).toList();

  /// Returns the audit log instance.
  PluginAuditLog get auditLog => _auditLog;

  /// Asserts that [pluginId] may exercise [capability].
  ///
  /// Throws [CapabilityException] with outcome `denied` if the capability is
  /// not in [grantedCapabilities]. Records the attempt in the audit log.
  void require(
    String pluginId,
    String capability,
    Set<String> grantedCapabilities,
  ) {
    if (!grantedCapabilities.contains(capability)) {
      final exception = CapabilityException(
        pluginId,
        capability,
        'denied',
        reason: 'capability not granted',
      );
      _auditLog.recordException(exception);
      throw exception;
    }
    _auditLog.record(
      pluginId: pluginId,
      capability: capability,
      outcome: 'allowed',
    );
  }

  /// Records a plugin load outcome without throwing.
  void recordLoadOutcome(
    String pluginId, {
    required String outcome,
    String? reason,
  }) {
    _auditLog.record(
      pluginId: pluginId,
      capability: 'plugin.load',
      outcome: outcome,
      reason: reason,
    );
  }
}
