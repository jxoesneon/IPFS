// test/core/cid/multicodec_expanded_test.dart
import 'package:dart_ipfs_core/dart_ipfs_core.dart';
import 'package:test/test.dart';

void main() {
  group('Multicodec expanded registry', () {
    test('has at least 50 codecs', () {
      expect(Multicodec.count, greaterThanOrEqualTo(50));
    });

    test('supports all IPLD codecs', () {
      final ipldCodecs = [
        'raw',
        'dag-pb',
        'dag-cbor',
        'libp2p-key',
        'git-raw',
        'dag-jose',
        'dag-cose',
        'dag-json',
        'eth-block',
        'eth-tx',
        'bitcoin-block',
        'bitcoin-tx',
        'zcash-block',
        'zcash-tx',
      ];
      for (final name in ipldCodecs) {
        expect(Multicodec.supports(name), isTrue, reason: 'Missing: $name');
      }
    });

    test('supports all multihash codecs', () {
      final hashCodecs = [
        'identity',
        'sha1',
        'sha2-256',
        'sha2-512',
        'sha3-512',
        'sha3-384',
        'sha3-256',
        'sha3-224',
        'shake-128',
        'shake-256',
        'keccak-224',
        'keccak-256',
        'keccak-384',
        'keccak-512',
        'blake3',
        'sha2-384',
        'murmur3-x64-64',
        'murmur3-32',
        'dbl-sha2-256',
        'md4',
        'md5',
      ];
      for (final name in hashCodecs) {
        expect(Multicodec.supports(name), isTrue, reason: 'Missing: $name');
      }
    });

    test('supports multiaddr codecs', () {
      final multiaddrCodecs = [
        'ip4',
        'tcp',
        'udp',
        'ip6',
        'dns',
        'dns4',
        'dns6',
        'dnsaddr',
        'p2p-circuit',
        'quic',
        'quic-v1',
        'http',
      ];
      for (final name in multiaddrCodecs) {
        expect(Multicodec.supports(name), isTrue, reason: 'Missing: $name');
      }
    });

    test('supports key type codecs', () {
      final keyCodecs = [
        'ed25519-pub',
        'secp256k1-pub',
        'x25519-pub',
        'sr25519-pub',
        'aes-128',
        'aes-256',
      ];
      for (final name in keyCodecs) {
        expect(Multicodec.supports(name), isTrue, reason: 'Missing: $name');
      }
    });

    test('supports namespace codecs', () {
      final nsCodecs = [
        'ipfs-ns',
        'ipns-ns',
        'ipld-ns',
        'dnslink',
        'ipfs',
        'ipns',
      ];
      for (final name in nsCodecs) {
        expect(Multicodec.supports(name), isTrue, reason: 'Missing: $name');
      }
    });

    test('code() returns correct codes for known codecs', () {
      expect(Multicodec.code('identity'), equals(0x00));
      expect(Multicodec.code('raw'), equals(0x55));
      expect(Multicodec.code('dag-pb'), equals(0x70));
      expect(Multicodec.code('dag-cbor'), equals(0x71));
      expect(Multicodec.code('dag-json'), equals(0x0129));
      expect(Multicodec.code('sha2-256'), equals(0x12));
      expect(Multicodec.code('murmur3-x64-64'), equals(0x22));
      expect(Multicodec.code('ed25519-pub'), equals(0xed));
      expect(Multicodec.code('p2p-circuit'), equals(0x0122));
      expect(Multicodec.code('quic-v1'), equals(0x01cd));
    });

    test('name() returns correct names for known codes', () {
      expect(Multicodec.name(0x00), equals('identity'));
      expect(Multicodec.name(0x55), equals('raw'));
      expect(Multicodec.name(0x70), equals('dag-pb'));
      expect(Multicodec.name(0x71), equals('dag-cbor'));
      expect(Multicodec.name(0x12), equals('sha2-256'));
      expect(Multicodec.name(0xed), equals('ed25519-pub'));
    });

    test('code() throws for unknown codec', () {
      expect(() => Multicodec.code('nonexistent'), throwsArgumentError);
    });

    test('name() throws for unknown code', () {
      expect(() => Multicodec.name(0xFFFF), throwsArgumentError);
    });

    test('supportsByCode() returns true for known codes', () {
      expect(Multicodec.supportsByCode(0x71), isTrue);
      expect(Multicodec.supportsByCode(0x55), isTrue);
      expect(Multicodec.supportsByCode(0xFFFF), isFalse);
    });

    test('supported returns unmodifiable list', () {
      final list = Multicodec.supported;
      expect(() => list.add('test'), throwsUnsupportedError);
    });

    test('round-trip: code -> name -> code is stable', () {
      for (final name in Multicodec.supported) {
        final code = Multicodec.code(name);
        expect(
          Multicodec.name(code),
          equals(name),
          reason: 'Round-trip failed for $name',
        );
      }
    });
  });
}
