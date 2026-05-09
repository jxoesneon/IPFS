// lib/src/transport/webtransport/webtransport_dialer_stub.dart
import 'webtransport_dialer.dart';

/// Factory for creating the platform-specific dialer.
WebTransportDialer createDialer() => throw UnsupportedError(
      'Cannot create WebTransport dialer without dart:js_interop or dart:io',
    );
