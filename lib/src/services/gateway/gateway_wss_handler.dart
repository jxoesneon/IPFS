// lib/src/services/gateway/gateway_wss_handler.dart
export 'gateway_wss_handler_io.dart'
    if (dart.library.html) 'gateway_wss_handler_web.dart';
