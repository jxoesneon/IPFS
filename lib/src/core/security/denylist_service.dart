// lib/src/core/security/denylist_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/security_config.dart';
import 'package:dart_ipfs/src/core/interfaces/i_lifecycle.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:dart_multihash/dart_multihash.dart';
import 'package:http/http.dart' as http;
import 'package:multibase/multibase.dart';

/// Statistics describing the current state of a denylist refresh.
class DenylistStats {
  /// Creates a new [DenylistStats].
  DenylistStats({
    required this.loadedEntries,
    this.lastRefresh,
    required this.refreshErrors,
  });

  /// Number of entries currently loaded.
  final int loadedEntries;

  /// Timestamp of the last successful refresh.
  final DateTime? lastRefresh;

  /// Number of failed refresh attempts since the service started.
  final int refreshErrors;

  /// Converts this snapshot to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'loadedEntries': loadedEntries,
    'lastRefresh': lastRefresh?.toIso8601String(),
    'refreshErrors': refreshErrors,
  };
}

/// A single audit event recorded when content is matched by the denylist.
class DenylistAuditEvent {
  /// Creates a new [DenylistAuditEvent].
  DenylistAuditEvent({
    required this.timestamp,
    required this.cidOrMultihash,
    required this.action,
    required this.source,
    this.reason,
  });

  /// When the event occurred.
  final DateTime timestamp;

  /// The CID or multihash that matched the denylist.
  final String cidOrMultihash;

  /// The action taken: `"blocked"`, `"logged"`, or `"allowed"`.
  final String action;

  /// The layer that triggered the event: `"gateway"`, `"rpc"`, or `"dht"`.
  final String source;

  /// Optional operator-provided reason from list metadata.
  final String? reason;

  /// Converts this event to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'cidOrMultihash': cidOrMultihash,
    'action': action,
    'source': source,
    if (reason != null) 'reason': reason,
  };
}

/// Immutable snapshot of a loaded denylist used for O(1) lookups.
class _DenylistSnapshot {
  _DenylistSnapshot({
    required this.cidStrings,
    required this.multihashHexes,
    required this.reasons,
    required this.warnings,
    required this.totalBytes,
  });

  final Set<String> cidStrings;
  final Set<String> multihashHexes;
  final Map<String, String> reasons;
  final int warnings;
  final int totalBytes;

  bool get isEmpty => cidStrings.isEmpty && multihashHexes.isEmpty;

  int get entryCount => cidStrings.length + multihashHexes.length;

  String? reasonFor(String cidOrMultihash, String multihashHex) {
    return reasons[cidOrMultihash] ?? reasons[multihashHex];
  }
}

/// Result of parsing a denylist source.
class _ParseResult {
  _ParseResult({required this.snapshot, required this.warnings});

  final _DenylistSnapshot snapshot;
  final int warnings;
}

/// Operator-controlled content denylist service.
///
/// Supports CID strings, multihash strings, and BadBits-style compact lists.
/// The service is default-off: it only blocks requests when the operator
/// explicitly enables it via [SecurityConfig.enableDenylist].
class DenylistService implements ILifecycle {
  /// Creates a denylist service from security configuration and metrics.
  ///
  /// [storagePath] is an optional local file path used to persist a cached
  /// copy of the last successfully loaded list. When provided, the service
  /// falls back to the cached copy if the configured source is unavailable.
  DenylistService(
    this._config,
    this._metrics, {
    String? storagePath,
    http.Client? httpClient,
  }) : _storagePath = storagePath,
       _httpClient = httpClient ?? http.Client(),
       _internalHttpClient = httpClient == null {
    _logger = Logger('DenylistService');
    _snapshot = _emptySnapshot();
  }

  final SecurityConfig _config;
  final MetricsCollector _metrics;
  final String? _storagePath;
  final http.Client _httpClient;
  final bool _internalHttpClient;
  late Logger _logger;

  _DenylistSnapshot _snapshot = _DenylistSnapshot(
    cidStrings: const <String>{},
    multihashHexes: const <String>{},
    reasons: const <String, String>{},
    warnings: 0,
    totalBytes: 0,
  );

  final List<DenylistAuditEvent> _auditLog = [];
  Timer? _refreshTimer;
  DateTime? _lastRefresh;
  int _refreshErrors = 0;
  bool _started = false;

  static const int _maxLineLength = 4096;
  static const int _maxEntries = 1000000;
  static const int _maxBytes = 256 * 1024 * 1024;
  static const int _maxAuditLogSize = 10000;

  static const Set<String> _validActions = {'block', 'log'};

