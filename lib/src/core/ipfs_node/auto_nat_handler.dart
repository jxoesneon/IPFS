// src/core/ipfs_node/auto_nat_handler.dart
import 'dart:async';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/network/nat_traversal_service.dart';
import 'package:dart_ipfs/src/utils/logger.dart';

/// Handles NAT detection and traversal for an IPFS node.
class AutoNATHandler {
  /// Creates an AutoNATHandler with the given config and network handler.
  AutoNATHandler(
    this._config,
    this._networkHandler, {
    NatTraversalService? natService,
  }) : _natService = natService ?? NatTraversalService() {
    _logger = Logger(
      'AutoNATHandler',
      debug: _config.debug,
      verbose: _config.verboseLogging,
    );
    _logger.debug('AutoNATHandler instance created');
  }
  final IPFSConfig _config;
  final NetworkHandler _networkHandler;
  final NatTraversalService _natService;
  late final Logger _logger;
  bool _isRunning = false;
  Timer? _dialbackTimer;

  // NAT status
  NATType _natType = NATType.unknown;
  bool _reachable = false;
  DateTime? _lastDialbackTest;
  int? _mappedPort;

  static const Duration _dialbackInterval = Duration(minutes: 30);

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

      // Attempt port mapping if behind NAT and enabled
      if (_natType != NATType.none && _config.network.enableNatTraversal) {
        await _attemptPortMapping();
      } else if (_natType != NATType.none) {
        _logger.info('NAT detected but port mapping is disabled in config');
      }

      // Start periodic dialback tests and perform initial test
      await _startDialbackTests();

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

      // Clean up port mappings
      if (_mappedPort != null) {
        await _natService.unmapPort(_mappedPort!);
      } else {
        // Fallback or legacy default
        await _natService.unmapPort(4001);
      }

      _isRunning = false;
      _logger.info('AutoNATHandler stopped successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to stop AutoNATHandler', e, stackTrace);
      rethrow;
    }
  }

  Future<void> _startDialbackTests() async {
    _logger.verbose('Starting periodic dialback tests');

    _dialbackTimer?.cancel();
    _dialbackTimer = Timer.periodic(_dialbackInterval, (_) {
      _performDialbackTest();
    });

    // Initial test - only if not already performed by port mapping
    if (_lastDialbackTest == null ||
        DateTime.now().difference(_lastDialbackTest!) >
            const Duration(seconds: 5)) {
      await _performDialbackTest();
    }
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
      // Note: checkDialback already tests reachability.
      // Accurate symmetric NAT detection requires binding multiple ports which RouterInterface doesn't expose yet.
      // Defaulting to restricted for now if not directly reachable.
      _natType = NATType.restricted;

      _logger.debug('NAT type detected: $_natType');
    } catch (e, stackTrace) {
      _logger.error('Error detecting NAT type', e, stackTrace);
      _natType = NATType.unknown;
    }
  }

  Future<bool> _checkDirectConnectivity() async {
    // Attempt direct connections to bootstrap nodes
    final bootstrapPeers = _config.network.bootstrapPeers;
    int successfulConnections = 0;

    for (final peer in bootstrapPeers) {
      if (await _networkHandler.canConnectDirectly(peer)) {
        successfulConnections++;
      }
    }

    if (bootstrapPeers.isEmpty) return false;
    return successfulConnections >= (bootstrapPeers.length + 1) ~/ 2;
  }

  // Symmetric NAT test removed as NetworkHandler.testConnection is deprecated.
  // Future<bool> _testSymmetricNAT() async { ... }

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

  Future<void> _attemptPortMapping() async {
    _logger.debug('Attempting UPnP/NAT-PMP port mapping...');

    // Extract port from listen addresses
    int? port;
    for (final addr in _config.network.listenAddresses) {
      if (addr.contains('/tcp/') || addr.contains('/udp/')) {
        final parts = addr.split('/');
        // Format: /ip4/0.0.0.0/tcp/4001
        for (var i = 0; i < parts.length - 1; i++) {
          if (parts[i] == 'tcp' || parts[i] == 'udp') {
            port = int.tryParse(parts[i + 1]);
            if (port != null) break;
          }
        }
      }
      if (port != null) break;
    }

    if (port == null) {
      _logger.warning(
        'Could not determine listening port from config, skipping port mapping',
      );
      return;
    }

    _logger.debug('Identified listening port: $port');

    // Store for unmapping
    _mappedPort = port;

    final mapped = await _natService.mapPort(port);
    if (mapped.isNotEmpty) {
      _logger.info(
        'Port mapping successful for protocols: ${mapped.join(", ")}',
      );
      // Re-check reachability after mapping
      await _performDialbackTest();
    } else {
      _logger.debug('Port mapping failed or no gateway found');
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

/// Represents different types of NAT configurations.
enum NATType {
  /// NAT type not yet determined.
  unknown,

  /// No NAT (directly reachable).
  none,

  /// Port-restricted or address-restricted NAT.
  restricted,

  /// Symmetric NAT (hardest to traverse).
  symmetric,
}
