// lib/src/services/gateway/gateway_wss_handler_web.dart
import 'package:shelf/shelf.dart';

import '../../utils/logger.dart';

/// Web stub for WebSocket upgrade requests.
Future<Response> handleGatewayWebSocket(Request request, Logger logger) async {
  return Response(
    426,
    body: 'WebSocket upgrade not available on web platform',
    headers: {'Content-Type': 'text/plain'},
  );
}
