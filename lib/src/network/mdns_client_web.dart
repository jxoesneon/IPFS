import 'mdns_client.dart';

/// Creates an mDNS client for the Web platform (throws UnsupportedError).
MDnsClient createMDnsClient({dynamic client, dynamic serverSocket}) =>
    throw UnsupportedError('mDNS not supported on web');
