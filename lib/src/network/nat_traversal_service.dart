import 'dart:async';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:port_forwarder/port_forwarder.dart';

/// Manages NAT traversal and port forwarding operations.
class NatTraversalService {
  /// Creates a new NatTraversalService.
  NatTraversalService({Logger? logger, Gateway? gateway})
    : _logger = logger ?? Logger('NatTraversalService'),
      _gateway = gateway;

  final Logger _logger;
  Gateway? _gateway;

  /// Attempts to map the specified [port] for both TCP and UDP.
  ///
  /// Returns a list of successfully mapped protocols.
  Future<List<String>> mapPort(int port, {Duration? leaseDuration}) async {
    _logger.info('Attempting to map port $port via UPnP/NAT-PMP...');
    final mappedProtocols = <String>[];

    try {
      // Discover gateway if not already found
      if (_gateway == null) {
        _logger.debug('Discovering gateway...');
        _gateway = await Gateway.discover();
      }

      final gateway = _gateway;
      if (gateway == null) {
        _logger.warning('No UPnP/NAT-PMP gateway discovered');
        return [];
      }

      // Note: IP not directly available on Gateway abstract class always, but we can try
      // _logger.debug('Discovered gateway: ${gateway.externalAddress}');

      // Try TCP
      try {
        await gateway.openPort(
          externalPort: port,
          internalPort: port,
          protocol: PortType.tcp,
          leaseDuration: leaseDuration?.inSeconds ?? 0,
        );
        mappedProtocols.add('TCP');
        _logger.info('Successfully mapped TCP port $port');
      } catch (e) {
        _logger.warning('Failed to map TCP port $port', e);
      }

      // Try UDP
      try {
        await gateway.openPort(
          externalPort: port,
          internalPort: port,
          protocol: PortType.udp,
          leaseDuration: leaseDuration?.inSeconds ?? 0,
        );
        mappedProtocols.add('UDP');
        _logger.info('Successfully mapped UDP port $port');
      } catch (e) {
        _logger.warning('Failed to map UDP port $port', e);
      }
    } catch (e) {
      _logger.error('Error during port mapping', e);
    }

    return mappedProtocols;
  }

  /// Removes port mappings for the specified [port].
  Future<void> unmapPort(int port) async {
    _logger.info('Removing port mappings for port $port...');

    final gateway = _gateway;
    if (gateway == null) return;

    try {
      // Best effort removal for both protocols
      await gateway.closePort(externalPort: port, protocol: PortType.tcp);
      await gateway.closePort(externalPort: port, protocol: PortType.udp);
    } catch (e) {
      _logger.warning('Error removing port mappings', e);
    }
  }
}
