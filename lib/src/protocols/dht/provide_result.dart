// src/protocols/dht/provide_result.dart
import 'dart:async';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';

/// Result of an on-demand provider announcement.
///
/// Returned by `DHTHandler.provideDetailed` and
/// `DHTClient.addProviderDetailed` so callers (e.g. the
/// `/api/v0/dht/provide` RPC endpoint) can report real success/failure
/// feedback instead of a bare `{ "Success": true }`.
class ProvideResult {
  /// Creates a new [ProvideResult].
  ProvideResult({
    required this.cid,
    required this.attempts,
    required this.successes,
    required this.failures,
    required this.duration,
    this.errors = const [],
    this.cidsAnnounced = 1,
  });

  /// The root CID the announcement was requested for.
  final CID cid;

  /// Number of peer announcements attempted.
  final int attempts;

  /// Number of peer announcements that succeeded.
  final int successes;

  /// Number of peer announcements that failed.
  final int failures;

  /// Wall-clock duration of the provide operation.
  final Duration duration;

  /// Human-readable error strings (capped at [maxErrors] entries).
  final List<String> errors;

  /// Number of distinct CIDs announced. Greater than 1 for recursive
  /// provides that walked a DAG.
  final int cidsAnnounced;

  /// Maximum number of error strings retained in [errors].
  static const int maxErrors = 20;

  /// Whether the operation completed without failures.
  ///
  /// A run that found no peers to contact ([attempts] == 0) is a
  /// successful no-op: the provider record is still stored locally.
  bool get success => failures == 0;

  /// Converts this result to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'cid': cid.toString(),
    'attempts': attempts,
    'successes': successes,
    'failures': failures,
    'duration_ms': duration.inMilliseconds,
    'errors': errors,
    'cidsAnnounced': cidsAnnounced,
  };
}

/// A queued on-demand provide job.
///
/// Enqueued via `DHTHandler.enqueueProvide` and drained by the handler's
/// internal queue processor. The [result] future completes with the
/// [ProvideResult] once the job runs.
class PendingProvide {
  /// Creates a new [PendingProvide] job.
  PendingProvide({
    required this.cid,
    this.recursive = false,
    this.timeout,
    this.blockStore,
    this.recordMetrics = true,
  }) {
    // Queued jobs are fire-and-forget for the enqueueing RPC request; mark
    // the result future as observed so a failed job never surfaces as an
    // unhandled async error. Callers awaiting [result] still see the error.
    _completer.future.ignore();
  }

  /// CID to announce.
  final CID cid;

  /// Whether to announce the whole DAG reachable from [cid].
  final bool recursive;

  /// Optional deadline for the job's peer announcements.
  final Duration? timeout;

  /// Blockstore used for DAG enumeration when [recursive] is true.
  final BlockStore? blockStore;

  /// Whether the job should record provide metrics.
  final bool recordMetrics;

  /// Completes with the [ProvideResult] when the job finishes.
  Future<ProvideResult> get result => _completer.future;

  final Completer<ProvideResult> _completer = Completer<ProvideResult>();

  /// Completes [result] with [value].
  void complete(ProvideResult value) => _completer.complete(value);

  /// Completes [result] with an error.
  void completeError(Object error, [StackTrace? stackTrace]) =>
      _completer.completeError(error, stackTrace);
}
