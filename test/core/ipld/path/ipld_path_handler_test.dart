import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/errors/ipld_errors.dart';
import 'package:dart_ipfs/src/core/ipld/path/ipld_path_handler.dart';
import 'package:test/test.dart';

void main() {
  group('IPLDPathHandler', () {
    group('parsePath', () {
      test('throws if path does not start with /', () {
        expect(
          () => IPLDPathHandler.parsePath('invalid'),
          throwsA(isA<IPLDPathError>()),
        );
      });

      test('throws if path is empty parts', () {
        // split of "/" is empty list?
        // split('/') -> ['', ''] -> where -> [].
        expect(
          () => IPLDPathHandler.parsePath('/'),
          throwsA(isA<IPLDPathError>()),
        );
      });

      test('throws if namespace invalid', () {
        expect(
          () => IPLDPathHandler.parsePath('/invalid'),
          throwsA(isA<IPLDPathError>()),
        );
      });

      test('throws if CID invalid', () {
        expect(
          () => IPLDPathHandler.parsePath('/ipfs/notacid'),
          throwsA(isA<IPLDPathError>()),
        );
      });

      test('parses simple path', () {
        final cidStr = 'QmYwAPJzv5CZsnA6ULBXebJWvruP6P3wXhHjS2Mtc38E2z';
        final result = IPLDPathHandler.parsePath('/ipfs/$cidStr');

        expect(result.$1, equals('ipfs'));
        expect(result.$2.encode(), equals(cidStr));
        expect(result.$3, isNull);
      });

      test('parses path with segments', () {
        final cidStr = 'QmYwAPJzv5CZsnA6ULBXebJWvruP6P3wXhHjS2Mtc38E2z';
        final result = IPLDPathHandler.parsePath('/ipfs/$cidStr/a/b/c');

        expect(result.$1, equals('ipfs'));
        expect(result.$2.encode(), equals(cidStr));
        expect(result.$3, equals('a/b/c'));
      });

      test('parses subpaths with multiple slashes', () {
        final cidStr = 'QmYwAPJzv5CZsnA6ULBXebJWvruP6P3wXhHjS2Mtc38E2z';
        // split logic filters empty.
        final result = IPLDPathHandler.parsePath('/ipfs/$cidStr//a');
        expect(result.$3, equals('a'));
      });
    });

    group('normalizePath', () {
      test('removes duplicate slashes', () {
        expect(IPLDPathHandler.normalizePath('///a//b'), equals('/a/b'));
      });

      test('removes trailing slash', () {
        expect(IPLDPathHandler.normalizePath('/a/b/'), equals('/a/b'));
      });

      test('keeps root slash if only slash', () {
        expect(IPLDPathHandler.normalizePath('/'), equals('/'));
      });

      test('handles mixed', () {
        expect(IPLDPathHandler.normalizePath('/a//b//'), equals('/a/b'));
      });
    });
  });
}

