# dart_ipfs_quic

Native QUIC transport foundation for `dart_ipfs`, built on the Cloudflare
[quiche](https://github.com/cloudflare/quiche) C API via Dart FFI.

## Status

This is a **foundation package**. It provides:

- Hand-written FFI bindings to the quiche C API (`lib/src/generated/`).
- A runtime library loader (`QuicheLibrary.probe()`).
- Dart wrappers for quiche config and connection objects.
- Unit tests verifying the native library can be loaded and configured.

A full libp2p QUIC transport (UDP I/O loop, `package:ipfs_libp2p` `Transport`
wrapper, libp2p TLS 1.3 certificate handshake) is planned per
[`doc/specs/QUIC_TRANSPORT_RFC.md`](../../doc/specs/QUIC_TRANSPORT_RFC.md).

## Building the Native Library

### Windows

```powershell
$env:PATH = "C:\path\to\nasm;$env:PATH"
git clone --branch 0.23.0 --recursive https://github.com/cloudflare/quiche.git
cd quiche
cargo build --package quiche --release --features ffi
copy target\release\quiche.dll ..\packages\dart_ipfs_quic\native\quiche.dll
```

### Linux / macOS

```bash
git clone --branch 0.23.0 --recursive https://github.com/cloudflare/quiche.git
cd quiche
cargo build --package quiche --release --features ffi
cp target/release/libquiche.* ../packages/dart_ipfs_quic/native/
```

## Usage

```dart
import 'package:dart_ipfs_quic/dart_ipfs_quic.dart';

void main() {
  final lib = QuicheLibrary.probe();
  if (!lib.isAvailable) {
    print('quiche library not available: ${lib.error}');
    return;
  }
  print('quiche ${lib.version} loaded');

  final config = QuicheConfig()..applyDefaults();
  try {
    // Use config to create connections...
  } finally {
    config.dispose();
  }
}
```

## License

MIT — see the root `LICENSE` file. The quiche native library is BSD-2-Clause.
