export 'http_server_adapter.dart';
export 'http_server_adapter_stub.dart'
    if (dart.library.io) 'http_server_adapter_io.dart'
    if (dart.library.html) 'http_server_adapter_web.dart';

