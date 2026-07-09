// Shared helpers for fuzz and property-based tests.
//
// Dart does not have a widely-adopted standard fuzz or property-based testing
// package, so these helpers provide deterministic, seedable random input
// generation that can be used to exercise binary parsers with arbitrary and
// corrupt data.
import 'dart:math' as math;
import 'dart:typed_data';

/// A seedable random number generator used across all fuzz/property tests.
///
/// Using a fixed seed makes failures reproducible. Callers may override the
/// seed via the `FUZZ_SEED` environment variable when running locally.
math.Random makeRandom([int? seed]) {
  final s =
      seed ??
      int.tryParse(
        const String.fromEnvironment('FUZZ_SEED', defaultValue: ''),
      ) ??
      0xC1E1; // "Ciel" inspired default seed.
  return math.Random(s);
}

/// Generates [length] random bytes.
Uint8List randomBytes(math.Random rng, int length) {
  final data = Uint8List(length);
  for (var i = 0; i < length; i++) {
    data[i] = rng.nextInt(256);
  }
  return data;
}

/// Generates a random byte sequence with length in [minLength, maxLength].
Uint8List randomBytesRange(math.Random rng, int minLength, int maxLength) {
  final length = minLength + rng.nextInt(maxLength - minLength + 1);
  return randomBytes(rng, length);
}

/// Returns a copy of [bytes] with the byte at [index] replaced by [value].
Uint8List withByte(Uint8List bytes, int index, int value) {
  final copy = Uint8List.fromList(bytes);
  copy[index] = value;
  return copy;
}

/// Returns a copy of [bytes] with [count] random bytes flipped.
Uint8List withFlippedBytes(math.Random rng, Uint8List bytes, int count) {
  final copy = Uint8List.fromList(bytes);
  for (var i = 0; i < count && i < copy.length; i++) {
    final idx = rng.nextInt(copy.length);
    copy[idx] ^= rng.nextInt(256);
  }
  return copy;
}

/// Returns the first [length] bytes of [bytes] (truncation).
Uint8List truncated(Uint8List bytes, int length) {
  if (length >= bytes.length) return Uint8List.fromList(bytes);
  return Uint8List.fromList(bytes.sublist(0, length));
}

/// Generates a random unsigned varint byte sequence (1-10 bytes).
Uint8List randomVarint(math.Random rng) {
  final length = 1 + rng.nextInt(10);
  final data = Uint8List(length);
  for (var i = 0; i < length - 1; i++) {
    data[i] = (rng.nextInt(128) | 0x80); // continuation bit set
  }
  data[length - 1] = rng.nextInt(128); // final byte, no continuation
  return data;
}

/// Generates a random valid UTF-8 string of [length] code points.
String randomUtf8String(math.Random rng, int length) {
  final buffer = StringBuffer();
  for (var i = 0; i < length; i++) {
    // Keep to BMP printable range to ensure valid UTF-8.
    buffer.writeCharCode(0x20 + rng.nextInt(0x7E - 0x20));
  }
  return buffer.toString();
}

/// Generates a byte sequence containing invalid UTF-8 (lone continuation bytes
/// and truncated multi-byte sequences).
Uint8List invalidUtf8Bytes(math.Random rng, int length) {
  final data = Uint8List(length);
  for (var i = 0; i < length; i++) {
    // Mix of high bytes that start multi-byte sequences without proper
    // continuation bytes.
    data[i] = 0x80 + rng.nextInt(0x7F);
  }
  return data;
}
