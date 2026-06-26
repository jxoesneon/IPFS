// src/protocols/dht/reprovider.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/dht_config.dart';
import 'package:dart_ipfs/src/core/data_structures/pin_manager.dart';
import 'package:dart_ipfs/src/core/interfaces/i_lifecycle.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/mfs/mfs_manager.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_handler.dart';
import 'package:dart_ipfs/src/protocols/dht/interface_dht_handler.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:synchronized/synchronized.dart';

/// Result of a single reprovide run.
class ReproviderResult {
  /// Creates a new [ReproviderResult].
  ReproviderResult({
    required this.strategy,
    required this.attempted,
    required this.succeeded,
    required this.failed,
    required this.duration,
    this.errors = const [],
    this.groupedCids,
  });

  /// Strategy used for this run.
  final String strategy;

  /// Number of CIDs whose announcement was attempted.
  final int attempted;

  /// Number of CIDs whose announcement succeeded.
  final int succeeded;

  /// Number of CIDs whose announcement failed.
  final int failed;

  /// Duration of the reprovide run.
  final Duration duration;

  /// Human-readable error messages encountered during the run.
  final List<String> errors;

  /// CIDs grouped by target peer when sweep optimization is enabled.
  final Map<PeerId, List<CID>>? groupedCids;

  /// Converts this result to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'strategy': strategy,
        'attempted': attempted,
        'succeeded': succeeded,
        'failed': failed,
        'duration_ms': duration.inMilliseconds,
        'errors': errors,
        'groupedCids': groupedCids?.map(
          (peer, cids) =>
              MapEntry(peer.toBase58(), cids.map((c) => c.toString()).toList()),
        ),
      };
}

/// Status snapshot of the [Reprovider] service.
class ReproviderStatus {
  /// Creates a new [ReproviderStatus].
  ReproviderStatus({
    this.lastRun,
    this.lastResult,
    this.nextRun,
    required this.strategy,
    required this.running,
  });

  /// Timestamp of the last completed run.
  final DateTime? lastRun;

  /// Result of the last completed run.
  final ReproviderResult? lastResult;

  /// Scheduled timestamp of the next automatic run.
  final DateTime? nextRun;

  /// Currently configured strategy.
  final String strategy;

  /// Whether a reprovide run is currently in progress.
  final bool running;

  /// Converts this status to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'lastRun': lastRun?.toIso8601String(),
        'nextRun': nextRun?.toIso8601String(),
        'strategy': strategy,
        'running': running,
        'lastResult': lastResult?.toJson(),
      };
}

/// Periodic service that re-announces local content to the DHT.
///
/// Supports the strategies defined in `REPROVIDE_SPEC.md`: `pinned`, `roots`,
/// `all`, `pinned+mfs`, `unique`, and `entities`.
class Reprovider implements ILifecycle {
  /// Creates a new [Reprovider].
  Reprovider({
    required DHTConfig config,
    required IDHTHandler dhtHandler,
    required PinManager pinManager,
    required MFSManager mfsManager,
    MetricsCollector? metrics,
  })  : _config = config,
        _dhtHandler = dhtHandler,
        _pinManager = pinManager,
        _mfsManager = mfsManager,
        _metrics = metrics,
        _logger = Logger('Reprovider'),
        _strategy = config.reproviderStrategy;

  final DHTConfig _config;
  final IDHTHandler _dhtHandler;
  final PinManager _pinManager;
  final MFSManager _mfsManager;
  final MetricsCollector? _metrics;
  final Logger _logger;
  final _runLock = Lock();

  String _strategy;
  Timer? _timer;
  DateTime? _lastRun;
  DateTime? _nextRun;
  ReproviderResult? _lastResult;
  Future<ReproviderResult>? _currentRun;

  /// Supported reprovide strategy names.
  static const List<String> supportedStrategies = [
    'pinned',
    'roots',
    'all',
    'pinned+mfs',
    'unique',
    'entities',
  ];

  /// Starts the periodic reprovider timer.
  ///
  /// If the reprovider is disabled in configuration, no timer is scheduled.
  @override
  Future<void> start() async {
    if (!_config.reproviderEnabled) {
      _logger.info('Reprovider is disabled by configuration');
      return;
    }

    _logger.info(
      'Starting Reprovider: strategy=$_strategy, interval=${_config.reproviderInterval}',
    );
    _scheduleTimer();
  }

