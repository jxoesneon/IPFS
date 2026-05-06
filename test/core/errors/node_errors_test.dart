import 'package:dart_ipfs/src/core/errors/node_errors.dart';
import 'package:test/test.dart';

void main() {
  group('IPFSNode error hierarchy', () {
    test('IPFSNodeError exposes details and stringifies', () {
      final err = NodeInitializationError('boom', details: 'extra');
      expect(err.message, contains('boom'));
      expect(err.details, equals('extra'));
      expect(err.toString(), contains('IPFSNodeError'));
      expect(err.toString(), contains('boom'));
      expect(err.toString(), contains('extra'));
    });

    test('IPFSNodeError without details omits parenthetical', () {
      final err = NodeStartupError('failed');
      expect(err.toString(), equals('IPFSNodeError: failed'));
    });

    test('subclasses share the IPFSNodeError parent', () {
      expect(NodeShutdownError('x'), isA<IPFSNodeError>());
      expect(NodeStateError('x'), isA<IPFSNodeError>());
      expect(NodeInitializationError('x'), isA<IPFSNodeError>());
      expect(NodeStartupError('x'), isA<IPFSNodeError>());
    });

    test('ComponentError formats component name in toString', () {
      final err = ComponentError('Bitswap', 'failed');
      expect(err.component, equals('Bitswap'));
      expect(err.toString(), contains('ComponentError (Bitswap)'));
      final withDetails = ComponentError('DHT', 'failed', details: 1);
      expect(withDetails.toString(), contains('(1)'));
    });
  });
}
