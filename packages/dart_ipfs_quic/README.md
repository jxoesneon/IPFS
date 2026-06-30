# dart_ipfs_quic

Pure-Dart QUIC transport foundation for `dart_ipfs`, built on the
[quic_lib](https://github.com/jxoesneon/quic_lib) package.

## Status

This is a **foundation package**. It provides a `package:ipfs_libp2p`
-compatible `Transport` implementation that can be registered with
`Libp2pRouter` when `enableQuic` is true.

- No native DLLs or `dart:ffi` dependencies.
- Backed by the pure-Dart QUIC stack in `quic_lib`.
- Advertises `/udp/.../quic-v1` listen addresses.
- Dial and listen APIs are wired to `quic_lib`'s `Libp2pQuicTransport`.

A full Kubo/Helia-interoperable QUIC transport (complete libp2p TLS 1.3
handshake, stream multiplexing, and interop tests) is still being hardened.

## Usage

```dart
import 'package:dart_ipfs_quic/dart_ipfs_quic.dart';

void main() {
  final transport = QuicTransport();
  print('QUIC transport available: ${transport.protocols}');
  transport.dispose();
}
```

## Building

No native library build is required. `quic_lib` is pure Dart.

## License

MIT — see the root `LICENSE` file.
