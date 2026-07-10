import 'package:ipfs_libp2p/p2p/transport/transport.dart' as libp2p_transport;

/// Web stub for QUIC transport probing.
///
/// QUIC is not available on the web, so this always returns `null` and the
/// caller falls back to TCP/WebRTC/WebTransport transports.
Future<libp2p_transport.Transport?> probeQuicTransport(
  libp2p_transport.Transport? Function()? factory,
) async => null;