  /// Stops the periodic timer and waits for any in-flight run.
  @override
  Future<void> stop() async {
    _logger.info('Stopping Reprovider...');
    _timer?.cancel();
    _timer = null;
    _nextRun = null;

    final currentRun = _currentRun;
    if (currentRun != null) {
      try {
        await currentRun;
      } catch (e) {
        _logger.debug('In-flight reprovide run finished with error: $e');
      }
    }
  }

  /// Manually triggers a reprovide run.
  ///
  /// If [wait] is `true` and another run is already in progress, the call
  /// waits for that run to finish before starting a new one. Otherwise, a busy
  /// result is returned immediately.
  Future<ReproviderResult> trigger({bool wait = false}) async {
    _logger.debug('Manual reprovide triggered (wait=$wait)');

    final pendingRun = _currentRun;
    if (pendingRun != null) {
      if (wait) {
        _logger.debug('Waiting for in-flight reprovide run to complete');
        await pendingRun;
      } else {
        return _busyResult();
      }
    }

    return _runLock.synchronized(_run);
  }

  /// Returns the current status of the reprovider.
  ReproviderStatus getStatus() {
    return ReproviderStatus(
      lastRun: _lastRun,
      lastResult: _lastResult,
      nextRun: _nextRun,
      strategy: _strategy,
      running: _currentRun != null,
    );
  }

  /// Changes the active strategy after validating it.
  ///
  /// Throws an [ArgumentError] if [strategy] is not supported.
  void setStrategy(String strategy) {
    if (!supportedStrategies.contains(strategy)) {
      throw ArgumentError(
        'Unsupported reprovide strategy: $strategy. '
        'Supported strategies: $supportedStrategies',
      );
    }
    _strategy = strategy;
    _logger.info('Reprovider strategy changed to $strategy');
  }

  void _scheduleTimer() {
    _timer?.cancel();
    _nextRun = DateTime.now().add(_config.reproviderInterval);
    _timer = Timer.periodic(_config.reproviderInterval, (_) {
      _logger.debug('Periodic reprovide run triggered');
      unawaited(_runLock.synchronized(_run));
    });
  }

  Future<ReproviderResult> _run() async {
    _currentRun = _runInternal();
    try {
      return await _currentRun!;
    } finally {
      _currentRun = null;
    }
  }

  Future<ReproviderResult> _runInternal() async {
    _logger.info('Reprovide run started: strategy=$_strategy');
    final stopwatch = Stopwatch()..start();

    final errors = <String>[];
    Map<PeerId, List<CID>>? groupedCids;
    var attempted = 0;
    var succeeded = 0;
    var failed = 0;

    try {
      final cids = await _collectCids(_strategy);
      final deduped = _deduplicate(cids);
      _logger.debug(
          'Reproviding ${deduped.length} CIDs using strategy $_strategy');

      if (_config.reproviderSweepOptimization) {
        groupedCids = _groupByClosestPeers(deduped);
      }

      // Batch provides to avoid swamping the DHT client with single-CID calls.
      for (var i = 0; i < deduped.length; i += _config.reproviderBatchSize) {
        final batch = deduped.sublist(
          i,
          i + _config.reproviderBatchSize > deduped.length
              ? deduped.length
              : i + _config.reproviderBatchSize,
        );

        attempted += batch.length;
        try {
          await _dhtHandler.provideAll(batch);
          succeeded += batch.length;
          for (var n = 0; n < batch.length; n++) {
            _metrics?.recordDhtProvide(true);
          }
        } catch (e, st) {
          failed += batch.length;
          for (var n = 0; n < batch.length; n++) {
            _metrics?.recordDhtProvide(false);
          }
          final message = 'Failed to provide batch of ${batch.length} CIDs: $e';
          errors.add(message);
          _logger.error(message, e, st);
        }
      }
    } catch (e, st) {
      final message = 'Reprovide run failed: $e';
      errors.add(message);
      _logger.error(message, e, st);
    }

    stopwatch.stop();
    final duration = stopwatch.elapsed;
    final success = attempted == 0 || succeeded > 0;

    _metrics?.recordReprovide(_strategy, success, duration);
    _lastRun = DateTime.now();
    _lastResult = ReproviderResult(
      strategy: _strategy,
      attempted: attempted,
      succeeded: succeeded,
      failed: failed,
      duration: duration,
      errors: errors,
      groupedCids: groupedCids,
    );

    _logger.info(
      'Reprovide run completed: $succeeded/$attempted succeeded, '
      '${errors.length} errors in ${duration.inMilliseconds}ms',
    );
    return _lastResult!;
  }

