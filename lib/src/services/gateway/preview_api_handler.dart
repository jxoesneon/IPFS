import 'dart:convert';

import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/services/gateway/cached_preview_generator.dart';
import 'package:dart_ipfs/src/services/gateway/content_type_handler.dart';
import 'package:dart_ipfs/src/services/gateway/lazy_preview_handler.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// HTTP API handler for preview requests.
///
/// Serves generated previews via the gateway API.
class PreviewApiHandler {
  /// Creates a handler with [_previewGenerator] and [_lazyPreviewHandler].
  PreviewApiHandler(this._previewGenerator, this._lazyPreviewHandler);
  final CachedPreviewGenerator _previewGenerator;
  final LazyPreviewHandler _lazyPreviewHandler;
  final ContentTypeHandler _contentTypeHandler = ContentTypeHandler();

  String _detectContentType(Block block) {
    return _contentTypeHandler.detectContentType(block);
  }

  /// Handles an HTTP request to generate a preview.
  Future<Response> handlePreviewRequest(Request request) async {
    final previewId = request.params['previewId'];
    if (previewId == null) {
      return Response.notFound('Preview ID is required');
    }

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
