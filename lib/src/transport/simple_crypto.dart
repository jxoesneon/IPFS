import 'dart:async';
import 'dart:typed_data';
import 'package:p2plib/p2plib.dart' as p2p;

/// A simple [p2p.Crypto] implementation that uses the seed directly as identity
/// and performs no encryption or signing. This is suitable for tunneled traffic
/// where security is handled by the carrier (e.g. Libp2p/Noise).
class SimpleCrypto implements p2p.Crypto {
  Uint8List? _seed;
  Uint8List? _encPubKey;
  Uint8List? _signPubKey;

  @override
  Future<p2p.InitResult> init([Uint8List? seed]) async {
    _seed = seed ?? Uint8List(32);
    // Pad/Repeat to 32 bytes if shorter
    if (_seed!.length < 32) {
      final newSeed = Uint8List(32);
      newSeed.setRange(0, _seed!.length, _seed!);
      _seed = newSeed;
    }
    // Use the 32-byte seed as both keys to match our padding logic
    _encPubKey = _seed!.sublist(0, 32);
    _signPubKey = _seed!.sublist(0, 32);

    return (seed: _seed!, encPubKey: _encPubKey!, signPubKey: _signPubKey!);
  }

  @override
  Future<Uint8List> seal(Uint8List datagram) async {
    // Just append 64 bytes of zeros as dummy signature.
    // Ensure the message is long enough in the caller (e.g. > 144 bytes payload)
    // p2plib 2.3.1 requires length == 208 OR length > 256.
    final builder = BytesBuilder(copy: false)
      ..add(datagram)
      ..add(Uint8List(64));
    return builder.toBytes();
  }

  @override
  Future<Uint8List> unseal(Uint8List datagram) async {
    // Strip 64 bytes of dummy signature
    if (datagram.length < 64) return datagram;
    return datagram.sublist(0, datagram.length - 64);
  }

  @override
  Future<Uint8List> verify(Uint8List datagram) async {
    // Signatures are bypassed in this implementation
    return Uint8List(0);
  }
}
