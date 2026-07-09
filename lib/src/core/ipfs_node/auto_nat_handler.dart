// src/core/ipfs_node/auto_nat_handler.dart
import 'dart:async';

import '../../network/nat_traversal_service.dart';
import '../../protocols/autonat/autonat_protocol.dart';
import '../../utils/logger.dart';
import '../config/ipfs_config.dart';
import '../interfaces/i_lifecycle.dart';
import 'network_handler.dart';

/// Handles NAT detection and traversal for an IPFS node.
///
/// This handler uses the spec-compliant AutoNAT protocol to determine
/// the node's NAT status by asking peers to dial back. It also attempts
/// port mapping if needed to ensure reachability.
class AutoNATHandler implements ILifecycle {
  /// Creates an AutoNATHandler with the given config and network handler.
  ///
  /// @param _config The IPFS configuration.
  /// @param _networkHandler The network handler.
  /// @param natService Optional NAT traversal service.
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

  // AutoNAT service and server
  AutoNATService? _autonatService;
  AutoNATServer? _autonatServer;

  // NAT status
  NATType _natType = NATType.unknown;
  bool _reachable = false;
  DateTime? _lastDialbackTest;
  int? _mappedPort;

  static const Duration _dialbackInterval = Duration(minutes: 30);

  /// Starts the AutoNAT service
  @override
  Future<void> start() async {
    if (_isRunning) {
      _logger.warning('AutoNATHandler already running');
      return;
    }

    try {
      _logger.debug('Starting AutoNATHandler...');

      // Initialize AutoNAT service and server
      final router = _networkHandler.router;
      _autonatService = AutoNATService(router, _config);
      _autonatServer = AutoNATServer(router, _config);

      // Start the AutoNAT server to handle incoming dialback requests
      _autonatServer!.start();

      // Initial NAT detection using spec-compliant protocol
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
  @override
  Future<void> stop() async {
    if (!_isRunning) {
      _logger.warning('AutoNATHandler already stopped');
      return;
    }

    try {
      _logger.debug('Stopping AutoNATHandler...');

      _dialbackTimer?.cancel();
      _dialbackTimer = null;

      // Stop AutoNAT server
      _autonatServer?.stop();
      _autonatServer = null;
      _autonatService = null;

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
    _logger.debug('Detecting NAT type using AutoNAT protocol...');

    try {
      // Use spec-compliant AutoNAT protocol to determine NAT status
      if (_autonatService == null) {
        _logger.warning('AutoNAT service not initialized, using fallback');
        await _fallbackDetectNATType();
        return;
      }

      // Update observed addresses from our listening addresses
      final observedAddrs = _networkHandler.router.listeningAddresses;
      _autonatService!.updateObservedAddrs(observedAddrs);

      // Try to perform dialback with a connected peer
      final connectedPeers = _networkHandler.router.listConnectedPeers();
      if (connectedPeers.isEmpty) {
        _logger.debug('No connected peers for AutoNAT, using fallback');
        await _fallbackDetectNATType();
        return;
      }

      // Try with the first connected peer
      final peerId = connectedPeers.first;
      final natStatus = await _autonatService!.performDialback(peerId);

      // Map AutoNAT NATStatus to our NATType
      switch (natStatus) {
        case NATStatus.public:
          _natType = NATType.none;
          _reachable = true;
          _logger.debug('Node is publicly reachable (no NAT)');
          break;
        case NATStatus.private:
          _natType = NATType.restricted;
          _reachable = false;
          _logger.debug('Node is behind NAT');
          break;
        case NATStatus.unknown:
          _logger.debug('NAT status unknown, using fallback');
          await _fallbackDetectNATType();
          break;
      }
    } catch (e, stackTrace) {
      _logger.error('Error detecting NAT type with AutoNAT', e, stackTrace);
      await _fallbackDetectNATType();
    }
  }

  /// Fallback NAT detection when AutoNAT is not available.
  Future<void> _fallbackDetectNATType() async {
    _logger.debug('Using fallback NAT detection...');

    try {
      // Try to establish direct connections
      final directConnectivity = await _checkDirectConnectivity();

      if (directConnectivity) {
        _natType = NATType.none;
        _reachable = true;
        _logger.debug('Node is directly reachable (no NAT)');
        return;
      }

      // Default to restricted if not directly reachable
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
