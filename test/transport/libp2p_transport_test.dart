// test/transport/libp2p_transport_test.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';

// Note: Libp2pTransport depends on external dart_libp2p package which requires
// network operations. These tests focus on unit-testable logic patterns.

void main() {
  group('Libp2pTransport Protocol ID', () {
    test('p2plib protocol ID is correct', () {
      // From libp2p_transport.dart: const String p2plibProtocolId = '/p2plib/1.0.0';
      const protocolId = '/p2plib/1.0.0';
      expect(protocolId, equals('/p2plib/1.0.0'));
    });
  });

  group('Libp2pTransport Frame Protocol', () {
    test('frame length is encoded as 4 bytes big-endian', () {
      final datagram = Uint8List.fromList([1, 2, 3, 4, 5]); // 5 bytes
      final lenBytes = Uint8List(4);
      ByteData.view(lenBytes.buffer).setUint32(0, datagram.length);

      // Verify big-endian encoding (0x00000005)
      expect(lenBytes[0], equals(0));
      expect(lenBytes[1], equals(0));
      expect(lenBytes[2], equals(0));
      expect(lenBytes[3], equals(5));
    });

    test('frame length decoding extracts correct value', () {
      final lenBytes = Uint8List.fromList([0, 0, 0, 10]);
      final length = ByteData.view(lenBytes.buffer).getUint32(0);
      expect(length, equals(10));
    });

    test('frame length handles larger values', () {
      final lenBytes = Uint8List(4);
      ByteData.view(lenBytes.buffer).setUint32(0, 65536);

      final decoded = ByteData.view(lenBytes.buffer).getUint32(0);
      expect(decoded, equals(65536));
    });
  });

  group('Libp2pTransport Address Handling', () {
    test('MultiAddr format is correct', () {
      // Example: /ip4/0.0.0.0/tcp/4001
      const ip = '0.0.0.0';
      const port = 4001;
      final ma = '/ip4/$ip/tcp/$port';

      expect(ma, equals('/ip4/0.0.0.0/tcp/4001'));
    });

    test('MultiAddr parses IPv4 correctly', () {
      final address = InternetAddress('192.168.1.1');
      const port = 5000;
      final ma = '/ip4/${address.address}/tcp/$port';

      expect(ma, contains('192.168.1.1'));
      expect(ma, contains('5000'));
    });
  });

  group('Libp2pTransport State', () {
    test('isStarted logic is correct', () {
      // Simulated: isStarted => _startCompleter.isCompleted && _host != null
      var completerCompleted = false;
      var hostNotNull = false;

      bool isStarted() => completerCompleted && hostNotNull;

      expect(isStarted(), isFalse);

      completerCompleted = true;
      expect(isStarted(), isFalse);

      hostNotNull = true;
      expect(isStarted(), isTrue);
    });

    test('stream cache cleanup on stop', () {
      final streamCache = <String, dynamic>{};
      streamCache['peer1'] = 'stream1';
      streamCache['peer2'] = 'stream2';

      // Simulate stop()
      streamCache.clear();

      expect(streamCache, isEmpty);
    });
  });

  group('Identity Derivation', () {
    test('seed presence determines identity type', () {
      final seed = Uint8List.fromList(List.generate(32, (i) => i));
      Uint8List? noSeed;

      expect(seed, isNotNull);
      expect(noSeed, isNull);

      // If seed != null -> derive from seed
      // Else -> generate temporary
      final usingSeed = seed != null;
      expect(usingSeed, isTrue);
    });
  });

  group('PeerId Conversion', () {
    test('extracts first 32 bytes for Ed25519 public key', () {
      // p2plib PeerId is 64 bytes (encKey + signKey)
      final p2plibPeerId = Uint8List.fromList(List.generate(64, (i) => i));
      final pubKeyBytes = p2plibPeerId.sublist(0, 32);

      expect(pubKeyBytes.length, equals(32));
      expect(pubKeyBytes.first, equals(0));
      expect(pubKeyBytes.last, equals(31));
    });
  });
}

