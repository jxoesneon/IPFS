import 'package:dart_ipfs/src/core/errors/ipld_errors.dart';
import 'package:test/test.dart';

void main() {
  group('IPLD Errors', () {
    test('IPLDEncodingError', () {
      final err = IPLDEncodingError('test');
      expect(err.toString(), contains('IPLD encoding error: test'));
      expect(err, isA<IPLDError>());
      expect(err, isA<Exception>());
    });

    test('IPLDDecodingError', () {
      final err = IPLDDecodingError('test');
      expect(err.toString(), contains('IPLD decoding error: test'));
    });

    test('IPLDResolutionError', () {
      final err = IPLDResolutionError('test');
      expect(err.toString(), contains('IPLD resolution error: test'));
    });

    test('IPLDStorageError', () {
      final err = IPLDStorageError('test');
      expect(err.toString(), contains('IPLD storage error: test'));
    });

    test('IPLDValidationError', () {
      final err = IPLDValidationError('test');
      expect(err.toString(), contains('IPLD validation error: test'));
    });

    test('IPLDLinkError', () {
      final err = IPLDLinkError('test');
      expect(err.toString(), contains('IPLD link error: test'));
    });

    test('IPLDSchemaError', () {
      final err = IPLDSchemaError('test');
      expect(err.toString(), contains('IPLD schema error: test'));
    });
  });
}
