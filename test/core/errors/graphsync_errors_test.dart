import 'package:dart_ipfs/src/core/errors/graphsync_errors.dart';
import 'package:test/test.dart';

void main() {
  group('Graphsync Errors', () {
    test('BlockNotFoundError creates correct message', () {
      final error = BlockNotFoundError('QmXyz123');
      expect(error.message, equals('Block not found: QmXyz123'));
      expect(error.toString(), contains('Block not found'));
    });

    test('BlockParseError includes cause', () {
      final cause = Exception('Invalid format');
      final error = BlockParseError('Bad data', cause);
      expect(error.message, contains('Failed to parse block data'));
      expect(error.cause, equals(cause));
      expect(error.toString(), contains('Cause:'));
    });

    test('GraphTraversalError without cause', () {
      final error = GraphTraversalError('Path not found');
      expect(error.toString(), contains('Graph traversal error'));
      expect(error.toString(), isNot(contains('Cause:')));
    });

    test('MessageError with cause', () {
      final error = MessageError('Invalid packet', 'Bad header');
      expect(error.message, contains('Message error'));
      expect(error.cause, equals('Bad header'));
    });

    test('RequestTimeoutError creates correct message', () {
      final error = RequestTimeoutError('req-42');
      expect(error.message, contains('Request timed out: req-42'));
    });

    test('RequestHandlingError with cause', () {
      final error = RequestHandlingError(
        'Failed to process',
        Exception('Network'),
      );
      expect(error.message, contains('Failed to handle request'));
      expect(error.cause, isA<Exception>());
    });

    test('All errors are exceptions', () {
      expect(BlockNotFoundError('x'), isA<Exception>());
      expect(BlockParseError('x'), isA<Exception>());
      expect(GraphTraversalError('x'), isA<Exception>());
      expect(MessageError('x'), isA<Exception>());
      expect(RequestTimeoutError('x'), isA<Exception>());
      expect(RequestHandlingError('x'), isA<Exception>());
    });
  });
}
