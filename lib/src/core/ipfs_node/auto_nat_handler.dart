// src/core/ipfs_node/auto_nat_handler.dart
import 'dart:async';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';

/// Handles NAT detection and traversal for an IPFS node
class AutoNATHandler {
  final IPFSConfig _config;
  final NetworkHandler _networkHandler;
  late final Logger _logger;
  bool _isRunning = false;
  Timer? _dialbackTimer;

  // NAT status
  NATType _natType = NATType.unknown;
  bool _reachable = false;
  DateTime? _lastDialbackTest;

  static const Duration _dialbackInterval = Duration(minutes: 30);

  AutoNATHandler(this._config, this._networkHandler) {
    _logger = Logger('AutoNATHandler',
        debug: _config.debug, verbose: _config.verboseLogging);
    _logger.debug('AutoNATHandler instance created');
  }

  /// Starts the AutoNAT service
  Future<void> start() async {
    if (_isRunning) {
      _logger.warning('AutoNATHandler already running');
      return;
    }

    try {
      _logger.debug('Starting AutoNATHandler...');

      // Initial NAT detection
      await _detectNATType();

      // Start periodic dialback tests
      _startDialbackTests();

      _isRunning = true;
      _logger.info('AutoNATHandler started successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to start AutoNATHandler', e, stackTrace);
      rethrow;
    }
  }

  /// Stops the AutoNAT service
  Future<void> stop() async {
    if (!_isRunning) {
      _logger.warning('AutoNATHandler already stopped');
      return;
    }

    try {
      _logger.debug('Stopping AutoNATHandler...');

      _dialbackTimer?.cancel();
      _dialbackTimer = null;

      _isRunning = false;
      _logger.info('AutoNATHandler stopped successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to stop AutoNATHandler', e, stackTrace);
      rethrow;
    }
  }

  void _startDialbackTests() {
    _logger.verbose('Starting periodic dialback tests');

    _dialbackTimer?.cancel();
    _dialbackTimer = Timer.periodic(_dialbackInterval, (_) {
      _performDialbackTest();
    });

    // Initial test
    _performDialbackTest();
  }

  Future<void> _detectNATType() async {
    _logger.debug('Detecting NAT type...');

    try {
      // Try to establish direct connections
      final directConnectivity = await _checkDirectConnectivity();

      if (directConnectivity) {
        _natType = NATType.none;
        _reachable = true;
        _logger.debug('Node is directly reachable (no NAT)');
        return;
      }

      // Test for symmetric NAT
      final isSymmetric = await _testSymmetricNAT();
      _natType = isSymmetric ? NATType.symmetric : NATType.restricted;

      _logger.debug('NAT type detected: $_natType');
    } catch (e, stackTrace) {
      _logger.error('Error detecting NAT type', e, stackTrace);
      _natType = NATType.unknown;
    }
  }

  Future<bool> _checkDirectConnectivity() async {
    try {
      // Attempt direct connections to bootstrap nodes
      final bootstrapPeers = _config.network.bootstrapPeers;
      int successfulConnections = 0;

      for (final peer in bootstrapPeers) {
        if (await _networkHandler.canConnectDirectly(peer)) {
          successfulConnections++;
        }
      }

      return successfulConnections >= bootstrapPeers.length ~/ 2;
    } catch (e) {
      _logger.error('Error checking direct connectivity', e);
      return false;
    }
  }

  Future<bool> _testSymmetricNAT() async {
    try {
      // Test connections from different source ports
      final results = await Future.wait([
        _networkHandler.testConnection(sourcePort: 4001),
        _networkHandler.testConnection(sourcePort: 4002),
      ]);

      // If external ports are different, it's symmetric NAT
      return results[0] != results[1];
    } catch (e) {
      _logger.error('Error testing symmetric NAT', e);
      return false;
    }
  }

  Future<void> _performDialbackTest() async {
    _logger.verbose('Performing dialback test');

    try {
      final testResult = await _networkHandler.testDialback();
      _reachable = testResult;
      _lastDialbackTest = DateTime.now();

      _logger.debug('Dialback test complete. Reachable: $_reachable');
    } catch (e) {
      _logger.error('Error performing dialback test', e);
      _reachable = false;
    }
  }

  /// Gets the current status of the AutoNAT handler
  Future<Map<String, dynamic>> getStatus() async {
    return {
      'running': _isRunning,
      'nat_type': _natType.toString(),
      'reachable': _reachable,
      'last_dialback_test': _lastDialbackTest?.toIso8601String(),
      'dialback_interval': _dialbackInterval.inMinutes,
    };
  }
}

/// Represents different types of NAT configurations
enum NATType {
  unknown,
  none,
  restricted,
  symmetric,
}
