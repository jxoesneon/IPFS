import 'dart:typed_data';
import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:dart_multihash/dart_multihash.dart';
import 'package:multibase/multibase.dart';
import 'package:test/test.dart';
import 'package:dart_ipfs/src/services/gateway/directory_parser.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart' as pb;
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart' as unixfs;

void main() {
  group('DirectoryHandler', () {
    test('addEntry and listEntries', () {
      final handler = DirectoryHandler('/test');
      final entry = DirectoryEntry(
        name: 'file.txt',
        size: 1024,
        isDirectory: false,
        timestamp: 1234567890,
      );

      handler.addEntry(entry);
      final entries = handler.listEntries();

      expect(entries, hasLength(1));
      expect(entries.first.name, equals('file.txt'));
    });

    test('listEntries returns unmodifiable list', () {
      final handler = DirectoryHandler('/test');
      handler.addEntry(
        DirectoryEntry(
          name: 'file.txt',
          size: 1024,
          isDirectory: false,
          timestamp: 1234567890,
        ),
      );

      final entries = handler.listEntries();
      expect(
        () => entries.add(
          DirectoryEntry(
            name: 'file2.txt',
            size: 2048,
            isDirectory: false,
            timestamp: 1234567890,
          ),
        ),
        throwsUnsupportedError,
      );
    });
  });

  group('DirectoryEntry', () {
    test('constructor initializes all fields', () {
      final entry = DirectoryEntry(
        name: 'test.txt',
        size: 100,
        isDirectory: false,
        timestamp: 1234567890,
        metadata: {'key': 'value'},
      );

      expect(entry.name, equals('test.txt'));
      expect(entry.size, equals(100));
      expect(entry.isDirectory, isFalse);
      expect(entry.timestamp, equals(1234567890));
      expect(entry.metadata, equals({'key': 'value'}));
    });

    test('metadata can be null', () {
      final entry = DirectoryEntry(
        name: 'test.txt',
        size: 100,
        isDirectory: false,
        timestamp: 1234567890,
      );

      expect(entry.metadata, isNull);
    });
  });

  group('DirectoryParser', () {
    late DirectoryParser parser;

    setUp(() {
      parser = DirectoryParser();
    });

    test('parseDirectoryBlock throws on non-dag-pb codec', () {
      final mh = Multihash.encode(
        'sha2-256',
        Uint8List.fromList(List.filled(32, 1)),
      );
      final cid = CID.v1('raw', mh);
      final block = Block(
        cid: cid,
        data: Uint8List.fromList([1, 2, 3]),
        format: 'raw',
      );

      expect(() => parser.parseDirectoryBlock(block), throwsFormatException);
    });

    test('generateHtmlListing includes header', () {
      final handler = DirectoryHandler('/test');
      final html = parser.generateHtmlListing(handler, '/test');

      expect(html, contains('<!DOCTYPE html>'));
      expect(html, contains('<title>IPFS Directory: /test</title>'));
      expect(html, contains('Directory listing for /test'));
    });

    test('generateHtmlListing includes parent link for non-root paths', () {
      final handler = DirectoryHandler('/test/subdir');
      final html = parser.generateHtmlListing(handler, '/test/subdir');

      expect(html, contains('..'));
    });

    test('generateHtmlListing does not include parent link for root', () {
      final handler = DirectoryHandler('/');
      final html = parser.generateHtmlListing(handler, '/');

      expect(html, isNot(contains('..')));
    });

    test('generateHtmlListing sorts directories before files', () {
      final handler = DirectoryHandler('/test');
      handler.addEntry(
        DirectoryEntry(
          name: 'file.txt',
          size: 100,
          isDirectory: false,
          timestamp: 1234567890,
        ),
      );
      handler.addEntry(
        DirectoryEntry(
          name: 'subdir',
          size: 0,
          isDirectory: true,
          timestamp: 1234567890,
        ),
      );

      final html = parser.generateHtmlListing(handler, '/test');
      final subdirIndex = html.indexOf('subdir');
      final fileIndex = html.indexOf('file.txt');

      expect(subdirIndex, lessThan(fileIndex));
    });

    test('generateHtmlListing formats size correctly', () {
      final handler = DirectoryHandler('/test');
      handler.addEntry(
        DirectoryEntry(
          name: 'large.txt',
          size: 1024 * 1024,
          isDirectory: false,
          timestamp: 1234567890,
        ),
      );

      final html = parser.generateHtmlListing(handler, '/test');
      expect(html, contains('1.0 MB'));
    });

    test('generateHtmlListing includes metadata tooltip', () {
      final handler = DirectoryHandler('/test');
      handler.addEntry(
        DirectoryEntry(
          name: 'file.txt',
          size: 100,
          isDirectory: false,
          timestamp: 1234567890,
          metadata: {'mode': '0755', 'custom': 'value'},
        ),
      );

      final html = parser.generateHtmlListing(handler, '/test');
      expect(html, contains('ℹ️'));
    });

    test('parseDirectoryBlock with HAMTShard type', () {
      final mh = Multihash.encode(
        'sha2-256',
        Uint8List.fromList(List.filled(32, 1)),
      );
      final cid = CID.v1('dag-pb', mh);
      final data = unixfs.Data()..type = unixfs.Data_DataType.HAMTShard;
      final pbNode = pb.PBNode()
        ..data = data.writeToBuffer()
        ..links.add(
          pb.PBLink()
            ..name = 'file.txt'
            ..hash = Uint8List.fromList([1, 2, 3])
            ..size = fixnum.Int64(100),
        );

      final block = Block(
        cid: cid,
        data: pbNode.writeToBuffer(),
        format: 'dag-pb',
      );

      final handler = parser.parseDirectoryBlock(block);
      expect(handler.listEntries(), hasLength(1));
    });

    test('parseDirectoryBlock throws on invalid PBNode', () {
      final mh = Multihash.encode(
        'sha2-256',
        Uint8List.fromList(List.filled(32, 1)),
      );
      final cid = CID.v1('dag-pb', mh);
      final block = Block(
        cid: cid,
        data: Uint8List.fromList([1, 2, 3]),
        format: 'dag-pb',
      );

      expect(() => parser.parseDirectoryBlock(block), throwsFormatException);
    });

    test('parseDirectoryBlock throws on non-Directory UnixFS type', () {
      final mh = Multihash.encode(
        'sha2-256',
        Uint8List.fromList(List.filled(32, 1)),
      );
      final cid = CID.v1('dag-pb', mh);
      final data = unixfs.Data()..type = unixfs.Data_DataType.File;
      final pbNode = pb.PBNode()..data = data.writeToBuffer();

      final block = Block(
        cid: cid,
        data: pbNode.writeToBuffer(),
        format: 'dag-pb',
      );

      expect(() => parser.parseDirectoryBlock(block), throwsFormatException);
    });

    test('_formatSize handles different units', () {
      // This tests the private method indirectly through generateHtmlListing
      final handler = DirectoryHandler('/test');
      handler.addEntry(
        DirectoryEntry(
          name: 'kb.txt',
          size: 1024,
          isDirectory: false,
          timestamp: 1234567890,
        ),
      );
      handler.addEntry(
        DirectoryEntry(
          name: 'mb.txt',
          size: 1024 * 1024,
          isDirectory: false,
          timestamp: 1234567890,
        ),
      );
      handler.addEntry(
        DirectoryEntry(
          name: 'gb.txt',
          size: 1024 * 1024 * 1024,
          isDirectory: false,
          timestamp: 1234567890,
        ),
      );

      final html = parser.generateHtmlListing(handler, '/test');
      expect(html, contains('1.0 KB'));
      expect(html, contains('1.0 MB'));
      expect(html, contains('1.0 GB'));
    });

    test('_getFileType handles various extensions', () {
      final handler = DirectoryHandler('/test');
      handler.addEntry(
        DirectoryEntry(
          name: 'image.jpg',
          size: 100,
          isDirectory: false,
          timestamp: 1234567890,
        ),
      );
      handler.addEntry(
        DirectoryEntry(
          name: 'video.mp4',
          size: 100,
          isDirectory: false,
          timestamp: 1234567890,
        ),
      );
      handler.addEntry(
        DirectoryEntry(
          name: 'audio.mp3',
          size: 100,
          isDirectory: false,
          timestamp: 1234567890,
        ),
      );

      final html = parser.generateHtmlListing(handler, '/test');
      expect(html, contains('image'));
      expect(html, contains('video'));
      expect(html, contains('audio'));
    });

    test('_getIcon returns default for unknown type', () {
      final handler = DirectoryHandler('/test');
      handler.addEntry(
        DirectoryEntry(
          name: 'unknown.xyz',
          size: 100,
          isDirectory: false,
          timestamp: 1234567890,
        ),
      );

      final html = parser.generateHtmlListing(handler, '/test');
      expect(html, contains('📄'));
    });

    test('generateHtmlListing formats date correctly', () {
      final handler = DirectoryHandler('/test');
      handler.addEntry(
        DirectoryEntry(
          name: 'file.txt',
          size: 100,
          isDirectory: false,
          timestamp: 1234567890000, // Use milliseconds
        ),
      );

      final html = parser.generateHtmlListing(handler, '/test');
      expect(html, contains('2009'));
    });

    test('generateHtmlListing with empty directory', () {
      final handler = DirectoryHandler('/test');
      final html = parser.generateHtmlListing(handler, '/test');

      expect(html, contains('Directory listing for /test'));
    });

    test('parseDirectoryBlock with empty links', () {
      final mh = Multihash.encode(
        'sha2-256',
        Uint8List.fromList(List.filled(32, 1)),
      );
      final cid = CID.v1('dag-pb', mh);
      final data = unixfs.Data()..type = unixfs.Data_DataType.Directory;
      final pbNode = pb.PBNode()..data = data.writeToBuffer();

      final block = Block(
        cid: cid,
        data: pbNode.writeToBuffer(),
        format: 'dag-pb',
      );

      final handler = parser.parseDirectoryBlock(block);
      expect(handler.listEntries(), isEmpty);
    });

    test('parseDirectoryBlock with multiple links', () {
      final mh = Multihash.encode(
        'sha2-256',
        Uint8List.fromList(List.filled(32, 1)),
      );
      final cid = CID.v1('dag-pb', mh);
      final data = unixfs.Data()..type = unixfs.Data_DataType.Directory;
      final pbNode = pb.PBNode()
        ..data = data.writeToBuffer()
        ..links.add(
          pb.PBLink()
            ..name = 'file1.txt'
            ..hash = Uint8List.fromList([1, 2, 3])
            ..size = fixnum.Int64(100),
        )
        ..links.add(
          pb.PBLink()
            ..name = 'file2.txt'
            ..hash = Uint8List.fromList([4, 5, 6])
            ..size = fixnum.Int64(200),
        )
        ..links.add(
          pb.PBLink()
            ..name = 'dir1'
            ..hash = Uint8List.fromList([7, 8, 9])
            ..size = fixnum.Int64(0),
        );

      final block = Block(
        cid: cid,
        data: pbNode.writeToBuffer(),
        format: 'dag-pb',
      );

      final handler = parser.parseDirectoryBlock(block);
      expect(handler.listEntries(), hasLength(3));
    });

    test('parseDirectoryBlock with link without name', () {
      final mh = Multihash.encode(
        'sha2-256',
        Uint8List.fromList(List.filled(32, 1)),
      );
      final cid = CID.v1('dag-pb', mh);
      final data = unixfs.Data()..type = unixfs.Data_DataType.Directory;
      final pbNode = pb.PBNode()
        ..data = data.writeToBuffer()
        ..links.add(
          pb.PBLink()
            ..hash = Uint8List.fromList([1, 2, 3])
            ..size = fixnum.Int64(100),
        );

      final block = Block(
        cid: cid,
        data: pbNode.writeToBuffer(),
        format: 'dag-pb',
      );

      final handler = parser.parseDirectoryBlock(block);
      expect(handler.listEntries(), hasLength(1));
    });

    test('generateHtmlListing with special characters in names', () {
      final handler = DirectoryHandler('/test');
      handler.addEntry(
        DirectoryEntry(
          name: 'file with spaces.txt',
          size: 100,
          isDirectory: false,
          timestamp: 1234567890,
        ),
      );

      final html = parser.generateHtmlListing(handler, '/test');
      expect(html, contains('file with spaces.txt'));
    });

    test('generateHtmlListing with nested path', () {
      final handler = DirectoryHandler('/test/nested/path');
      handler.addEntry(
        DirectoryEntry(
          name: 'file.txt',
          size: 100,
          isDirectory: false,
          timestamp: 1234567890,
        ),
      );

      final html = parser.generateHtmlListing(handler, '/test/nested/path');
      expect(html, contains('/test/nested'));
    });

    test('generateHtmlListing with very large file', () {
      final handler = DirectoryHandler('/test');
      handler.addEntry(
        DirectoryEntry(
          name: 'huge.bin',
          size: 1024 * 1024 * 1024 * 10,
          isDirectory: false,
          timestamp: 1234567890,
        ),
      );

      final html = parser.generateHtmlListing(handler, '/test');
      expect(html, contains('10.0 GB'));
    });
  });
}
