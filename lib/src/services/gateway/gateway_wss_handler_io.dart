// lib/src/services/gateway/gateway_wss_handler_io.dart
import 'dart:io';

import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:shelf/shelf.dart';

/// Handles a WebSocket upgrade request on the IO platform.
Future<Response> handleGatewayWebSocket(
  Request request,
  Logger logger,
) async {
  final rawRequest = request.context['shelf.io.request'] as HttpRequest?;
  if (rawRequest == null) {
    return Response(
      426,
      body: 'WebSocket upgrade not available on this adapter',
      headers: {'Content-Type': 'text/plain'},
    );
  }
  if (!WebSocketTransformer.isUpgradeRequest(rawRequest)) {
    return Response(
      400,
      body: 'Expected WebSocket upgrade headers',
      headers: {'Content-Type': 'text/plain'},
    );
  }
  try {
    final socket = await WebSocketTransformer.upgrade(rawRequest);
    _serveWebSocket(socket, logger);
    return Response.ok('');
  } catch (e, stackTrace) {
    logger.error('WebSocket upgrade failed', e, stackTrace);
    return Response.internalServerError(
      body: 'WebSocket upgrade failed',
    );
  }
}

void _serveWebSocket(WebSocket socket, Logger logger) {
  socket.listen(
    (message) {
      logger.debug('WSS message received: $message');
      // WSS gateway data channel is intentionally left minimal for v2.1.
      socket.add('{"status":"ok"}');
    },
    onDone: () {
      logger.debug('WSS connection closed');
    },
    onError: (Object e, StackTrace st) {
      logger.warning('WSS connection error', e, st);
    },
  );
}
