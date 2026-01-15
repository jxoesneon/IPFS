// src/core/ipfs_node/mdns_handler.dart
import 'dart:async';
import 'dart:io';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/peer.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/network/mdns_client.dart';
import 'package:dart_ipfs/src/utils/base58.dart';
import 'package:dart_ipfs/src/utils/logger.dart';

/// Handles mDNS (multicast DNS) peer discovery for an IPFS node.
class MDNSHandler {
  /// Creates an mDNS handler with config and optional mDNS client.
  MDNSHandler(this._config, {MDnsClient? mdnsClient}) {
    _logger = Logger(
      'MDNSHandler',
      debug: _config.debug,
      verbose: _config.verboseLogging,
    );
    _mdnsClient = mdnsClient ?? MDnsClient();
    _logger.debug('MDNSHandler instance created');
  }
  final IPFSConfig _config;
  late final Logger _logger;
  late final MDnsClient _mdnsClient;

  final String _serviceType = '_ipfs-discovery._udp';
  final Set<String> _discoveredPeers = {};
  final StreamController<Peer> _peerDiscoveryController =
      StreamController<Peer>.broadcast();

  bool _isRunning = false;
  Timer? _advertisementTimer;
  Timer? _discoveryTimer;

  /// Starts the mDNS discovery service
  Future<void> start() async {
    if (!_config.network.enableMDNS) {
      _logger.debug('MDNS disabled by configuration');
      return;
    }

    if (_isRunning) {
      _logger.warning('MDNSHandler already running');
      return;
    }

    try {
      _logger.debug('Starting MDNSHandler...');

      await _mdnsClient.start();
      _logger.verbose('MDNS client started');

      // Start the responder
      final port = _getPort();
      await _mdnsClient.startServer(
        serviceType: _serviceType,
        instanceName: _config.nodeId,
        port: port,
        txt: [_config.nodeId],
      );

      // Start periodic peer discovery
      _startDiscovery();

      // Start periodic service advertisement
      _startAdvertising();

      _isRunning = true;
      _logger.info('MDNSHandler started successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to start MDNSHandler', e, stackTrace);
      await stop();
      rethrow;
    }
  }

  /// Stops the mDNS discovery service
  Future<void> stop() async {
    if (!_isRunning) {
      _logger.warning('MDNSHandler already stopped');
      return;
    }

    try {
      _logger.debug('Stopping MDNSHandler...');

      _advertisementTimer?.cancel();
      _discoveryTimer?.cancel();

      await _mdnsClient.stop();

      _isRunning = false;
      _logger.info('MDNSHandler stopped successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to stop MDNSHandler', e, stackTrace);
      rethrow;
    }
  }

  void _startDiscovery() {
    _logger.verbose('Starting peer discovery');

    _discoveryTimer?.cancel();
    _discoveryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _discoverPeers();
    });

    // Initial discovery
    _discoverPeers();
  }

  void _startAdvertising() {
    _logger.verbose('Starting service advertisement');

    _advertisementTimer?.cancel();
    _advertisementTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _advertiseService();
    });

    // Initial advertisement
    _advertiseService();
  }

  // Helper to extract port
  int _getPort() {
    try {
      if (_config.network.listenAddresses.isEmpty) return 4001;
      final addr = _config.network.listenAddresses.first;
      // Example: /ip4/0.0.0.0/tcp/4001
      final parts = addr.split('/');
      if (parts.length >= 5) {
        return int.parse(parts[4]);
      }
    } catch (e) {
      _logger.warning('Failed to parse port from listen address: $e');
    }
    return 4001;
  }

  Future<void> _discoverPeers() async {
    try {
      _logger.verbose('Performing peer discovery');

      await for (final PtrResourceRecord ptr
          in _mdnsClient.lookup<PtrResourceRecord>(
            ResourceRecordQuery.serverPointer(_serviceType),
          )) {
        if (!_discoveredPeers.contains(ptr.domainName)) {
          _logger.debug('New peer discovered: ${ptr.domainName}');

          final peerInfo = await _resolvePeerInfo(ptr.domainName);
          if (peerInfo != null) {
            _discoveredPeers.add(ptr.domainName);
            _peerDiscoveryController.add(peerInfo);
          }
        }
      }
    } catch (e, stackTrace) {
      _logger.error('Error during peer discovery', e, stackTrace);
    }
  }

  Future<void> _advertiseService() async {
    try {
      _logger.verbose('Advertising IPFS service');

      final port = _getPort();
      await _mdnsClient.announce(_serviceType, _config.nodeId, port, [
        _config.nodeId,
      ]);

      _logger.debug('Service advertised successfully');
    } catch (e, stackTrace) {
      _logger.error('Error advertising service', e, stackTrace);
    }
  }

  Future<Peer?> _resolvePeerInfo(String domainName) async {
    try {
      _logger.verbose('Resolving peer info for: $domainName');

      final srv = await _mdnsClient
          .lookup<SrvResourceRecord>(ResourceRecordQuery.service(domainName))
          .first;

      final txt = await _mdnsClient
          .lookup<TxtResourceRecord>(ResourceRecordQuery.text(domainName))
          .first;

      if (txt.text.isEmpty) {
        _logger.warning('No TXT record found for peer: $domainName');
        return null;
      }

      // Resolve the .local hostname to an IP address
      final addresses = await InternetAddress.lookup(srv.target);
      if (addresses.isEmpty) {
        _logger.warning('Failed to resolve hostname: ${srv.target}');
        return null;
      }

      // Create a FullAddress from the resolved IP
      final address = FullAddress(address: addresses.first, port: srv.port);

      // Create a PeerId from the TXT record
      final peerId = PeerId(value: Base58().base58Decode(txt.text.first));

      return Peer(
        id: peerId,
        addresses: [address],
        latency: 0, // Default latency for new peers
        agentVersion: '', // Empty version since we don't know it yet
      );
    } on SocketException catch (e) {
      // Failed .local hostname lookups are expected on platforms without mDNS support
      // (Windows without Bonjour, Linux without avahi-daemon)
      _logger.verbose(
        'Could not resolve mDNS hostname: $domainName '
        '(OS Error: ${e.osError?.message ?? "Unknown"})',
      );
      return null;
    } catch (e) {
      // Unexpected errors might indicate real problems
      _logger.warning(
        'Unexpected error resolving peer info for $domainName: $e',
      );
      return null;
    }
  }

  /// Stream of discovered peers
  Stream<Peer> get peerDiscovery => _peerDiscoveryController.stream;

  /// Gets the current status of the mDNS handler
  Future<Map<String, dynamic>> getStatus() async {
    return {
      'running': _isRunning,
      'discovered_peers': _discoveredPeers.length,
      'service_type': _serviceType,
    };
  }
}
