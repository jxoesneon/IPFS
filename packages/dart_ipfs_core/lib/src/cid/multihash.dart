// lib/src/cid/multihash.dart
import 'dart:typed_data';

import 'package:dart_multihash/dart_multihash.dart' as dm;

/// Helpers for computing and decoding multihashes.
///
/// This class is a thin wrapper around `package:dart_multihash` that provides
/// the hash functions most commonly used by dart_ipfs_core.
class MultihashUtils {
  // Private constructor to prevent instantiation.
  MultihashUtils._();

  /// Encodes [hash] with the SHA2-256 multihash function.
  static dm.MultihashInfo sha256(Uint8List hash) {
    if (hash.length != 32) {
      throw ArgumentError('SHA2-256 digest must be 32 bytes');
    }
    return dm.Multihash.encode('sha2-256', hash);
  }

  /// Encodes raw [hash] bytes with the named multihash function.
  ///
  /// Supported names include `sha2-256`, `sha2-512`, `blake2b-256`, etc.
  static dm.MultihashInfo encode(String name, Uint8List hash) =>
      dm.Multihash.encode(name, hash);

  /// Decodes a multihash byte array.
  static dm.MultihashInfo decode(Uint8List bytes) => dm.Multihash.decode(bytes);
}

/// Re-export of the underlying multihash info type from `dart_multihash`.
typedef MultihashInfo = dm.MultihashInfo;
