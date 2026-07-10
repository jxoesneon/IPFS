/// Web-safe stub for UnixFS HAMT MurmurHash3 hashing.
///
/// The real murmur3-x64-64 implementation uses 64-bit integer literals and
/// bitwise operations that cannot be represented exactly in JavaScript. The
/// dashboard and other web consumers do not exercise HAMT directory building, so
/// this stub returns a deterministic 32-bit fallback hash sufficient for the
/// file to compile under dart2js.
library;

/// Returns a deterministic fallback hash for web builds.
///
/// The native implementation lives in [murmur_hash.dart] and is used on all
/// non-web platforms. On the web, HAMT directory construction is not supported
/// and callers that rely on the exact murmur3-x64-64 digest must run on a
/// native platform.
int murmur3X64Hash64(List<int> bytes, {int seed = 0}) {
  var h = seed;
  for (final byte in bytes) {
    h = ((h * 31) + byte) & 0x3FFFFFFF;
  }
  return h;
}
