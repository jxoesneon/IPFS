import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:dart_ipfs/src/services/gateway/content_type_handler.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/cid.dart';

void main() {
  group('ContentTypeHandler', () {
    late ContentTypeHandler handler;

    setUp(() {
      handler = ContentTypeHandler();
    });

    group('Detection', () {
      test('detectContentType detects known signatures', () async {
        final pngData = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x00]);
        final pngBlock = await Block.fromData(pngData);
        expect(handler.detectContentType(pngBlock), 'image/png');

        final jpegData = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0x00]);
        final jpegBlock = await Block.fromData(jpegData);
        expect(handler.detectContentType(jpegBlock), 'image/jpeg');
      });

      test('detectContentType falls back to octet-stream', () async {
        final randomData = Uint8List.fromList([0x00, 0x01, 0x02, 0x03]);
        final block = await Block.fromData(randomData);
        expect(handler.detectContentType(block), 'application/octet-stream');
      });

      test('detectContentType detects text', () async {
        final textData = utf8.encode(
          'Hello world, this is just plain text content.',
        );
        final block = await Block.fromData(Uint8List.fromList(textData));
        expect(handler.detectContentType(block), 'text/plain');
      });

      test('detectContentType favors filename', () async {
        final data = Uint8List.fromList([0x00]);
        final block = await Block.fromData(data);
        expect(
          handler.detectContentType(block, filename: 'test.html'),
          'text/html',
        );
      });
    });

    group('Processing', () {
      test('processContent renders markdown', () async {
        final mdContent = '# Hello';
        final block = await Block.fromData(
          Uint8List.fromList(utf8.encode(mdContent)),
        );

        final processed = handler.processContent(block, 'text/markdown');
        final html = utf8.decode(processed);

        expect(html, contains('<h1>Hello</h1>'));
        expect(html, contains('<!DOCTYPE html>'));
      });

      test('processContent handles CAR files', () async {
        final data = Uint8List.fromList([1, 2, 3]); // Fake CAR data
        final block = await Block.fromData(data);

        final processed = handler.processContent(
          block,
          'application/vnd.ipfs.car',
        );
        final html = utf8.decode(processed);

        expect(html, contains('CAR Archive Preview'));
        expect(html, contains('3 B')); // Size check
      });

      test('processContent calls pass-through for unknown types', () async {
        final data = Uint8List.fromList([1, 2, 3]);
        final block = await Block.fromData(data);

        final processed = handler.processContent(block, 'application/unknown');
        expect(processed, equals(data));
      });
    });
  });
}

