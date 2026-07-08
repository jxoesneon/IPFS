// tool/compile_cli.dart
//
// Helper script that compiles the dart_ipfs CLI into a native AOT executable
// for the current platform. The resulting binary is copied into the runtime
// Docker image by `Dockerfile`.
//
// Native dependency note:
//   The `pubspec.yaml` declares `sodium: ^4.0.2+1`, which wraps the native
//   `libsodium` library. `libsodium` is a C library that requires glibc at
//   runtime and cannot be bundled into a static Dart AOT executable without
//   deliberate static linking.
//
//   Therefore, the default Docker runtime image uses
//   `cgr.dev/chainguard/glibc-dynamic` (hardened glibc, no shell, no package
//   manager). The dynamic linker inside the runtime must be able to resolve
//   `libsodium.so.23` (or `libsodium.so.26` on newer distributions).
//
//   Known library paths on common glibc base images:
//     - Debian / Ubuntu: `/usr/lib/x86_64-linux-gnu/libsodium.so.23`
//     - Chainguard glibc-dynamic: `/usr/lib/libsodium.so.23`
//
//   The Dockerfile copies the `libsodium.so*` wildcard from the Debian builder
//   stage into the runtime image at `/usr/lib/` so the dynamic linker can resolve
//   the soname without a package manager or shell.
//
//   When running outside of the Chainguard image, set the library search path
//   if needed, e.g.:
//     LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu ./build/ipfs version
//
// ignore_for_file: avoid_print

import 'dart:io';

const String _defaultOutput = 'build/ipfs';

Future<void> main(List<String> args) async {
  final output = args.isNotEmpty ? args.first : _defaultOutput;
  final entrypoint = 'bin/ipfs.dart';

  print('Compiling dart_ipfs CLI ...');
  print('  entrypoint: $entrypoint');
  print('  output:     $output');
  print('');
  print('Runtime dependency: libsodium');
  print(
    '  glibc dynamic base image (default): cgr.dev/chainguard/glibc-dynamic',
  );
  print('  expected library soname:            libsodium.so.23');
  print(
    '  common Debian path:                 /usr/lib/x86_64-linux-gnu/libsodium.so.23',
  );
  print('  common Chainguard path:             /usr/lib/libsodium.so.23');
  print('');

  final result = await Process.run('dart', [
    'compile',
    'exe',
    entrypoint,
    '-o',
    output,
    '--verbosity=info',
  ], runInShell: true);

  stdout.write(result.stdout);
  stderr.write(result.stderr);

  if (result.exitCode != 0) {
    exit(result.exitCode);
  }

  print('');
  print('Binary written to: $output');
  print('Verify library resolution with:');
  print('  ldd $output | grep sodium');
}
