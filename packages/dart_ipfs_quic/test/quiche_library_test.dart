import 'package:dart_ipfs_quic/dart_ipfs_quic.dart';
import 'package:test/test.dart';

void main() {
  final lib = QuicheLibrary.probe();

  group('QuicheLibrary', () {
    test('probes the native quiche library', () {
      // The library may not be present on all platforms / CI images.
      // When present, it must report a version; when absent, the probe must
      // report a non-null error explaining why.
      if (lib.isAvailable) {
        expect(lib.version, isNotNull);
        expect(lib.version, contains('.'));
      } else {
        expect(lib.error, isNotNull);
      }
    });

    test('config can be created and disposed', () {
      if (!lib.isAvailable) {
        markTestSkipped('Native quiche library not available: ${lib.error}');
      }
      final config = QuicheConfig()..applyDefaults();
      addTearDown(config.dispose);
      expect(config.pointer, isNotNull);
    },
        skip: !lib.isAvailable
            ? 'Native quiche library not available: ${lib.error}'
            : false);
  });
}