  /// Returns whether the denylist is enabled and contains entries.
  bool get isEnabled => _config.enableDenylist && !_snapshot.isEmpty;

  /// Returns whether the operator has enabled the denylist in configuration.
  bool get configuredEnabled => _config.enableDenylist;

  /// Returns the number of loaded entries (CIDs + multihashes).
  int get length => _snapshot.entryCount;

  /// Returns the current denylist statistics.
  DenylistStats getStats() => DenylistStats(
    loadedEntries: _snapshot.entryCount,
    lastRefresh: _lastRefresh,
    refreshErrors: _refreshErrors,
  );

  /// Returns a copy of the audit log, oldest first.
  List<DenylistAuditEvent> getAuditLog() => List.unmodifiable(_auditLog);

  /// Returns the configured default action: `"block"` or `"log"`.
  String get defaultAction =>
      _validActions.contains(_config.denylistDefaultAction)
      ? _config.denylistDefaultAction
      : 'block';

  /// Starts the service, loads the initial denylist, and schedules refreshes.
  @override
  Future<void> start() async {
    if (_started) return;
    _started = true;

    if (!_config.enableDenylist) {
      _logger.info('Denylist service is disabled by configuration');
      return;
    }

    await _loadInitial();
    _scheduleRefreshTimer();
  }

  /// Stops the service and cancels the refresh timer.
  @override
  Future<void> stop() async {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _started = false;
    if (_internalHttpClient) {
      _httpClient.close();
    }
  }

  /// Loads the denylist from the configured source, falling back to the cached
  /// copy when available.
  Future<void> _loadInitial() async {
    final path = _config.denylistPath;
    if (path == null || path.isEmpty) {
      _logger.warning(
        'Denylist enabled but no source path configured; service remains inactive',
      );
      return;
    }

    try {
      if (_isUrl(path)) {
        await loadFromUrl(path);
      } else {
        await loadFromPath(path);
      }
    } catch (e, st) {
      _logger.warning(
        'Failed to load denylist from configured source: $path',
        e,
        st,
      );
      await _tryLoadFromStorage();
    }
  }

  /// Schedules the periodic refresh timer based on configuration.
  void _scheduleRefreshTimer() {
    final interval = _config.denylistRefreshInterval;
    if (interval <= Duration.zero) return;

    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(interval, (_) async {
      try {
        await refresh();
      } catch (e, st) {
        _logger.warning('Scheduled denylist refresh failed', e, st);
      }
    });
  }

  /// Refreshes the denylist from the configured source.
  Future<void> refresh() async {
    final path = _config.denylistPath;
    if (path == null || path.isEmpty) return;

    if (_isUrl(path)) {
      await loadFromUrl(path);
    } else {
      await loadFromPath(path);
    }
  }

  /// Loads the denylist from a local file path.
  Future<void> loadFromPath(String path) async {
    _logger.info('Loading denylist from path: $path');
    try {
      final file = File(path);
      if (!await file.exists()) {
        throw FileSystemException('Denylist file not found', path);
      }
      final bytes = await file.readAsBytes();
      _loadCompactBytes(bytes);
    } on FormatException {
      rethrow;
    } catch (e, st) {
      _logger.warning('Failed to load denylist from path: $path', e, st);
      rethrow;
    }
  }

  /// Loads the denylist from an HTTP(S) URL.
  Future<void> loadFromUrl(String url) async {
    _logger.info('Loading denylist from URL: $url');
    try {
      final response = await _httpClient
          .get(Uri.parse(url))
          .timeout(const Duration(minutes: 5));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      _loadCompactBytes(response.bodyBytes);
      await _persistBytes(response.bodyBytes);
    } on FormatException {
      _refreshErrors++;
      rethrow;
    } catch (e, st) {
      _refreshErrors++;
      _logger.warning('Failed to load denylist from URL: $url', e, st);
      rethrow;
    }
  }

  /// Loads a compact BadBits-style denylist from raw bytes.
  void loadCompactBytes(Uint8List bytes) {
    _loadCompactBytes(bytes);
  }

  void _loadCompactBytes(Uint8List bytes) {
    if (bytes.length > _maxBytes) {
      throw const FormatException('Denylist exceeds maximum size');
    }

    final text = utf8.decode(bytes, allowMalformed: true);
    final result = _parseCompact(text, bytes.length);

    if (result.snapshot.entryCount > _maxEntries) {
      throw const FormatException('Denylist exceeds maximum entry count');
    }

    if (bytes.isNotEmpty && result.snapshot.isEmpty) {
      throw const FormatException('Denylist contains no valid entries');
    }

    _snapshot = result.snapshot;
    _lastRefresh = DateTime.now().toUtc();

    _logger.warning(
      'Denylist loaded: ${result.snapshot.entryCount} entries '
      'from source (warnings: ${result.warnings})',
    );

    if (bytes.isNotEmpty) {
      unawaited(_persistBytes(bytes));
    }
  }

