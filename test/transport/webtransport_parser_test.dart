import 'package:test/test.dart';
import 'package:ipfs_libp2p/dart_libp2p.dart' as libp2p;
import 'package:dart_ipfs/src/transport/webtransport/multiaddr_parser.dart';

void main() {
  group('WebTransportMultiaddrParser', () {
    test('should parse valid WebTransport multiaddr', () {
      final addr = libp2p.MultiAddr(
          '/ip4/127.0.0.1/udp/4001/quic-v1/webtransport/certhash/uEiC_S8_XW-XhX_X_X_X_X_X_X_X_X_X_X_X_X_X_X_X');
      final info = WebTransportMultiaddrParser.parse(addr);

      expect(info, isNotNull);
      expect(info!.ip, equals('127.0.0.1'));
      expect(info.port, equals(4001));
      expect(info.certHashes, contains('uEiC_S8_XW-XhX_X_X_X_X_X_X_X_X_X_X_X_X_X_X_X'));
    });

    test('should parse multiaddr with multiple certhashes', () {
      final addr = libp2p.MultiAddr(
          '/ip4/127.0.0.1/udp/4001/quic-v1/webtransport/certhash/hash1/certhash/hash2');
      final info = WebTransportMultiaddrParser.parse(addr);

      expect(info, isNotNull);
      expect(info!.certHashes, hasLength(2));
      expect(info.certHashes, contains('hash1'));
      expect(info.certHashes, contains('hash2'));
    });

    test('should return null for non-WebTransport multiaddr', () {
      final addr = libp2p.MultiAddr('/ip4/127.0.0.1/tcp/4001');
      final info = WebTransportMultiaddrParser.parse(addr);

      expect(info, isNull);
    });
  });
}