  Future<List<CID>> _collectCids(String strategy) async {
    switch (strategy) {
      case 'pinned':
      case 'unique':
        return _recursivePinCids();
      case 'roots':
        return _rootPinCids();
      case 'all':
        return _allBlockCids();
      case 'pinned+mfs':
        return _recursivePinCids()..addAll(_mfsRootCids());
      case 'entities':
        return {..._rootPinCids(), ..._mfsRootCids()}.toList();
      default:
        throw ArgumentError('Unsupported reprovide strategy: $strategy');
    }
  }

  List<CID> _recursivePinCids() {
    return _pinManager
        .getRecursivePins()
        .map(_parseCid)
        .whereType<CID>()
        .toList();
  }

  List<CID> _rootPinCids() {
    return _pinManager
        .getRecursivePinRoots()
        .map(_parseCid)
        .whereType<CID>()
        .toList();
  }

  List<CID> _mfsRootCids() {
    if (!_mfsManager.isStarted) return [];
    try {
      return [_mfsManager.rootCid];
    } catch (e) {
      _logger.debug('MFS root not available for reprovide: $e');
      return [];
    }
  }

  Future<List<CID>> _allBlockCids() async {
    final blockStore = _pinManager.blockStore;
    final blocks = await blockStore.getAllBlocks();
    return blocks
        .map((block) => block.cid)
        .whereType<CID>()
        .toList();
  }

  CID? _parseCid(String cidStr) {
    try {
      return CID.decode(cidStr);
    } catch (e) {
      _logger.warning('Skipping invalid CID in pin set: $cidStr');
      return null;
    }
  }

  List<CID> _deduplicate(List<CID> cids) {
    return cids.toSet().toList();
  }

  Map<PeerId, List<CID>> _groupByClosestPeers(List<CID> cids) {
    if (_dhtHandler is! DHTHandler) {
      // Sweep optimization requires the concrete DHT client; fall back to
      // an empty grouping when an alternate handler is provided.
      return {};
    }
    final routingTable = _dhtHandler.dhtClient.kademliaRoutingTable;
    final localPeerId = _dhtHandler.dhtClient.peerId;
    final k = _config.bucketSize;

    // Sort by XOR distance from the local peer to improve routing locality.
    final sorted = List<CID>.from(cids);
    sorted.sort((a, b) {
      final keyA = _routingKey(a);
      final keyB = _routingKey(b);
      return _xorDistance(keyA, localPeerId)
          .compareTo(_xorDistance(keyB, localPeerId));
    });

    final grouped = <PeerId, List<CID>>{};
    for (final cid in sorted) {
      final target = _routingKey(cid);
      final closest = routingTable.findClosestPeers(target, k);
      for (final peer in closest) {
        grouped.putIfAbsent(peer, () => []).add(cid);
      }
    }

    return grouped;
  }

  PeerId _routingKey(CID cid) {
    final multihashBytes = cid.multihash.toBytes();
    final hashBytes = Uint8List.fromList(sha256.convert(multihashBytes).bytes);
    return PeerId(value: hashBytes);
  }

  BigInt _xorDistance(PeerId a, PeerId b) {
    final aBytes = a.value;
    final bBytes = b.value;
    final length =
        aBytes.length > bBytes.length ? aBytes.length : bBytes.length;
    var result = BigInt.zero;
    for (var i = 0; i < length; i++) {
      final aByte = i < aBytes.length ? aBytes[i] : 0;
      final bByte = i < bBytes.length ? bBytes[i] : 0;
      result = (result << 8) | BigInt.from(aByte ^ bByte);
    }
    return result;
  }

  ReproviderResult _busyResult() {
    return ReproviderResult(
      strategy: _strategy,
      attempted: 0,
      succeeded: 0,
      failed: 0,
      duration: Duration.zero,
      errors: ['Reprovider is already running'],
    );
  }
}
