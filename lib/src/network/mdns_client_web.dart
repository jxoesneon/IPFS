import 'mdns_client.dart';

/// Creates an mDNS client for the Web platform.
///
/// Always throws [UnsupportedError]: mDNS requires UDP multicast sockets,
/// which browsers cannot open. LAN peer discovery on the web must go
/// through a signaling server, rendezvous endpoint, or a WebSocket relay
/// instead.
MDnsClient createMDnsClient({dynamic client, dynamic serverSocket}) =>
    throw UnsupportedError(
      'mDNS is not supported on the web platform: browsers cannot open '
      'UDP multicast sockets. Use a signaling server or relay for '
      'peer discovery instead.',
    );
