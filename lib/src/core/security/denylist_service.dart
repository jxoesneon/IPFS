// lib/src/core/security/denylist_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:dart_multihash/dart_multihash.dart';
import 'package:http/http.dart' as http;
import 'package:multibase/multibase.dart';

import '../../utils/logger.dart';
import '../cid.dart';
import '../config/security_config.dart';
import '../interfaces/i_lifecycle.dart';
import '../metrics/metrics_collector.dart';

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

/// A single ordered, path-scoped denylist rule.
///
/// Rules are stored per anchor (multihash or IPNS name) in list order and
/// evaluated newest-first so that `!` negated rules appearing later in the
/// denylist take precedence, per the compact denylist format spec.
class _PathRule {
  const _PathRule({
    required this.path,
    required this.isPrefix,
    required this.negated,
  });

  /// Normalized path: no leading or trailing `/` and no trailing `*`.
  /// An empty path addresses the anchor itself (CID or IPNS name).
  final String path;

  /// Whether this is a `PATH*` prefix rule.
  final bool isPrefix;

  /// Whether this is a `!` (allow) rule that negates earlier deny rules.
  final bool negated;

  /// Whether the rule matches [requestPath] (normalized like [path]).
  bool matches(String requestPath) {
    return isPrefix ? requestPath.startsWith(path) : requestPath == path;
  }
}

/// Immutable snapshot of a loaded denylist used for O(1) lookups.
class _DenylistSnapshot {
  _DenylistSnapshot({
    required this.cidStrings,
    required this.multihashHexes,
    required this.hashedMultihashes,
    required this.legacyHashHexes,
    required this.ipfsPathRules,
    required this.ipnsNameRules,
    required this.ipnsNames,
    required this.reasons,
    required this.warnings,
    required this.totalBytes,
  });

  final Set<String> cidStrings;
  final Set<String> multihashHexes;

  /// Modern `//` double-hash entries: hex-encoded multihash bytes of
  /// `hash(preimage)` where the preimage is e.g. `b58Multihash/PATH`.
  final Set<String> hashedMultihashes;

  /// Legacy `//` double-hash entries: lowercase sha256 hex digests of
  /// `CIDV1_BASE32/PATH` BadBits anchor strings.
  final Set<String> legacyHashHexes;

  /// Ordered path rules for `/ipfs/CID/PATH` items, keyed by multihash hex.
  final Map<String, List<_PathRule>> ipfsPathRules;

  /// Ordered path/name rules for `/ipns/NAME/PATH` items, keyed by the IPNS
  /// name (lowercased for non-CID names, verbatim for CID names).
  final Map<String, List<_PathRule>> ipnsNameRules;

  /// Blocked non-CID IPNS names (DNSLink domains, etc.), lowercased.
  final Set<String> ipnsNames;

  final Map<String, String> reasons;
  final int warnings;
  final int totalBytes;

  bool get isEmpty => entryCount == 0;

  int get entryCount =>
      cidStrings.length +
      multihashHexes.length +
      hashedMultihashes.length +
      legacyHashHexes.length +
      ipnsNames.length +
      ipfsPathRules.values.fold<int>(0, (sum, rules) => sum + rules.length) +
      ipnsNameRules.values.fold<int>(0, (sum, rules) => sum + rules.length);

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

  _DenylistSnapshot _snapshot = _emptySnapshot();

  final List<DenylistAuditEvent> _auditLog = [];
  Timer? _refreshTimer;
  DateTime? _lastRefresh;
  int _refreshErrors = 0;
  bool _started = false;

  static const int _maxLineLength = 4096;
  static const int _maxEntries = 1000000;
  static const int _maxBytes = 256 * 1024 * 1024;
  static const int _maxAuditLogSize = 10000;

  /// Maximum size of the optional YAML list header per the compact denylist
  /// format spec (1 MiB).
  static const int _maxHeaderBytes = 1024 * 1024;

