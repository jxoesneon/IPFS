// Export the IpfsPlatform interface (available on all platforms from stub)
export 'platform_stub.dart' show IpfsPlatform;

// Export the platform-specific factory function
export 'platform_stub.dart'
    if (dart.library.io) 'platform_io.dart'
    if (dart.library.html) 'platform_web.dart'
    show getPlatform;
