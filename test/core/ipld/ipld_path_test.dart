// test/core/ipld/ipld_path_test.dart
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/ipld/path/ipld_path_handler.dart';
import 'package:test/test.dart';

void main() {
  group('IPLDPathHandler', () {
    const validCidString =
        'QmXg9Pp2ytZ14xgmQjYEiHjVjMFXzCVVEcRTWJBmLgR39V'; // A valid CIDv0

    group('parsePath', () {
      test('parses valid IPFS path with just CID', () {
        final (namespace, cid, remaining) = IPLDPathHandler.parsePath(
          '/ipfs/$validCidString',
        );
        expect(namespace, 'ipfs');
        expect(
          cid.encode(),
          validCidString,
        ); // Compare encoded string as CID object might vary
        expect(remaining, isNull);
      });

      test('parses valid IPFS path with subpath', () {
        final (namespace, cid, remaining) = IPLDPathHandler.parsePath(
          '/ipfs/$validCidString/folder/file.txt',
        );
        expect(namespace, 'ipfs');
        expect(cid.encode(), validCidString);
        expect(remaining, 'folder/file.txt');
      });

      test('parses valid IPLD path', () {
        final (namespace, cid, remaining) = IPLDPathHandler.parsePath(
          '/ipld/$validCidString',
        );
        expect(namespace, 'ipld');
        expect(cid.encode(), validCidString);
        expect(remaining, isNull);
      });

      test('parses valid IPNS path', () {
        // modifying CID handling might be needed if IPNS uses PeerIDs that aren't strict CIDs in this parser?
        // The parser calls CID.decode, so likely IPNS keys are treated as CIDs here or expected to be CIDs.
        // Let's assume standard CID for now.
        final (namespace, cid, remaining) = IPLDPathHandler.parsePath(
          '/ipns/$validCidString',
        );
        expect(namespace, 'ipns');
        expect(cid.encode(), validCidString);
      });

      test('throws IPLDPathError on missing leading slash', () {
        expect(
          () => IPLDPathHandler.parsePath('ipfs/$validCidString'),
          throwsA(isA<IPLDPathError>()),
        );
      });

      test('throws IPLDPathError on invalid namespace', () {
        expect(
          () => IPLDPathHandler.parsePath('/invalid/$validCidString'),
          throwsA(isA<IPLDPathError>()),
        );
      });

      test('throws IPLDPathError on invalid CID', () {
        expect(
          () => IPLDPathHandler.parsePath('/ipfs/not-a-cid'),
          throwsA(isA<IPLDPathError>()),
        );
      });

      test('throws IPLDPathError on empty path parts', () {
        // e.g. just "/" or empty
        // path "/" split is ["", ""], filtered to empty
        expect(
          () => IPLDPathHandler.parsePath('/'),
          throwsA(isA<IPLDPathError>()),
        );
      });
    });

    group('normalizePath', () {
      test('removes duplicate slashes', () {
        expect(
          IPLDPathHandler.normalizePath('//ipfs///$validCidString//path'),
          '/ipfs/$validCidString/path',
        );
      });

      test('removes trailing slash', () {
        expect(
          IPLDPathHandler.normalizePath('/ipfs/$validCidString/'),
          '/ipfs/$validCidString',
        );
      });

      test('preserves root slash', () {
        expect(IPLDPathHandler.normalizePath('/'), '/');
      });

      test('handles already clean path', () {
        expect(
          IPLDPathHandler.normalizePath('/ipfs/$validCidString'),
          '/ipfs/$validCidString',
        );
      });
    });
  });
}
