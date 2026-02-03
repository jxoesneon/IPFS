// test/core/errors/error_instantiation_verified_test.dart
import 'package:dart_ipfs/src/core/errors/graphsync_errors.dart';
import 'package:dart_ipfs/src/core/errors/ipld_errors.dart';
import 'package:dart_ipfs/src/core/storage/datastore.dart';
import 'package:test/test.dart';

/// Simple verified tests for error class instantiation.
void main() {
  group('Error Instantiation - Verified Tests', () {
    group('IPLD Errors', () {
      test('IPLDEncodingError instantiates correctly', () {
        final error = IPLDEncodingError('encoding failed');
        expect(error, isA<IPLDError>());
        expect(error.message, contains('encoding'));
      });

      test('IPLDDecodingError instantiates correctly', () {
        final error = IPLDDecodingError('decoding failed');
        expect(error, isA<IPLDError>());
        expect(error.message, contains('decoding'));
      });

      test('IPLDResolutionError instantiates correctly', () {
        final error = IPLDResolutionError('resolution failed');
        expect(error, isA<IPLDError>());
        expect(error.message, contains('resolution'));
      });

      test('IPLDStorageError instantiates correctly', () {
        final error = IPLDStorageError('storage failed');
        expect(error, isA<IPLDError>());
        expect(error.message, contains('storage'));
      });

      test('IPLDValidationError instantiates correctly', () {
        final error = IPLDValidationError('validation failed');
        expect(error, isA<IPLDError>());
        expect(error.message, contains('validation'));
      });

      test('IPLDLinkError instantiates correctly', () {
        final error = IPLDLinkError('link error');
        expect(error, isA<IPLDError>());
        expect(error.message, contains('link'));
      });

      test('IPLDSchemaError instantiates correctly', () {
        final error = IPLDSchemaError('schema error');
        expect(error, isA<IPLDError>());
        expect(error.message, contains('schema'));
      });
    });

    group('Graphsync Errors', () {
      test('BlockNotFoundError instantiates correctly', () {
        final error = BlockNotFoundError('QmTest');
        expect(error, isA<GraphsyncError>());
        expect(error.message, contains('QmTest'));
      });

      test('BlockParseError instantiates correctly', () {
        final error = BlockParseError('parse failed');
        expect(error, isA<GraphsyncError>());
        expect(error.message, contains('parse'));
      });

      test('GraphTraversalError instantiates correctly', () {
        final error = GraphTraversalError('traversal failed');
        expect(error, isA<GraphsyncError>());
        expect(error.message, contains('traversal'));
      });

      test('MessageError instantiates correctly', () {
        final error = MessageError('message error');
        expect(error, isA<GraphsyncError>());
        expect(error.message, contains('message'));
      });

      test('RequestTimeoutError instantiates correctly', () {
        final error = RequestTimeoutError('req-123');
        expect(error, isA<GraphsyncError>());
        expect(error.message, contains('req-123'));
      });

      test('RequestHandlingError instantiates correctly', () {
        final error = RequestHandlingError('handling failed');
        expect(error, isA<GraphsyncError>());
        expect(error.message, contains('handling'));
      });
    });

    group('Datastore Error', () {
      test('DatastoreError instantiates correctly', () {
        final error = DatastoreError('operation failed');
        expect(error, isA<DatastoreError>());
        expect(error.message, equals('operation failed'));
      });
    });

    group('Error Properties', () {
      test('IPLD errors are Exceptions', () {
        final error = IPLDEncodingError('test');
        expect(error, isA<Exception>());
      });

      test('Graphsync errors are Exceptions', () {
        final error = BlockNotFoundError('test');
        expect(error, isA<Exception>());
      });

      test('errors have toString', () {
        final error = IPLDResolutionError('test');
        expect(error.toString(), isNotEmpty);
      });
    });
  });
}

