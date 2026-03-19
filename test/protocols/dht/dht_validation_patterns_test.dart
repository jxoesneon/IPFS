// test/protocols/dht/dht_validation_patterns_test.dart
import 'package:test/test.dart';

/// Tests for DHTHandler validation regex patterns.
///
/// Since DHTHandler requires complex RouterInterface and NetworkHandler for
/// full initialization, we test the validation logic patterns directly.
///
/// These patterns match what DHTHandler.isValidCID, isValidPeerID, and
/// extractCIDFromResponse use internally.
void main() {
  group('DHT Validation Patterns', () {
    // Pattern used by isValidCID and isValidPeerID
    final alphanumericPattern = RegExp(r'^[a-zA-Z0-9]+$');

    // Pattern used by extractCIDFromResponse for Qm-style CIDs
    final qmCIDPattern = RegExp(r'Qm[1-9A-HJ-NP-Za-km-z]{44}');

    group('Alphanumeric Pattern (CID/PeerID validation)', () {
      test('matches valid alphanumeric strings', () {
        expect(alphanumericPattern.hasMatch('QmTest'), isTrue);
        expect(alphanumericPattern.hasMatch('12D3KooWTest'), isTrue);
        expect(alphanumericPattern.hasMatch('bafybeig'), isTrue);
        expect(alphanumericPattern.hasMatch('abc123XYZ'), isTrue);
      });

      test('rejects empty strings', () {
        expect(alphanumericPattern.hasMatch(''), isFalse);
      });

      test('rejects strings with special characters', () {
        expect(alphanumericPattern.hasMatch('test!'), isFalse);
        expect(alphanumericPattern.hasMatch('test@test'), isFalse);
        expect(alphanumericPattern.hasMatch('test#123'), isFalse);
        expect(alphanumericPattern.hasMatch('test space'), isFalse);
      });

      test('rejects strings with only whitespace', () {
        expect(alphanumericPattern.hasMatch('   '), isFalse);
        expect(alphanumericPattern.hasMatch('\t'), isFalse);
        expect(alphanumericPattern.hasMatch('\n'), isFalse);
      });
    });

    group('Qm CID Extraction Pattern', () {
      test('extracts valid Qm-style CID from text', () {
        const text =
            'The CID is QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojGiKDPq here';
        final match = qmCIDPattern.firstMatch(text);

        expect(match, isNotNull);
        expect(match!.group(0), startsWith('Qm'));
        expect(match.group(0)!.length, equals(46)); // Qm + 44 chars
      });

      test('extracts CID from JSON response', () {
        const json =
            '{"Path": "/ipfs/QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojGiKDPq/file"}';
        final match = qmCIDPattern.firstMatch(json);

        expect(match, isNotNull);
        expect(
          match!.group(0),
          equals('QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojGiKDPq'),
        );
      });

      test('returns null when no CID present', () {
        const text = 'No CID here, just regular text';
        final match = qmCIDPattern.firstMatch(text);

        expect(match, isNull);
      });

      test('extracts first CID when multiple present', () {
        const text =
            'CID1: QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojGiKDPq and CID2: QmTest1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZabcd';
        final match = qmCIDPattern.firstMatch(text);

        expect(match, isNotNull);
        expect(
          match!.group(0),
          equals('QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojGiKDPq'),
        );
      });
    });

    group('Integration with Actual DHT Patterns', () {
      test('validates typical CID formats work with alphanumeric pattern', () {
        // CIDv0 (Qm-based)
        expect(
          'QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojGiKDPq'.isNotEmpty &&
              alphanumericPattern.hasMatch(
                'QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojGiKDPq',
              ),
          isTrue,
        );

        // CIDv1 (bafy-based)
        expect(
          'bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi'
                  .isNotEmpty &&
              alphanumericPattern.hasMatch(
                'bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi',
              ),
          isTrue,
        );
      });

      test(
        'validates typical PeerID formats work with alphanumeric pattern',
        () {
          // Qm-style peer ID
          expect(
            'QmPeer123ABC'.isNotEmpty &&
                alphanumericPattern.hasMatch('QmPeer123ABC'),
            isTrue,
          );

          // 12D3-style peer ID
          expect(
            '12D3KooWTest'.isNotEmpty &&
                alphanumericPattern.hasMatch('12D3KooWTest'),
            isTrue,
          );
        },
      );

      test('rejects invalid CID/PeerID formats', () {
        expect(''.isNotEmpty, isFalse); // Empty fails isEmpty check
        expect(alphanumericPattern.hasMatch('invalid!@#'), isFalse);
        expect(alphanumericPattern.hasMatch('has spaces'), isFalse);
        expect(
          alphanumericPattern.hasMatch('/ipfs/QmTest'),
          isFalse,
        ); // Has slashes
      });
    });
  });
}
