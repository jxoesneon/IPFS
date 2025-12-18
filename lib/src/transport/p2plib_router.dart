/// P2plib router exports for platform-specific implementation.
library;

export 'router_events.dart';
export 'router_impl_io.dart' if (dart.library.html) 'router_impl_web.dart';
