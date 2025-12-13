import 'dart:typed_data';
import 'package:dart_ipfs/src/protocols/graphsync/graphsync_protocol.dart';
import 'package:dart_ipfs/src/protocols/graphsync/graphsync_types.dart';
import 'package:dart_ipfs/src/proto/generated/graphsync/graphsync.pb.dart';
import 'package:test/test.dart';

void main() {
  group('GraphsyncProtocol', () {
    late GraphsyncProtocol protocol;

    setUp(() {
      protocol = GraphsyncProtocol();
    });

    test('has correct protocol ID', () {
      expect(GraphsyncProtocol.protocolID, equals('/ipfs/graphsync/1.0.0'));
    });

    test('has default timeout', () {
      expect(GraphsyncProtocol.defaultTimeout, equals(Duration(seconds: 60)));
    });

    test('createRequest creates valid request message', () {
      final root = Uint8List.fromList([1, 2, 3]);
      final selector = Uint8List.fromList([4, 5, 6]);

      final message = protocol.createRequest(
        id: 1,
        root: root,
        selector: selector,
      );

      expect(message, isNotNull);
      expect(message.requests, hasLength(1));
      expect(message.requests.first.id, equals(1));
      expect(message.requests.first.root, equals(root));
      expect(message.requests.first.selector, equals(selector));
    });

    test('createRequest with priority sets priority correctly', () {
      final message = protocol.createRequest(
        id: 2,
        root: Uint8List.fromList([1]),
        selector: Uint8List.fromList([2]),
        priority: GraphsyncPriority.high,
      );

      expect(message.requests.first.priority,
          equals(GraphsyncPriority.high.value));
    });

    test('createRequest with extensions includes extensions', () {
      final extensions = {
        'test-extension': Uint8List.fromList([7, 8, 9]),
      };

      final message = protocol.createRequest(
        id: 3,
        root: Uint8List.fromList([1]),
        selector: Uint8List.fromList([2]),
        extensions: extensions,
      );

      expect(message.requests.first.extensions, isNotEmpty);
      expect(message.requests.first.extensions.containsKey('test-extension'),
          isTrue);
    });

    test('createCancelRequest creates cancel message', () {
      final message = protocol.createCancelRequest(42);

      expect(message.requests, hasLength(1));
      expect(message.requests.first.id, equals(42));
      expect(message.requests.first.cancel, isTrue);
    });

    test('createPauseRequest creates pause message', () {
      final message = protocol.createPauseRequest(100);

      expect(message.requests, hasLength(1));
      expect(message.requests.first.id, equals(100));
      expect(message.requests.first.pause, isTrue);
    });

    test('createUnpauseRequest creates unpause message', () {
      final message = protocol.createUnpauseRequest(200);

      expect(message.requests, hasLength(1));
      expect(message.requests.first.id, equals(200));
      expect(message.requests.first.unpause, isTrue);
    });

    test('createResponse creates valid response message', () {
      final message = protocol.createResponse(
        requestId: 1,
        status: ResponseStatus.RS_COMPLETED,
      );

      expect(message, isNotNull);
      expect(message.responses, hasLength(1));
      expect(message.responses.first.id, equals(1));
      expect(
          message.responses.first.status, equals(ResponseStatus.RS_COMPLETED));
    });

    test('createResponse with metadata includes metadata', () {
      final metadata = {
        'key1': 'value1',
        'key2': 'value2',
      };

      final message = protocol.createResponse(
        requestId: 5,
        status: ResponseStatus.RS_IN_PROGRESS,
        metadata: metadata,
      );

      expect(message.responses.first.metadata, isNotEmpty);
      expect(message.responses.first.metadata['key1'], equals('value1'));
    });

    test('createResponse with extensions includes extensions', () {
      final extensions = {
        GraphsyncExtensions.doNotSendCids: Uint8List.fromList([1, 2]),
      };

      final message = protocol.createResponse(
        requestId: 6,
        status: ResponseStatus.RS_IN_PROGRESS,
        extensions: extensions,
      );

      expect(message.responses.first.extensions, isNotEmpty);
    });

    test('createResponse with blocks includes blocks', () {
      final blocks = [
        Block()..data = Uint8List.fromList([10, 20]),
        Block()..data = Uint8List.fromList([30, 40]),
      ];

      final message = protocol.createResponse(
        requestId: 7,
        status: ResponseStatus.RS_IN_PROGRESS,
        blocks: blocks,
      );

      expect(message.blocks, hasLength(2));
    });

    test('createProgressResponse creates progress message', () {
      final message = protocol.createProgressResponse(
        requestId: 8,
        blocksProcessed: 50,
        totalBlocks: 100,
      );

      expect(message.responses.first.status,
          equals(ResponseStatus.RS_IN_PROGRESS));
      expect(message.responses.first.metadata['blocksProcessed'], equals('50'));
      expect(message.responses.first.metadata['totalBlocks'], equals('100'));
    });

    test('GraphsyncPriority enum has correct values', () {
      expect(GraphsyncPriority.low.value, equals(1));
      expect(GraphsyncPriority.normal.value, equals(2));
      expect(GraphsyncPriority.high.value, equals(3));
      expect(GraphsyncPriority.urgent.value, equals(4));
    });

    test('GraphsyncExtensions has standard keys', () {
      expect(GraphsyncExtensions.doNotSendCids, isNotEmpty);
      expect(GraphsyncExtensions.responseMetadata, isNotEmpty);
      expect(GraphsyncExtensions.requestPriority, isNotEmpty);
      expect(GraphsyncExtensions.blockHolesPresent, isNotEmpty);
      expect(GraphsyncExtensions.partialResponse, isNotEmpty);
    });

    test('GraphsyncMetadata has standard keys', () {
      expect(GraphsyncMetadata.totalSize, equals('total-size'));
      expect(GraphsyncMetadata.blockCount, equals('block-count'));
      expect(GraphsyncMetadata.transferRate, equals('transfer-rate'));
    });

    test('multiple requests can be created', () {
      final msg1 = protocol.createRequest(
        id: 1,
        root: Uint8List.fromList([1]),
        selector: Uint8List.fromList([2]),
      );

      final msg2 = protocol.createRequest(
        id: 2,
        root: Uint8List.fromList([3]),
        selector: Uint8List.fromList([4]),
      );

      expect(msg1.requests.first.id, equals(1));
      expect(msg2.requests.first.id, equals(2));
    });

    test('GraphsyncStatus enum has all standard statuses', () {
      expect(GraphsyncStatus.values, contains(GraphsyncStatus.inProgress));
      expect(GraphsyncStatus.values, contains(GraphsyncStatus.completed));
      expect(GraphsyncStatus.values, contains(GraphsyncStatus.error));
      expect(GraphsyncStatus.values, contains(GraphsyncStatus.cancelled));
      expect(GraphsyncStatus.values, contains(GraphsyncStatus.requestPaused));
    });

    test('GraphsyncMessageType enum has all standard types', () {
      expect(
          GraphsyncMessageType.values, contains(GraphsyncMessageType.request));
      expect(
          GraphsyncMessageType.values, contains(GraphsyncMessageType.response));
      expect(
          GraphsyncMessageType.values, contains(GraphsyncMessageType.complete));
      expect(
          GraphsyncMessageType.values, contains(GraphsyncMessageType.cancel));
      expect(
          GraphsyncMessageType.values, contains(GraphsyncMessageType.progress));
      expect(GraphsyncMessageType.values, contains(GraphsyncMessageType.error));
    });
  });
}