  /// Multihash code for sha2-256, the only hash function supported for
  /// computing modern `//` double-hash request preimages.
  static const int _sha256Code = 0x12;

  /// Matches legacy `//` double-hash entries (sha256 hex digests).
  static final RegExp _legacyHashPattern = RegExp(r'^[0-9a-fA-F]{64}$');

  /// Extracts a `version` field from the optional YAML list header.
  static final RegExp _versionPattern = RegExp(r'^version\s*:\s*(\S+)\s*$');

  /// Matches a YAML-style `key:` or `key: value` header line. The colon must
  /// be followed by whitespace or end-of-line so that block items containing
  /// colons (e.g. `ipfs://CID`) are not mistaken for header fields.
  static final RegExp _yamlFieldPattern = RegExp(
    r'^[A-Za-z_][\w.-]*\s*:(\s|$)',
  );

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
    final hashedMultihashes = <String>{};
    final legacyHashHexes = <String>{};
    final ipfsPathRules = <String, List<_PathRule>>{};
    final ipnsNameRules = <String, List<_PathRule>>{};
    final ipnsNames = <String>{};
    final reasons = <String, String>{};
    var warnings = 0;

    for (final rawLine in _itemLines(text)) {
      if (rawLine.length > _maxLineLength) {
        warnings++;
        continue;
      }

      var line = rawLine.trim();
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

      var negated = false;
      if (line.startsWith('!')) {
        negated = true;
        line = line.substring(1).trim();
        if (line.isEmpty) continue;
      }

      // Block items may carry trailing space-separated hints
      // (`item key:value ...`). Hints are optional metadata; unsupported
      // hints are ignored per the compact denylist format spec.
      var item = line.split(RegExp(r'\s+')).first;

      // `//` lines are double-hash block items (modern multihash form or
      // legacy sha256-hex BadBits anchors), not comments.
      if (item.startsWith('//')) {
        warnings += _applyDoubleHashItem(
          item.substring(2).trim(),
          negated,
          hashedMultihashes,
          legacyHashHexes,
        );
        continue;
      }

      // Normalize URI forms (`ipfs://CID/path`, `ipns://NAME/path`).
      final lowerItem = item.toLowerCase();
      if (lowerItem.startsWith('ipfs://')) {
        item = '/ipfs/${item.substring('ipfs://'.length)}';
      } else if (lowerItem.startsWith('ipns://')) {
        item = '/ipns/${item.substring('ipns://'.length)}';
      }

      final normalized = item.startsWith('/') ? item : '/$item';
      final normalizedLower = normalized.toLowerCase();
      if (normalizedLower.startsWith('/ipfs/')) {
        warnings += _applyIpfsItem(
          normalized.substring('/ipfs/'.length),
          negated,
          cidStrings,
          multihashHexes,
          hashedMultihashes,
          legacyHashHexes,
          ipfsPathRules,
        );
        continue;
      }
      if (normalizedLower.startsWith('/ipns/')) {
        warnings += _applyIpnsItem(
          normalized.substring('/ipns/'.length),
          negated,
          cidStrings,
          multihashHexes,
          hashedMultihashes,
          legacyHashHexes,
          ipnsNameRules,
          ipnsNames,
        );
        continue;
      }

      // Plain entries: multihash strings first so that bare multihash
      // entries (e.g. compact base32 strings) are not misidentified as
      // CIDv0 strings; then CID strings (any version/codec).
      final multihash = _tryDecodeMultihash(item);
      if (multihash != null) {
        final hexStr = _multihashHex(multihash);
        if (negated) {
          multihashHexes.remove(hexStr);
          _appendRule(
            ipfsPathRules,
            hexStr,
            const _PathRule(path: '', isPrefix: false, negated: true),
          );
        } else {
          multihashHexes.add(hexStr);
        }
        continue;
      }

      final cid = _tryDecodeCid(item);
      if (cid != null) {
        _applyCidLevelRule(
          cid,
          negated,
          cidStrings,
          multihashHexes,
          hashedMultihashes,
          legacyHashHexes,
        );
        if (negated) {
          _appendRule(
            ipfsPathRules,
            _multihashHex(cid.multihash),
            const _PathRule(path: '', isPrefix: false, negated: true),
          );
        }
        continue;
      }

      warnings++;
    }

