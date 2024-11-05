import 'dart:convert';
import 'package:shelf/shelf.dart';

class PreviewApiHandler {
  final CachedPreviewGenerator _previewGenerator;
  final LazyPreviewHandler _lazyPreviewHandler;

  PreviewApiHandler(this._previewGenerator, this._lazyPreviewHandler);

  Future<Response> handlePreviewRequest(Request request) async {
    final previewId = request.params['previewId'];
    final block = _lazyPreviewHandler.getPreviewBlock(previewId);
    
    if (block == null) {
      return Response.notFound('Preview not found');
    }

    final contentType = _detectContentType(block);
    final preview = await _previewGenerator.generatePreview(block, contentType);

    if (preview == null) {
      return Response.notFound('Preview generation failed');
    }

    return Response.ok(
      jsonEncode({
        'preview': base64Encode(preview),
        'contentType': contentType,
      }),
      headers: {'content-type': 'application/json'},
    );
  }
} 