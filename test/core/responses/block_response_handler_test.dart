import 'package:test/test.dart';
import 'package:dart_ipfs/src/core/responses/block_response_handler.dart';
import 'package:dart_ipfs/src/proto/generated/core/block.pb.dart';

void main() {
  group('BlockResponseHandler', () {
    test('success and failure', () {
      final s = BlockResponseHandler.success('OK');
      expect(s.success, isTrue);
      final f = BlockResponseHandler.failure('Fail');
      expect(f.success, isFalse);
    });

    test('found and notFound', () {
      final block = BlockProto()..data = [1];
      final found = BlockResponseHandler.found(block);
      expect(found.found, isTrue);
      final nf = BlockResponseHandler.notFound();
      expect(nf.found, isFalse);
    });

    test('removed and notRemoved', () {
      final r = BlockResponseHandler.removed('OK');
      expect(r.success, isTrue);
      final nr = BlockResponseHandler.notRemoved('Fail');
      expect(nr.success, isFalse);
    });
  });
}
