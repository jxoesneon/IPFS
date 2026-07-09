// lib/src/cid/multicodec.dart

/// Multicodec registry helpers for core IPLD and IPFS codecs.
///
/// See the multicodec table: https://github.com/multiformats/multicodec
class Multicodec {
  // Private constructor to prevent instantiation.
  Multicodec._();

  static const Map<String, int> _codecs = {
    'identity': 0x00,
    'ip4': 0x04,
    'tcp': 0x06,
    'udp': 0x0111,
    'sha1': 0x11,
    'sha2-256': 0x12,
    'sha2-512': 0x13,
    'sha3-512': 0x14,
    'sha3-384': 0x15,
    'sha3-256': 0x16,
    'sha3-224': 0x17,
    'shake-128': 0x18,
    'shake-256': 0x19,
    'keccak-224': 0x1a,
    'keccak-256': 0x1b,
    'keccak-384': 0x1c,
    'keccak-512': 0x1d,
    'blake3': 0x1e,
    'sha2-384': 0x20,
    'murmur3-x64-64': 0x22,
    'murmur3-32': 0x23,
    'ip6': 0x29,
    'dnslink': 0x33,
    'dns': 0x35,
    'dns4': 0x36,
    'dns6': 0x37,
    'dnsaddr': 0x38,
    'raw': 0x55,
    'dbl-sha2-256': 0x56,
    'dag-pb': 0x70,
    'dag-cbor': 0x71,
    'libp2p-key': 0x72,
    'git-raw': 0x78,
    'dag-jose': 0x85,
    'aes-128': 0x80,
    'aes-256': 0x81,
    'eth-block': 0x90,
    'eth-tx': 0x91,
    'bitcoin-block': 0xb0,
    'bitcoin-tx': 0xb1,
    'zcash-block': 0xc0,
    'zcash-tx': 0xc1,
    'md4': 0xd4,
    'md5': 0xd5,
    'ed25519-pub': 0xed,
    'x25519-pub': 0xec,
    'secp256k1-pub': 0xe7,
    'sr25519-pub': 0xef,
    'ipld-ns': 0x300,
    'ipfs-ns': 0x301,
    'ipns-ns': 0x302,
    'ipfs': 0x01a5,
    'ipns': 0x01a6,
    'dag-json': 0x0129,
    'dag-cose': 0x012b,
    'p2p-circuit': 0x0122,
    'quic': 0x01cc,
    'quic-v1': 0x01cd,
    'http': 0x01e0,
    'car': 0x0202,
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

  /// Returns the number of registered codecs.
  static int get count => _codecs.length;
}
