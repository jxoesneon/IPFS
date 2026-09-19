/// Web-safe MurmurHash3 x64-64 implementation for UnixFS HAMT sharding.
///
/// The companion [murmur_hash.dart] used on native platforms relies on
/// 64-bit `int` arithmetic that `dart2js` cannot represent (web `int` is an
/// IEEE-754 double and `>>>` is a 32-bit operation). This implementation
/// performs the identical algorithm with [BigInt] arithmetic, which
/// dart2js lowers to native JavaScript `BigInt`, so the computed digest is
/// exactly the murmur3-x64-64 value produced by the native build.
///
/// Because the public signature must stay `int` — and web bitwise shifts
/// only ever observe the low 32 bits of an operand — the function returns
/// the low 32 bits of the 64-bit `h1` half-word. This is exact for every
/// HAMT bucket index at depth 0–3 (`shift < 32`); deeper shard recursion
/// requires a native platform, which is a pre-existing limitation of the
/// shared `(hash >>> shift) & mask` indexing code rather than of this
/// function.
library;

/// Computes the MurmurHash3 x64-64 digest of [bytes].
///
/// Returns the exact low 32 bits of the 64-bit `h1` result (identical to
/// `murmur_hash.dart`'s `murmur3X64Hash64(bytes, seed: seed) & 0xFFFFFFFF`
/// on native platforms).
int murmur3X64Hash64(List<int> bytes, {int seed = 0}) {
  final h1 = _murmur3X64Hash128(bytes, seed: seed)[0];
  return (h1 & _mask32).toInt();
}

final BigInt _mask64 = (BigInt.one << 64) - BigInt.one;
final BigInt _mask32 = (BigInt.one << 32) - BigInt.one;

/// Computes the MurmurHash3 x64-128 digest of [bytes] as a pair of unsigned
/// 64-bit values `[h1, h2]` held in [BigInt]s.
List<BigInt> _murmur3X64Hash128(List<int> bytes, {int seed = 0}) {
  final c1 = BigInt.parse('0x87c37b91114253d5');
  final c2 = BigInt.parse('0x4cf5ad432745937f');

  var h1 = _mask(BigInt.from(seed));
  var h2 = _mask(BigInt.from(seed));

  final length = bytes.length;
  final nblocks = length ~/ 16;

  for (var i = 0; i < nblocks; i++) {
    final offset = i * 16;
    var k1 = _getUint64LE(bytes, offset);
    var k2 = _getUint64LE(bytes, offset + 8);

    k1 = _mask(k1 * c1);
    k1 = _rotl64(k1, 31);
    k1 = _mask(k1 * c2);
    h1 ^= k1;

    h1 = _rotl64(h1, 27);
    h1 = _mask(h1 + h2);
    h1 = _mask(h1 * BigInt.from(5) + BigInt.from(0x52dce729));

    k2 = _mask(k2 * c2);
    k2 = _rotl64(k2, 33);
    k2 = _mask(k2 * c1);
    h2 ^= k2;

    h2 = _rotl64(h2, 31);
    h2 = _mask(h2 + h1);
    h2 = _mask(h2 * BigInt.from(5) + BigInt.from(0x38495ab5));
  }

  var k1 = BigInt.zero;
  var k2 = BigInt.zero;
  final tail = length & 15;

  if (tail >= 15) k2 ^= BigInt.from(bytes[length - tail + 14] & 0xff) << 48;
  if (tail >= 14) k2 ^= BigInt.from(bytes[length - tail + 13] & 0xff) << 40;
  if (tail >= 13) k2 ^= BigInt.from(bytes[length - tail + 12] & 0xff) << 32;
  if (tail >= 12) k2 ^= BigInt.from(bytes[length - tail + 11] & 0xff) << 24;
  if (tail >= 11) k2 ^= BigInt.from(bytes[length - tail + 10] & 0xff) << 16;
  if (tail >= 10) k2 ^= BigInt.from(bytes[length - tail + 9] & 0xff) << 8;
  if (tail >= 9) {
    k2 ^= BigInt.from(bytes[length - tail + 8] & 0xff);
    k2 = _mask(k2 * c2);
    k2 = _rotl64(k2, 33);
    k2 = _mask(k2 * c1);
    h2 ^= k2;
  }
  if (tail >= 8) k1 ^= BigInt.from(bytes[length - tail + 7] & 0xff) << 56;
  if (tail >= 7) k1 ^= BigInt.from(bytes[length - tail + 6] & 0xff) << 48;
  if (tail >= 6) k1 ^= BigInt.from(bytes[length - tail + 5] & 0xff) << 40;
  if (tail >= 5) k1 ^= BigInt.from(bytes[length - tail + 4] & 0xff) << 32;
  if (tail >= 4) k1 ^= BigInt.from(bytes[length - tail + 3] & 0xff) << 24;
  if (tail >= 3) k1 ^= BigInt.from(bytes[length - tail + 2] & 0xff) << 16;
  if (tail >= 2) k1 ^= BigInt.from(bytes[length - tail + 1] & 0xff) << 8;
  if (tail >= 1) {
    k1 ^= BigInt.from(bytes[length - tail + 0] & 0xff);
    k1 = _mask(k1 * c1);
    k1 = _rotl64(k1, 31);
    k1 = _mask(k1 * c2);
    h1 ^= k1;
  }

  h1 ^= BigInt.from(length);
  h2 ^= BigInt.from(length);

  h1 = _mask(h1 + h2);
  h2 = _mask(h2 + h1);

  h1 = _fmix64(h1);
  h2 = _fmix64(h2);

  h1 = _mask(h1 + h2);
  h2 = _mask(h2 + h1);

  return <BigInt>[h1, h2];
}

BigInt _mask(BigInt value) => value & _mask64;

BigInt _rotl64(BigInt x, int r) =>
    _mask((_mask(x) << r) | (_mask(x) >> (64 - r)));

BigInt _fmix64(BigInt k) {
  var result = _mask(k);
  result ^= result >> 33;
  result = _mask(result * BigInt.parse('0xff51afd7ed558ccd'));
  result ^= result >> 33;
  result = _mask(result * BigInt.parse('0xc4ceb9fe1a85ec53'));
  result ^= result >> 33;
  return result;
}

BigInt _getUint64LE(List<int> bytes, int offset) {
  var result = BigInt.zero;
  for (var i = 0; i < 8; i++) {
    result |= BigInt.from(bytes[offset + i] & 0xff) << (i * 8);
  }
  return result;
}