  _ParseResult _parseCompact(String text, int totalBytes) {
    final cidStrings = <String>{};
    final multihashHexes = <String>{};
    final reasons = <String, String>{};
    var warnings = 0;

    final lines = const LineSplitter().convert(text);
    for (final rawLine in lines) {
      if (rawLine.length > _maxLineLength) {
        warnings++;
        continue;
      }

      final line = rawLine.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#')) {
        final metadata = _tryParseJsonComment(line);
        if (metadata != null) {
          final reason = metadata['reason'] as String?;
          final cid = metadata['cid'] as String?;
          if (reason != null && cid != null) {
            try {
              final decoded = CID.decode(cid);
              final hex = _multihashHex(decoded.multihash);
              reasons[hex] = reason;
              reasons[cid] = reason;
            } catch (_) {
              reasons[cid] = reason;
            }
          }
        }
        continue;
      }

      // Try multihash first so that raw multihash entries (e.g. BadBits
      // compact base32 strings) are not misidentified as CIDv0 strings.
      final multihash = _tryDecodeMultihash(line);
      if (multihash != null) {
        multihashHexes.add(_multihashHex(multihash));
        continue;
      }

      final cid = _tryDecodeCid(line);
      if (cid != null) {
        final cidStr = cid.encode();
        final hex = _multihashHex(cid.multihash);
        cidStrings.add(cidStr);
        multihashHexes.add(hex);
        continue;
      }

      warnings++;
    }

