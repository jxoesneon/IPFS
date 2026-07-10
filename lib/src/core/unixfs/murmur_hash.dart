/// Native 64-bit MurmurHash3 implementation for UnixFS HAMT sharding.
///
/// This file uses Dart VM 64-bit integers and is not compiled for web builds.
/// The web build uses [murmur_hash_web.dart] instead.
library;

/// Computes the MurmurHash3 x64-64 digest of [bytes] and returns the first
/// 64 bits (h1) as the [murmur3-x64-64] hash value.
int murmur3X64Hash64(List<int> bytes, {int seed = 0}) {
  return _murmur3X64Hash128(bytes, seed: seed)[0];
}

/// Computes the MurmurHash3 x64-128 digest of [bytes] as a pair of unsigned
/// 64-bit values `[h1, h2]`.
List<int> _murmur3X64Hash128(List<int> bytes, {int seed = 0}) {
  const c1 = 0x87c37b91114253d5;
  const c2 = 0x4cf5ad432745937f;

  var h1 = _mask64(seed);
  var h2 = _mask64(seed);

  final length = bytes.length;
  final nblocks = length ~/ 16;

  for (var i = 0; i < nblocks; i++) {
    final offset = i * 16;
    var k1 = _mask64(_getUint64LE(bytes, offset));
    var k2 = _mask64(_getUint64LE(bytes, offset + 8));

    k1 = _mask64(k1 * c1);
    k1 = _rotl64(k1, 31);
    k1 = _mask64(k1 * c2);
    h1 ^= k1;

    h1 = _rotl64(h1, 27);
    h1 = _mask64(h1 + h2);
    h1 = _mask64(h1 * 5 + 0x52dce729);

    k2 = _mask64(k2 * c2);
    k2 = _rotl64(k2, 33);
    k2 = _mask64(k2 * c1);
    h2 ^= k2;

    h2 = _rotl64(h2, 31);
    h2 = _mask64(h2 + h1);
    h2 = _mask64(h2 * 5 + 0x38495ab5);
  }

  var k1 = 0;
  var k2 = 0;
  final tail = length & 15;

  if (tail >= 15) k2 ^= (bytes[length - tail + 14] & 0xff) << 48;
  if (tail >= 14) k2 ^= (bytes[length - tail + 13] & 0xff) << 40;
  if (tail >= 13) k2 ^= (bytes[length - tail + 12] & 0xff) << 32;
  if (tail >= 12) k2 ^= (bytes[length - tail + 11] & 0xff) << 24;
  if (tail >= 11) k2 ^= (bytes[length - tail + 10] & 0xff) << 16;
  if (tail >= 10) k2 ^= (bytes[length - tail + 9] & 0xff) << 8;
  if (tail >= 9) {
    k2 ^= bytes[length - tail + 8] & 0xff;
    k2 = _mask64(k2 * c2);
    k2 = _rotl64(k2, 33);
    k2 = _mask64(k2 * c1);
    h2 ^= k2;
  }
  if (tail >= 8) k1 ^= (bytes[length - tail + 7] & 0xff) << 56;
  if (tail >= 7) k1 ^= (bytes[length - tail + 6] & 0xff) << 48;
  if (tail >= 6) k1 ^= (bytes[length - tail + 5] & 0xff) << 40;
  if (tail >= 5) k1 ^= (bytes[length - tail + 4] & 0xff) << 32;
  if (tail >= 4) k1 ^= (bytes[length - tail + 3] & 0xff) << 24;
  if (tail >= 3) k1 ^= (bytes[length - tail + 2] & 0xff) << 16;
  if (tail >= 2) k1 ^= (bytes[length - tail + 1] & 0xff) << 8;
  if (tail >= 1) {
    k1 ^= bytes[length - tail + 0] & 0xff;
    k1 = _mask64(k1 * c1);
    k1 = _rotl64(k1, 31);
    k1 = _mask64(k1 * c2);
    h1 ^= k1;
  }

  h1 ^= length;
  h2 ^= length;

  h1 = _mask64(h1 + h2);
  h2 = _mask64(h2 + h1);

  h1 = _fmix64(h1);
  h2 = _fmix64(h2);

  h1 = _mask64(h1 + h2);
  h2 = _mask64(h2 + h1);

  return <int>[h1, h2];
}

int _mask64(int value) => value & 0xFFFFFFFFFFFFFFFF;

int _rotl64(int x, int r) {
  final masked = _mask64(x);
  return _mask64((masked << r) | (masked >>> (64 - r)));
}

int _fmix64(int k) {
  var result = _mask64(k);
  result ^= result >>> 33;
  result = _mask64(result * 0xff51afd7ed558ccd);
  result ^= result >>> 33;
  result = _mask64(result * 0xc4ceb9fe1a85ec53);
  result ^= result >>> 33;
  return result;
}

int _getUint64LE(List<int> bytes, int offset) {
  var result = 0;
  for (var i = 0; i < 8; i++) {
    result |= (bytes[offset + i] & 0xff) << (i * 8);
  }
  return result;
}
