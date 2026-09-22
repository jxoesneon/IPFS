// test/public_api_exports_test.dart
import 'package:dart_ipfs/dart_ipfs.dart' as umbrella;
import 'package:test/test.dart';

/// Verifies that feature types implemented under lib/src are publicly
/// reachable through the umbrella `package:dart_ipfs/dart_ipfs.dart` library.
void main() {
  group('Public API exports', () {
    test('SelectorExecutor resolves from the umbrella', () {
      expect(umbrella.SelectorExecutor, isNotNull);
    });

    test('IPLDSchema resolves from the umbrella', () {
      expect(umbrella.IPLDSchema, isNotNull);
    });

    test('DenylistService resolves from the umbrella', () {
      expect(umbrella.DenylistService, isNotNull);
    });

    test('Reprovider resolves from the umbrella', () {
      expect(umbrella.Reprovider, isNotNull);
    });

    test('MFSManager resolves from the umbrella', () {
      expect(umbrella.MFSManager, isNotNull);
    });

    test('OTelExporter resolves from the umbrella', () {
      expect(umbrella.OTelExporter, isNotNull);
    });
  });
}
