// example/main.dart
import 'package:dart_ipfs_quic/dart_ipfs_quic.dart';
import 'package:ipfs_libp2p/core/multiaddr.dart';

void main() async {
  print('--- dart_ipfs_quic Example ---');

  // 1. Initialize the pure-Dart QUIC transport
  final transport = QuicTransport();
  print('Supported Protocols: ${transport.protocols.join(', ')}');

  // 2. Validate multiaddr dial and listen capabilities
  final quicAddr = MultiAddr('/ip4/127.0.0.1/udp/4001/quic-v1');
  final tcpAddr = MultiAddr('/ip4/127.0.0.1/tcp/4001');

  print('Can listen on $quicAddr: ${transport.canListen(quicAddr)}');
  print('Can listen on $tcpAddr: ${transport.canListen(tcpAddr)}');

  // 3. Verification complete
  print('QUIC transport initialized and verified successfully.');
  print('--- Example Complete ---');
}
