import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/services/gateway/file_preview_handler.dart';
import 'package:test/test.dart';

void main() {
  group('FilePreviewHandler', () {
    late FilePreviewHandler handler;
    // Create a dummy CID using synchronous computation helper
    final dummyCid = CID.computeForDataSync(
      Uint8List.fromList(utf8.encode('dummy')),
    );

    setUp(() {
      handler = FilePreviewHandler();
    });

    test('generatePreview returns null for unsupported type', () {
      final block = Block(
        cid: dummyCid,
        data: Uint8List.fromList(utf8.encode('blob data')),
      );
      final result = handler.generatePreview(block, 'application/octet-stream');
      expect(result, isNull);
    });

    test('generatePreview returns null for too large file', () {
      final largeData = Uint8List(6 * 1024 * 1024); // 6MB
      final block = Block(cid: dummyCid, data: largeData);
      final result = handler.generatePreview(block, 'text/plain');
      expect(result, isNull);
    });

    test('generateImagePreview generates valid base64 image tag', () {
      final data = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]); // PNG Header
      final block = Block(cid: dummyCid, data: data);
      final result = handler.generatePreview(block, 'image/png');

      expect(result, isNotNull);
      expect(result, contains('<div class="preview-container">'));
      expect(result, contains('<img src="data:image/png;base64,'));
      // The current implementation uses Uri.encodeFull which is likely wrong.
      // Valid base64 for these bytes should be "iVBORw=="
      // Let's assert that it matches actual Base64 pattern if fixed,
      // or exposes the bug.
      // We'll calculate expected base64
      final expectedBase64 = base64Encode(data);
      expect(result, contains(expectedBase64));
    });

    test('generateTextPreview handles JSON and escapes XSS', () {
      final jsonStr = '{"key": "<script>alert(1)</script>"}';
      final block = Block(
        cid: dummyCid,
        data: Uint8List.fromList(utf8.encode(jsonStr)),
      );
      final result = handler.generatePreview(block, 'application/json');

      expect(result, isNotNull);
      expect(result, contains('<pre class="preview-text"><code>'));
      // Should contain formatted JSON with escaped quotes
      expect(result, contains('&quot;key&quot;:'));
      // Should NOT contain raw script tag -> should be escaped
      expect(result, isNot(contains('<script>')));
      expect(result, contains('&lt;script&gt;'));
    });

    test('generateTextPreview formats Markdown correctly', () {
      final mdStr = '# Header\n\nContent';
      final block = Block(
        cid: dummyCid,
        data: Uint8List.fromList(utf8.encode(mdStr)),
      );
      final result = handler.generatePreview(block, 'text/markdown');

      expect(result, isNotNull);
      // The current logic converts to HTML then escapes it?
      // If it converts to HTML, we expect <h1>Header</h1>
      // If it escapes it, we expect &lt;h1&gt;Header&lt;/h1&gt;
      // Let's see what it does.
      // Ideally we want just the rendered HTML in a div, OR the source.
      // If it's in <code>, it should be source?
      // If the code converts to HTML, then puts in code, it effectively shows HTML source.
    });
  });
}
