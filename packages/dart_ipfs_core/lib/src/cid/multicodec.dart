// lib/src/cid/multicodec.dart

/// Multicodec registry helpers for core IPLD and IPFS codecs.
///
/// See the multicodec table: https://github.com/multiformats/multicodec
class Multicodec {
  // Private constructor to prevent instantiation.
  Multicodec._();

  static const Map<String, int> _codecs = {
    'identity': 0x00,
    'raw': 0x55,
    'dag-pb': 0x70,
    'dag-cbor': 0x71,
    'libp2p-key': 0x72,
    'dag-json': 0x0129,
    'dag-jose': 0x85,
    'dag-cose': 0x012b,
    'car': 0x0202,
    'ipld-ns': 0x300,
    'ipfs-ns': 0x301,
    'ipns-ns': 0x302,
  };

  /// Returns the numeric multicodec code for [name].
  ///
  /// Throws [ArgumentError] if [name] is not supported.
  static int code(String name) {
    final code = _codecs[name];
    if (code == null) {
      throw ArgumentError('Unsupported multicodec: $name');
    }
    return code;
  }

  /// Returns the canonical name for [code].
  ///
  /// Throws [ArgumentError] if [code] is not supported.
  static String name(int code) {
    final entry = _codecs.entries.firstWhere(
      (e) => e.value == code,
      orElse: () => throw ArgumentError(
        'Unsupported multicodec code: 0x${code.toRadixString(16)}',
      ),
    );
    return entry.key;
  }

  /// Returns true if [name] is a supported multicodec.
  static bool supports(String name) => _codecs.containsKey(name);

  /// Returns true if [code] is a supported multicodec code.
  static bool supportsByCode(int code) => _codecs.containsValue(code);

  /// Returns a read-only view of the supported codec names.
  static List<String> get supported => List.unmodifiable(_codecs.keys);
}
