import 'dart:typed_data';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/proto/generated/core/cid.pb.dart';
import 'package:dart_ipfs/src/utils/encoding.dart';
import 'package:test/test.dart';

void main() {
  group('EncodingUtils', () {
    test('toBase58 and fromBase58 roundtrip', () {
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final encoded = EncodingUtils.toBase58(data);
      expect(encoded.startsWith('z'), isTrue);
      
      final decoded = EncodingUtils.fromBase58(encoded);
      expect(decoded, equals(data));
    });

    test('fromBase58 empty string throws', () {
      expect(() => EncodingUtils.fromBase58(''), throwsArgumentError);
    });

    test('fromBase58 invalid prefix throws', () {
      expect(() => EncodingUtils.fromBase58('!123'), throwsArgumentError);
    });

    test('fromBase58 unsupported encoding throws', () {
      // 'f' is base16 (supported prefix but not implemented in fromBase58)
      expect(() => EncodingUtils.fromBase58('f123'), throwsUnsupportedError);
    });

    test('isValidCIDBytes - CIDv0', () {
      // CIDv0: 0x12 0x20 + 32 bytes SHA2-256
      final bytes = Uint8List(34);
      bytes[0] = 0x12;
      bytes[1] = 0x20;
      expect(EncodingUtils.isValidCIDBytes(bytes), isTrue);
      
      // Invalid length
      expect(EncodingUtils.isValidCIDBytes(Uint8List(33)), isFalse);
    });

    test('isValidCIDBytes - CIDv1', () async {
      final cid = CID.computeForDataSync(Uint8List(32), codec: 'dag-pb');
      final bytes = cid.toBytes();
      expect(EncodingUtils.isValidCIDBytes(bytes), isTrue);
    });

    test('isValidCIDBytes - invalid bytes', () {
      expect(EncodingUtils.isValidCIDBytes(Uint8List(0)), isFalse);
      expect(EncodingUtils.isValidCIDBytes(Uint8List.fromList([0x02, 0x01])), isFalse);
    });

    test('indexToCidVersion', () {
      expect(EncodingUtils.indexToCidVersion(0), equals(IPFSCIDVersion.IPFS_CID_VERSION_UNSPECIFIED));
      expect(EncodingUtils.indexToCidVersion(1), equals(IPFSCIDVersion.IPFS_CID_VERSION_0));
      expect(EncodingUtils.indexToCidVersion(2), equals(IPFSCIDVersion.IPFS_CID_VERSION_1));
      expect(() => EncodingUtils.indexToCidVersion(3), throwsUnsupportedError);
    });

    test('isValidMultibasePrefix', () {
      expect(EncodingUtils.isValidMultibasePrefix('z'), isTrue);
      expect(EncodingUtils.isValidMultibasePrefix('f'), isTrue);
      expect(EncodingUtils.isValidMultibasePrefix('!'), isFalse);
    });

    test('getEncodingFromPrefix', () {
      expect(EncodingUtils.getEncodingFromPrefix('z'), equals('base58btc'));
      expect(EncodingUtils.getEncodingFromPrefix('f'), equals('base16'));
      expect(EncodingUtils.getEncodingFromPrefix('!'), isEmpty);
    });

    test('codec conversion', () {
      expect(EncodingUtils.getCodeFromCodec('raw'), equals(0x55));
      expect(EncodingUtils.getCodecFromCode(0x70), equals('dag-pb'));
      
      expect(() => EncodingUtils.getCodeFromCodec('unknown'), throwsArgumentError);
      expect(() => EncodingUtils.getCodecFromCode(0xFFFF), throwsArgumentError);
    });

    test('supportedCodecs list', () {
      final codecs = EncodingUtils.supportedCodecs;
      expect(codecs, contains('raw'));
      expect(codecs, contains('dag-pb'));
    });

    test('cidToBytes', () async {
      final cid = CID.computeForDataSync(Uint8List(32), codec: 'raw');
      final bytes = EncodingUtils.cidToBytes(cid);
      expect(bytes, equals(cid.toBytes()));
    });
  });
}
