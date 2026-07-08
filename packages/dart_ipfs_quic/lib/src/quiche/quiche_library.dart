import 'dart:ffi';

import '../generated/quiche_bindings.dart' as q;

/// Result of attempting to load the native quiche library.
class QuicheLibrary {
  final DynamicLibrary? _library;
  final String? error;

  QuicheLibrary._(this._library, this.error);

  /// True if the native quiche library was loaded successfully.
  bool get isAvailable => _library != null;

  /// The version reported by the native library, or `null` if unavailable.
  String? get version {
    if (!isAvailable) return null;
    try {
      return q.quiche_version();
    } catch (_) {
      return null;
    }
  }

  /// Probe the environment for the native quiche library.
  factory QuicheLibrary.probe() {
    try {
      // Accessing any function from the bindings will trigger loading.
      final lib = q.quicheLibrary;
      return QuicheLibrary._(lib, null);
    } on UnsupportedError catch (e) {
      return QuicheLibrary._(null, e.message?.toString());
    } catch (e) {
      return QuicheLibrary._(null, e.toString());
    }
  }
}
