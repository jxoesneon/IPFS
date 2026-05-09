// lib/src/transport/webtransport/webtransport_dialer_stub.dart
import 'webtransport_dialer.dart';

WebTransportDialer createDialer() => throw UnsupportedError(
  'Cannot create WebTransport dialer without dart:html or dart:io',
);