    return _ParseResult(
      snapshot: _DenylistSnapshot(
        cidStrings: cidStrings,
        multihashHexes: multihashHexes,
        reasons: reasons,
        warnings: warnings,
        totalBytes: totalBytes,
      ),
      warnings: warnings,
    );
  }

  Map<String, dynamic>? _tryParseJsonComment(String line) {
    try {
      final jsonStr = line.substring(1).trim();
      if (jsonStr.isEmpty) return null;
      final decoded = json.decode(jsonStr) as Map<String, dynamic>?;
      return decoded;
    } catch (_) {
      return null;
    }
  }

  CID? _tryDecodeCid(String line) {
    try {
      return CID.decode(line);
    } catch (_) {
      return null;
    }
  }

  MultihashInfo? _tryDecodeMultihash(String line) {
    try {
      final bytes = multibaseDecode(line);
      return Multihash.decode(bytes);
    } catch (_) {
      return null;
    }
  }

  String _multihashHex(MultihashInfo multihash) {
    return hex.encode(multihash.toBytes());
  }

  String _cidOrMultihashHex(String value) {
    try {
      final cid = CID.decode(value);
      return _multihashHex(cid.multihash);
    } catch (_) {
      try {
        final mh = _tryDecodeMultihash(value);
        if (mh != null) return _multihashHex(mh);
      } catch (_) {
        // fall through
      }
    }
    return value;
  }

  /// Returns `true` if the CID is blocked.
  bool isBlocked(CID cid) {
    if (!_config.enableDenylist) return false;
    return _snapshot.multihashHexes.contains(_multihashHex(cid.multihash)) ||
        _snapshot.cidStrings.contains(cid.encode());
  }

  /// Returns `true` if the CID string is blocked.
  bool isBlockedByCidString(String cidStr) {
    if (!_config.enableDenylist) return false;
    try {
      final cid = CID.decode(cidStr);
      if (_snapshot.multihashHexes.contains(_multihashHex(cid.multihash))) {
        return true;
      }
      if (_snapshot.cidStrings.contains(cid.encode())) {
        return true;
      }
    } catch (_) {
      if (_snapshot.cidStrings.contains(cidStr)) {
        return true;
      }
    }
    return false;
  }

  /// Returns `true` if the multihash string is blocked.
  bool isBlockedByMultihash(String multihash) {
    if (!_config.enableDenylist) return false;
    try {
      final mh = _tryDecodeMultihash(multihash);
      if (mh != null && _snapshot.multihashHexes.contains(_multihashHex(mh))) {
        return true;
      }
    } catch (_) {
      // ignore
    }
    return _snapshot.cidStrings.contains(multihash);
  }

  /// Returns `true` if the path contains a blocked CID or IPNS name.
  bool isBlockedPath(String path) {
    if (!_config.enableDenylist) return false;
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    for (var i = 0; i < segments.length - 1; i++) {
      final namespace = segments[i];
      final value = segments[i + 1];
      if (namespace == 'ipfs') {
        if (isBlockedByCidString(value)) {
          return true;
        }
      } else if (namespace == 'ipns') {
        if (_snapshot.cidStrings.contains(value)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Records a denylist hit and returns the action that should be taken.
  ///
  /// Returns `"block"` or `"log"` depending on the configured default action.
  /// The audit event is always recorded.
  String recordHit(
    String cidOrMultihash, {
    required String source,
    String? reason,
  }) {
    if (!_config.enableDenylist) return 'allowed';

    final action = defaultAction;
    final multihashHex = _cidOrMultihashHex(cidOrMultihash);
    final resolvedReason =
        reason ?? _snapshot.reasonFor(cidOrMultihash, multihashHex);

    _appendAuditEvent(
      DenylistAuditEvent(
        timestamp: DateTime.now().toUtc(),
        cidOrMultihash: cidOrMultihash,
        action: action,
        source: source,
        reason: resolvedReason,
      ),
    );

    if (action == 'log') {
      _metrics.recordSecurityEvent('denylist_logged');
    } else {
      _metrics.recordSecurityEvent('denylist_blocked');
    }

    return action;
  }

  void _appendAuditEvent(DenylistAuditEvent event) {
    while (_auditLog.length >= _maxAuditLogSize) {
      _auditLog.removeAt(0);
    }
    _auditLog.add(event);
  }

  /// Adds a single CID to the in-memory denylist.
  void block(CID cid) {
    final snapshot = _copySnapshot();
    snapshot.cidStrings.add(cid.encode());
    snapshot.multihashHexes.add(_multihashHex(cid.multihash));
    _snapshot = snapshot;
  }

  /// Adds a CID string to the in-memory denylist.
  void blockCidString(String cidStr) {
    final snapshot = _copySnapshot();
    snapshot.cidStrings.add(cidStr);
    try {
      final cid = CID.decode(cidStr);
      snapshot.multihashHexes.add(_multihashHex(cid.multihash));
    } catch (_) {
      // literal entry
    }
    _snapshot = snapshot;
  }

  /// Removes a CID from the in-memory denylist.
  void unblock(CID cid) {
    final snapshot = _copySnapshot();
    snapshot.cidStrings.remove(cid.encode());
    snapshot.multihashHexes.remove(_multihashHex(cid.multihash));
    _snapshot = snapshot;
  }

  /// Removes a CID string from the in-memory denylist.
  void unblockCidString(String cidStr) {
    final snapshot = _copySnapshot();
    snapshot.cidStrings.remove(cidStr);
    try {
      final cid = CID.decode(cidStr);
      snapshot.multihashHexes.remove(_multihashHex(cid.multihash));
    } catch (_) {
      // literal entry
    }
    _snapshot = snapshot;
  }

  /// Clears all in-memory denylist entries.
  void clear() {
    _snapshot = _emptySnapshot();
  }

  _DenylistSnapshot _copySnapshot() => _DenylistSnapshot(
    cidStrings: Set<String>.from(_snapshot.cidStrings),
    multihashHexes: Set<String>.from(_snapshot.multihashHexes),
    reasons: Map<String, String>.from(_snapshot.reasons),
    warnings: _snapshot.warnings,
    totalBytes: _snapshot.totalBytes,
  );

  static _DenylistSnapshot _emptySnapshot() => _DenylistSnapshot(
    cidStrings: const <String>{},
    multihashHexes: const <String>{},
    reasons: const <String, String>{},
    warnings: 0,
    totalBytes: 0,
  );

  Future<void> _tryLoadFromStorage() async {
    final path = _storagePath;
    if (path == null) return;

    try {
      final file = File(path);
      if (!await file.exists()) return;
      final bytes = await file.readAsBytes();
      _loadCompactBytes(bytes);
      _logger.warning(
        'Denylist loaded from persistent storage: '
        '${_snapshot.entryCount} entries',
      );
    } catch (e, st) {
      _logger.warning('Failed to load denylist from storage: $path', e, st);
    }
  }

  Future<void> _persistBytes(Uint8List bytes) async {
    final path = _storagePath;
    if (path == null) return;

    try {
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
    } catch (e, st) {
      _logger.warning('Failed to persist denylist to $path', e, st);
    }
  }

  bool _isUrl(String value) {
    final lower = value.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }
}
