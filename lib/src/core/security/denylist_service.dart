// lib/src/core/security/denylist_service.dart
import 'dart:convert';
import 'dart:io';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/utils/logger.dart';

/// Service that maintains a list of blocked CIDs for content filtering.
///
/// When enabled, the gateway consults this service before serving trustless
/// (and optionally path-gateway) responses. Blocked content must return
/// HTTP 451 Unavailable For Legal Reasons.
///
/// The service keeps an in-memory set of blocked CIDs. If a configuration
/// path is provided, it attempts to load one CID per line from that file.
/// Lines starting with `#` and empty lines are ignored.
class DenylistService {
  /// Creates a denylist service.
  ///
  /// [configPath] is an optional path to a UTF-8 text file containing one
  /// blocked CID per line. If the file does not exist or cannot be read, the
  /// denylist remains empty and the failure is logged.
  DenylistService({String? configPath}) : _configPath = configPath {
    _loadFromConfig();
  }

  final String? _configPath;
  final Set<String> _blockedCids = {};
  final Logger _logger = Logger('DenylistService');

  /// Returns whether the denylist contains any entries.
  bool get isEnabled => _blockedCids.isNotEmpty;

  /// Returns the number of blocked CIDs.
  int get length => _blockedCids.length;

  /// Adds a single CID to the denylist.
  void block(CID cid) => _blockedCids.add(cid.encode());

  /// Adds a CID string to the denylist.
  void blockCidString(String cidStr) => _blockedCids.add(cidStr);

  /// Removes a CID from the denylist.
  void unblock(CID cid) => _blockedCids.remove(cid.encode());

  /// Clears all blocked CIDs.
  void clear() => _blockedCids.clear();

  /// Returns `true` if the CID is blocked.
  bool isBlocked(CID cid) => _blockedCids.contains(cid.encode());

  /// Returns `true` if the CID string is blocked.
  bool isBlockedByCidString(String cidStr) => _blockedCids.contains(cidStr);

  /// Returns `true` if the path contains a CID or IPNS name that is blocked.
  ///
  /// This checks both `/ipfs/<cid>` and `/ipns/<name>` segments. For IPNS,
  /// the name is matched literally against the denylist.
  bool isBlockedPath(String path) {
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    for (var i = 0; i < segments.length - 1; i++) {
      final namespace = segments[i];
      final value = segments[i + 1];
      if (namespace == 'ipfs' || namespace == 'ipns') {
        if (_blockedCids.contains(value)) {
          return true;
        }
      }
    }
    return false;
  }

  void _loadFromConfig() {
    final path = _configPath;
    if (path == null) return;

    try {
      final file = File(path);
      if (!file.existsSync()) {
        _logger.info('Denylist config path does not exist: $path');
        return;
      }

      final lines = file
          .readAsStringSync(encoding: utf8)
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty && !line.startsWith('#'))
          .toList();
      _blockedCids.addAll(lines);
      _logger.info('Loaded ${_blockedCids.length} blocked CID(s) from $path');
    } catch (e, stackTrace) {
      _logger.warning('Failed to load denylist from $path', e, stackTrace);
    }
  }
}
