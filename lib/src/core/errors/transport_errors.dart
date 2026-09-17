/// Error classes for transport-layer availability and failures.
library;

/// Exception thrown when a transport is enabled but has no working backend
/// on the current platform.
///
/// Browser-based transports such as WebTransport and WebRTC are only
/// implemented for the web platform. On platforms without a backend (for
/// example the Dart VM/IO platform) the corresponding stubs throw this
/// exception instead of [UnimplementedError] so callers can distinguish an
/// unavailable platform backend from a genuine implementation gap.
class TransportUnavailableException implements Exception {
  /// Creates a [TransportUnavailableException] with the given [message].
  TransportUnavailableException(this.message);

  /// Creates a [TransportUnavailableException] naming the [transport] that
  /// is unavailable and the [platform] it was requested on.
  ///
  /// Produces a message of the form
  /// `'$transport is not available on $platform platforms'`.
  TransportUnavailableException.forPlatform(String transport, String platform)
    : this('$transport is not available on $platform platforms');

  /// The error message.
  final String message;

  @override
  String toString() => 'TransportUnavailableException: $message';
}
