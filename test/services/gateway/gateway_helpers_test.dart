import 'dart:typed_data';
import 'package:fixnum/fixnum.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/services/gateway/gateway_lru_cache.dart';
import 'package:dart_ipfs/src/services/gateway/content_type_handler.dart';
import 'package:dart_ipfs/src/services/gateway/directory_parser.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart' as dag;
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart' as unixfs;
import 'package:test/test.dart';

// Mock CID for testing
CID get mockCid => CID.computeForDataSync(Uint8List(0));
CID get dagPbCid {
  final base = CID.computeForDataSync(Uint8List(0));
  return CID(version: base.version, multihash: base.multihash, codec: 'dag-pb');
}

void main() {
  group('GatewayLruCache', () {
    test('capacity check', () {
      expect(
        () => GatewayLruCache<String, int>(0),
        throwsA(isA<AssertionError>()),
      );
    });

    test('put/get/eviction', () {
      final cache = GatewayLruCache<String, int>(2);

      cache.put('a', 1);
      cache.put('b', 2);
      expect(cache.length, 2);
      expect(
        cache.get('a'),
        1,
      ); // Access 'a', making 'b' LRU if explicit access updates it?
      // LinkedHashMap by default is insertion order.
      // GatewayLruCache implementation does remove(key) + put(key) on access.
      // So 'a' becomes MRU. 'b' is LRU.

      cache.put('c', 3);
      // Should remove 'b'.

      expect(cache.containsKey('b'), isFalse);
      expect(cache.containsKey('a'), isTrue);
      expect(cache.containsKey('c'), isTrue);
    });

    test('clear', () {
      final cache = GatewayLruCache<String, int>(2)..put('a', 1);
      cache.clear();
      expect(cache.length, 0);
    });
  });

  group('ContentTypeHandler', () {
    final handler = ContentTypeHandler();

    test('detectContentType from filename', () {
      final block = Block(cid: mockCid, data: Uint8List(0));
      expect(
        handler.detectContentType(block, filename: 'test.html'),
        'text/html',
      );
    });

    test('detectContentType from content', () {
      final pngData = Uint8List.fromList([
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
      ]);
      final block = Block(cid: mockCid, data: pngData);
      expect(handler.detectContentType(block), 'image/png');
    });

    test('processContent markdown', () {
      final mdData = Uint8List.fromList('# Hello'.codeUnits);
      final block = Block(cid: mockCid, data: mdData);
      final htmlBytes = handler.processContent(block, 'text/markdown');
      expect(String.fromCharCodes(htmlBytes), contains('<h1>Hello</h1>'));
    });
  });

  group('DirectoryParser', () {
    final parser = DirectoryParser();

    test('parseDirectoryBlock valid unixfs', () {
      // 1. Create UnixFS Data
      final unixData = unixfs.Data()..type = unixfs.Data_DataType.Directory;

      // 2. Create PBNode
      final node = dag.PBNode()..data = unixData.writeToBuffer();

      // Add a link
      final link = dag.PBLink()
        ..name = 'file.txt'
        ..size = Int64(123);

      node.links.add(link);

      final blockData = node.writeToBuffer();
      final block = Block(cid: dagPbCid, data: blockData);

      final dirHandler = parser.parseDirectoryBlock(block);
      final entries = dirHandler.listEntries();

      expect(entries, hasLength(1));
      expect(entries.first.name, 'file.txt');
      expect(entries.first.size, 123);
    });

    test('generateHtmlListing', () {
      final dir = DirectoryHandler('/foo');
      dir.addEntry(
        DirectoryEntry(
          name: 'test.txt',
          size: 100,
          isDirectory: false,
          timestamp: 0,
        ),
      );

      final html = parser.generateHtmlListing(dir, '/foo/');
      expect(html, contains('test.txt'));
    });
  });
}