    return _ParseResult(
      snapshot: _DenylistSnapshot(
        cidStrings: cidStrings,
        multihashHexes: multihashHexes,
        hashedMultihashes: hashedMultihashes,
        legacyHashHexes: legacyHashHexes,
        ipfsPathRules: ipfsPathRules,
        ipnsNameRules: ipnsNameRules,
        ipnsNames: ipnsNames,
        reasons: reasons,
        warnings: warnings,
        totalBytes: totalBytes,
      ),
      warnings: warnings,
    );
  }

  /// Splits [text] into block-item lines, skipping an optional YAML header
  /// terminated by a `---` line.
  ///
  /// Per the compact denylist format spec the header is only recognized when
  /// a `---` delimiter appears within the first [_maxHeaderBytes] and every
  /// preceding line looks like YAML content (empty, comment, or `key:`).
  /// Otherwise the whole file is parsed as block items. A `version` field
  /// other than `1` is rejected.
  List<String> _itemLines(String text) {
    final lines = const LineSplitter().convert(text);
    var bytes = 0;
    var headerEnd = -1;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trim() == '---') {
        headerEnd = i;
        break;
      }
      bytes += lines[i].length + 1;
      if (bytes > _maxHeaderBytes) break;
    }
    if (headerEnd < 0) return lines;

    final header = lines.sublist(0, headerEnd);
    final looksLikeYaml = header.every((line) {
      final t = line.trim();
      return t.isEmpty ||
          t.startsWith('#') ||
          line.startsWith(' ') ||
          line.startsWith('\t') ||
          _yamlFieldPattern.hasMatch(t);
    });
    if (!looksLikeYaml) return lines;

    for (final line in header) {
      final match = _versionPattern.firstMatch(line.trim());
      if (match != null && int.tryParse(match.group(1)!) != 1) {
        throw FormatException(
          'Unsupported denylist version: ${match.group(1)}',
        );
      }
    }
    return lines.sublist(headerEnd + 1);
  }

  /// Parses the `CID/PATH` portion of an `/ipfs/` block item and records it.
  ///
  /// Returns the number of parse warnings produced.
  int _applyIpfsItem(
    String rest,
    bool negated,
    Set<String> cidStrings,
    Set<String> multihashHexes,
    Set<String> hashedMultihashes,
    Set<String> legacyHashHexes,
    Map<String, List<_PathRule>> ipfsPathRules,
  ) {
    final segments = rest.split('/');
    final cidStr = segments.first;
    if (cidStr.isEmpty) return 1;
    final cid = _tryDecodeCid(cidStr);
    if (cid == null) return 1;

    var subPath = segments.sublist(1).join('/');
    while (subPath.endsWith('/')) {
      subPath = subPath.substring(0, subPath.length - 1);
    }
    var isPrefix = false;
    if (subPath.endsWith('*')) {
      isPrefix = true;
      subPath = subPath.substring(0, subPath.length - 1);
      while (subPath.endsWith('/')) {
        subPath = subPath.substring(0, subPath.length - 1);
      }
    }

    if (subPath.isEmpty && !isPrefix) {
      _applyCidLevelRule(
        cid,
        negated,
        cidStrings,
        multihashHexes,
        hashedMultihashes,
        legacyHashHexes,
      );
    }
    // `/ipfs/CID/*` blocks the CID itself too, but only through the ordered
    // rule (which also matches the empty path) so that later `!` exceptions
    // can still allow specific paths.
    _appendRule(
      ipfsPathRules,
      _multihashHex(cid.multihash),
      _PathRule(path: subPath, isPrefix: isPrefix, negated: negated),
    );
    return 0;
  }

  /// Parses the `NAME/PATH` portion of an `/ipns/` block item and records it.
  ///
  /// If NAME is a CID, name-level rules block the underlying multihash (which
  /// also covers `/ipfs/` requests for the same multihash). Non-CID names
  /// (DNSLink domains) are stored lowercased.
  ///
  /// Returns the number of parse warnings produced.
  int _applyIpnsItem(
    String rest,
    bool negated,
    Set<String> cidStrings,
    Set<String> multihashHexes,
    Set<String> hashedMultihashes,
    Set<String> legacyHashHexes,
    Map<String, List<_PathRule>> ipnsNameRules,
    Set<String> ipnsNames,
  ) {
    final segments = rest.split('/');
    final name = segments.first;
    if (name.isEmpty) return 1;

    var subPath = segments.sublist(1).join('/');
    while (subPath.endsWith('/')) {
      subPath = subPath.substring(0, subPath.length - 1);
    }
    var isPrefix = false;
    if (subPath.endsWith('*')) {
      isPrefix = true;
      subPath = subPath.substring(0, subPath.length - 1);
      while (subPath.endsWith('/')) {
        subPath = subPath.substring(0, subPath.length - 1);
      }
    }

    final cid = _tryDecodeCid(name);
    final key = cid != null ? name : name.toLowerCase();
    if (subPath.isEmpty && !isPrefix) {
      if (cid != null) {
        _applyCidLevelRule(
          cid,
          negated,
          cidStrings,
          multihashHexes,
          hashedMultihashes,
          legacyHashHexes,
        );
      } else if (negated) {
        ipnsNames.remove(key);
        _removeHashedNameEntries(name, hashedMultihashes, legacyHashHexes);
      } else {
        ipnsNames.add(key);
      }
    }
    // `/ipns/NAME/*` blocks the name itself too, but only through the
    // ordered rule so that later `!` exceptions can still allow paths.
    _appendRule(
      ipnsNameRules,
      key,
      _PathRule(path: subPath, isPrefix: isPrefix, negated: negated),
    );
    return 0;
  }

  /// Applies or removes a CID-level block (the `/ipfs/CID` rule form).
  void _applyCidLevelRule(
    CID cid,
    bool negated,
    Set<String> cidStrings,
    Set<String> multihashHexes,
    Set<String> hashedMultihashes,
    Set<String> legacyHashHexes,
  ) {
    final multihashHex = _multihashHex(cid.multihash);
    if (negated) {
      cidStrings.remove(cid.encode());
      multihashHexes.remove(multihashHex);
      _removeHashedCidEntries(cid, hashedMultihashes, legacyHashHexes);
    } else {
      cidStrings.add(cid.encode());
      multihashHexes.add(multihashHex);
    }
  }

  /// Records a `//DOUBLE-HASH` block item.
  ///
  /// A 64-character hex value is a legacy sha256 anchor; per the spec it is
  /// also recorded as a modern multihash rule when it happens to decode as
  /// one. Other values must decode as a multibase/bare-base58btc multihash.
  /// Only sha2-256 double-hashes can be matched at request time; entries
  /// using other hash functions are stored but counted as warnings.
  ///
  /// Returns the number of parse warnings produced.
  int _applyDoubleHashItem(
    String value,
    bool negated,
    Set<String> hashedMultihashes,
    Set<String> legacyHashHexes,
  ) {
    if (value.isEmpty) return 1;
    var recognized = false;
    var warnings = 0;

    if (_legacyHashPattern.hasMatch(value)) {
      final key = value.toLowerCase();
      if (negated) {
        legacyHashHexes.remove(key);
      } else {
        legacyHashHexes.add(key);
      }
      recognized = true;
    }

    final multihash = _tryDecodeMultihash(value);
    if (multihash != null) {
      final key = _multihashHex(multihash);
      if (negated) {
        hashedMultihashes.remove(key);
      } else {
        hashedMultihashes.add(key);
      }
      if (multihash.code != _sha256Code) {
        // Only sha2-256 request preimages are computed, so this entry can
        // never match; surface it as a warning.
        warnings++;
      }
      recognized = true;
    }

    return recognized ? warnings : 1;
  }

  void _appendRule(
    Map<String, List<_PathRule>> rules,
    String key,
    _PathRule rule,
  ) {
    rules.putIfAbsent(key, () => <_PathRule>[]).add(rule);
  }

  /// Removes the modern and legacy double-hash entries a CID would produce,
  /// so `!/ipfs/CID` unblocks content regardless of how it was listed.
  void _removeHashedCidEntries(
    CID cid,
    Set<String> hashedMultihashes,
    Set<String> legacyHashHexes,
  ) {
    hashedMultihashes.remove(
      hex.encode(_sha256MultihashBytes(_b58Multihash(cid.multihash))),
    );
    final cidV1Base32 = _tryCidV1Base32(cid);
    if (cidV1Base32 != null) {
      legacyHashHexes.remove(_sha256Hex('$cidV1Base32/'));
    }
  }

  /// Removes the double-hash entries an IPNS name would produce.
  void _removeHashedNameEntries(
    String name,
    Set<String> hashedMultihashes,
    Set<String> legacyHashHexes,
  ) {
    for (final candidate in {name, name.toLowerCase()}) {
      hashedMultihashes.remove(
        hex.encode(_sha256MultihashBytes('/ipns/$candidate')),
      );
      legacyHashHexes.remove(_sha256Hex('$candidate/'));
    }
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

  /// Decodes a multihash string, accepting multibase-prefixed forms
  /// (`b…`, `z…`) and bare base58btc strings (`Qm…`-style, as used for
  /// multihashes and `//` double-hash items in compact denylists).
  MultihashInfo? _tryDecodeMultihash(String line) {
    try {
      return Multihash.decode(multibaseDecode(line));
    } catch (_) {
      // Not multibase-prefixed; try bare base58btc.
    }
    try {
      return Multihash.decode(multibaseDecode('z$line'));
    } catch (_) {
      return null;
    }
  }

  /// Returns the base58btc-encoded multihash (no multibase prefix), which is
  /// the modern double-hash preimage form and also the CIDv0 string form.
  String _b58Multihash(MultihashInfo multihash) {
    final encoded = multibaseEncode(Multibase.base58btc, multihash.toBytes());
    return encoded.substring(1); // strip the 'z' multibase prefix
  }

  /// Returns the CIDv1 base32 (lowercase) string form of [cid], preserving
  /// the codec, or `null` when the CID cannot be represented as CIDv1.
  String? _tryCidV1Base32(CID cid) {
    try {
      if (cid.version == 1) {
        return cid.encodeWithBase(Multibase.base32);
      }
      return CID
          .v1(cid.codec ?? 'dag-pb', cid.multihash)
          .encodeWithBase(Multibase.base32);
    } catch (_) {
      return null;
    }
  }

  /// Returns `sha2-256` of [preimage] wrapped as a multihash (`0x12 0x20 ||
  /// digest`), matching modern `//` double-hash denylist entries.
  Uint8List _sha256MultihashBytes(String preimage) {
    return Uint8List.fromList([
      _sha256Code,
      0x20,
      ...sha256.convert(utf8.encode(preimage)).bytes,
    ]);
  }

  /// Returns the lowercase hex sha256 digest of [preimage], matching legacy
  /// `//` double-hash denylist entries.
  String _sha256Hex(String preimage) {
    return sha256.convert(utf8.encode(preimage)).toString();
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
  ///
  /// Matching is codec- and version-agnostic (CIDv0 and CIDv1 share the
  /// multihash) and also covers `//` double-hash entries and `/ipfs/CID/*`
  /// prefix rules, which block the CID itself.
  bool isBlocked(CID cid) {
    if (!_config.enableDenylist) return false;
    final multihashHex = _multihashHex(cid.multihash);
    if (_snapshot.multihashHexes.contains(multihashHex) ||
        _snapshot.cidStrings.contains(cid.encode())) {
      return true;
    }
    // Path rules that match the empty path (e.g. `/ipfs/CID/*`) also block
    // the CID itself.
    if (_evalPathRules(_snapshot.ipfsPathRules[multihashHex], '') == true) {
      return true;
    }
    return _matchesHashedCid(cid, '');
  }

  /// Returns `true` if the CID string is blocked.
  bool isBlockedByCidString(String cidStr) {
    if (!_config.enableDenylist) return false;
    try {
      final cid = CID.decode(cidStr);
      if (isBlocked(cid)) {
        return true;
      }
    } catch (_) {
      // Fall through to the literal check below.
    }
    return _snapshot.cidStrings.contains(cidStr);
  }

  /// Returns `true` if the multihash string is blocked.
  bool isBlockedByMultihash(String multihash) {
    if (!_config.enableDenylist) return false;
    final mh = _tryDecodeMultihash(multihash);
    if (mh != null) {
      final hexStr = _multihashHex(mh);
      if (_snapshot.multihashHexes.contains(hexStr)) {
        return true;
      }
      if (_snapshot.hashedMultihashes.isNotEmpty &&
          _snapshot.hashedMultihashes.contains(
            hex.encode(_sha256MultihashBytes(_b58Multihash(mh))),
          )) {
        return true;
      }
      if (_evalPathRules(_snapshot.ipfsPathRules[hexStr], '') == true) {
        return true;
      }
    }
    return _snapshot.cidStrings.contains(multihash);
  }

  /// Returns `true` if the path contains a blocked CID or IPNS name.
  ///
  /// Accepts `/ipfs/…`, `/ipns/…`, `ipfs://…` and `ipns://…` forms and
  /// evaluates path-scoped rules (`/ipfs/CID/PATH`, `PATH*` prefixes, `!`
  /// negations) as well as double-hash entries.
  bool isBlockedPath(String path) {
    if (!_config.enableDenylist) return false;
    var normalized = path.trim();
    final lower = normalized.toLowerCase();
    if (lower.startsWith('ipfs://')) {
      normalized = '/ipfs/${normalized.substring('ipfs://'.length)}';
    } else if (lower.startsWith('ipns://')) {
      normalized = '/ipns/${normalized.substring('ipns://'.length)}';
    }

    final segments = normalized.split('/').where((s) => s.isNotEmpty).toList();
    for (var i = 0; i + 1 < segments.length; i++) {
      final namespace = segments[i].toLowerCase();
      if (namespace != 'ipfs' && namespace != 'ipns') continue;
      final value = segments[i + 1];
      var subPath = segments.sublist(i + 2).join('/');
      // Unreachable: segments contain no '/' and are non-empty, so the
      // joined sub-path can never end with '/'. Kept defensively.
      // coverage:ignore-start
      while (subPath.endsWith('/')) {
        subPath = subPath.substring(0, subPath.length - 1);
      }
      // coverage:ignore-end
      final blocked = namespace == 'ipfs'
          ? _isBlockedIpfsItem(value, subPath)
          : _isBlockedIpnsItem(value, subPath);
      if (blocked) return true;
    }
    return false;
  }

  /// Evaluates whether an `/ipfs/CID[/PATH]` item is blocked.
  bool _isBlockedIpfsItem(String cidStr, String subPath) {
    final cid = _tryDecodeCid(cidStr);
    if (cid == null) {
      return _snapshot.cidStrings.contains(cidStr);
    }
    final multihashHex = _multihashHex(cid.multihash);
    if (_evalPathRules(_snapshot.ipfsPathRules[multihashHex], subPath) ==
        true) {
      return true;
    }
    return _cidLevelBlocked(cid, multihashHex, subPath);
  }

  /// Evaluates whether an `/ipns/NAME[/PATH]` item is blocked.
  bool _isBlockedIpnsItem(String name, String subPath) {
    // Ordered name rules are evaluated newest-first; a matching deny rule
    // blocks immediately.
    var verdict = _evalPathRules(_snapshot.ipnsNameRules[name], subPath);
    final lowerName = name.toLowerCase();
    if (verdict == null && lowerName != name) {
      verdict = _evalPathRules(_snapshot.ipnsNameRules[lowerName], subPath);
    }
    if (verdict == true) return true;

    if (_snapshot.ipnsNames.contains(name) ||
        _snapshot.ipnsNames.contains(lowerName) ||
        _snapshot.cidStrings.contains(name)) {
      return true;
    }

    // CID names block the underlying multihash; domain names are matched
    // against double-hash entries.
    final cid = _tryDecodeCid(name);
    if (cid != null) {
      return _cidLevelBlocked(cid, _multihashHex(cid.multihash), subPath);
    }
    return _matchesHashedIpnsName(name, subPath);
  }

  /// CID-level (BlockService) check: literal CID/multihash entries and
  /// `//` double-hash entries for the given CID and optional [path].
  bool _cidLevelBlocked(CID cid, String multihashHex, String path) {
    if (_snapshot.multihashHexes.contains(multihashHex) ||
        _snapshot.cidStrings.contains(cid.encode())) {
      return true;
    }
    return _matchesHashedCid(cid, path);
  }

  /// Evaluates ordered path rules newest-first.
  ///
  /// Returns `true` when a deny rule matches, `false` when an allow (`!`)
  /// rule matches, and `null` when no rule applies. An allow verdict does
  /// not exempt the item from CID-level checks: callers still evaluate
  /// CID-level blocking, matching the layering in the compact denylist spec
  /// where a blocked root cannot be retrieved even through an allowed path.
  bool? _evalPathRules(List<_PathRule>? rules, String path) {
    if (rules == null) return null;
    for (var i = rules.length - 1; i >= 0; i--) {
      if (rules[i].matches(path)) {
        return !rules[i].negated;
      }
    }
    return null;
  }

  /// Whether [cid] (with optional [path]) matches a `//` double-hash entry.
  ///
  /// Modern preimages hash `b58Multihash` and `b58Multihash/PATH`; legacy
  /// BadBits anchors hash `CIDV1_BASE32/` and `CIDV1_BASE32/PATH` with
  /// sha256 hex encoding.
  bool _matchesHashedCid(CID cid, String path) {
    final snapshot = _snapshot;
    if (snapshot.hashedMultihashes.isEmpty &&
        snapshot.legacyHashHexes.isEmpty) {
      return false;
    }

    if (snapshot.hashedMultihashes.isNotEmpty) {
      final b58 = _b58Multihash(cid.multihash);
      for (final preimage in [b58, if (path.isNotEmpty) '$b58/$path']) {
        if (snapshot.hashedMultihashes.contains(
          hex.encode(_sha256MultihashBytes(preimage)),
        )) {
          return true;
        }
      }
    }

    if (snapshot.legacyHashHexes.isNotEmpty) {
      final cidV1Base32 = _tryCidV1Base32(cid);
      if (cidV1Base32 != null) {
        for (final preimage in [
          '$cidV1Base32/',
          if (path.isNotEmpty) '$cidV1Base32/$path',
        ]) {
          if (snapshot.legacyHashHexes.contains(_sha256Hex(preimage))) {
            return true;
          }
        }
      }
    }
    return false;
  }

  /// Whether a non-CID IPNS [name] (with optional [path]) matches a `//`
  /// double-hash entry.
  ///
  /// Modern preimages hash `/ipns/NAME` and `/ipns/NAME/PATH`; legacy
  /// DNSLink anchors hash `NAME/` and `NAME/PATH`.
  bool _matchesHashedIpnsName(String name, String path) {
    final snapshot = _snapshot;
    if (snapshot.hashedMultihashes.isEmpty &&
        snapshot.legacyHashHexes.isEmpty) {
      return false;
    }
    final names = {name, name.toLowerCase()};
    for (final candidate in names) {
      if (snapshot.hashedMultihashes.isNotEmpty) {
        for (final preimage in [
          '/ipns/$candidate',
          if (path.isNotEmpty) '/ipns/$candidate/$path',
        ]) {
          if (snapshot.hashedMultihashes.contains(
            hex.encode(_sha256MultihashBytes(preimage)),
          )) {
            return true;
          }
        }
      }
      if (snapshot.legacyHashHexes.isNotEmpty) {
        for (final preimage in [
          '$candidate/',
          if (path.isNotEmpty) '$candidate/$path',
        ]) {
          if (snapshot.legacyHashHexes.contains(_sha256Hex(preimage))) {
            return true;
          }
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
      _logger.info(
        'Denylist hit (logged): $cidOrMultihash via $source'
        '${resolvedReason != null ? ' — $resolvedReason' : ''}',
      );
    } else {
      _metrics.recordSecurityEvent('denylist_blocked');
      _logger.warning(
        'Denylist hit (blocked): $cidOrMultihash via $source'
        '${resolvedReason != null ? ' — $resolvedReason' : ''}',
      );
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
  ///
  /// Also drops path rules and computed double-hash entries anchored at the
  /// CID's multihash, so the CID is fully unblocked.
  void unblock(CID cid) {
    final snapshot = _copySnapshot();
    snapshot.cidStrings.remove(cid.encode());
    final multihashHex = _multihashHex(cid.multihash);
    snapshot.multihashHexes.remove(multihashHex);
    snapshot.ipfsPathRules.remove(multihashHex);
    _removeHashedCidEntries(
      cid,
      snapshot.hashedMultihashes,
      snapshot.legacyHashHexes,
    );
    _snapshot = snapshot;
  }

  /// Removes a CID string from the in-memory denylist.
  void unblockCidString(String cidStr) {
    final snapshot = _copySnapshot();
    snapshot.cidStrings.remove(cidStr);
    snapshot.ipnsNames.remove(cidStr);
    snapshot.ipnsNames.remove(cidStr.toLowerCase());
    try {
      final cid = CID.decode(cidStr);
      final multihashHex = _multihashHex(cid.multihash);
      snapshot.multihashHexes.remove(multihashHex);
      snapshot.ipfsPathRules.remove(multihashHex);
      _removeHashedCidEntries(
        cid,
        snapshot.hashedMultihashes,
        snapshot.legacyHashHexes,
      );
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
    hashedMultihashes: Set<String>.from(_snapshot.hashedMultihashes),
    legacyHashHexes: Set<String>.from(_snapshot.legacyHashHexes),
    ipfsPathRules: _copyRules(_snapshot.ipfsPathRules),
    ipnsNameRules: _copyRules(_snapshot.ipnsNameRules),
    ipnsNames: Set<String>.from(_snapshot.ipnsNames),
    reasons: Map<String, String>.from(_snapshot.reasons),
    warnings: _snapshot.warnings,
    totalBytes: _snapshot.totalBytes,
  );

  static Map<String, List<_PathRule>> _copyRules(
    Map<String, List<_PathRule>> rules,
  ) {
    return rules.map((key, value) => MapEntry(key, List.of(value)));
  }

  static _DenylistSnapshot _emptySnapshot() => _DenylistSnapshot(
    cidStrings: const <String>{},
    multihashHexes: const <String>{},
    hashedMultihashes: const <String>{},
    legacyHashHexes: const <String>{},
    ipfsPathRules: const <String, List<_PathRule>>{},
    ipnsNameRules: const <String, List<_PathRule>>{},
    ipnsNames: const <String>{},
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
