// test/core/block/gated_block_fetcher_test.dart
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/block/gated_block_fetcher.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs_core/dart_ipfs_core.dart' show MultihashInfo;
import 'package:test/test.dart';

/// Builds a CIDv1 identity CID whose multihash digest carries [data] inline.
CID _identityCid(List<int> data, {String codec = 'raw'}) {
  final digest = Uint8List.fromList(data);
  return CID.v1(
    codec,
    MultihashInfo(
      code: 0x00,
      name: 'identity',
      digest: digest,
      size: digest.length,
    ),
  );
}

void main() {
  group('GatedBlockFetcher', () {
    test('runs the denylist gate before identity synthesis', () async {
      final cid = _identityCid([1, 2, 3]);
      var gated = false;
      var storeRead = false;
      final fetcher = GatedBlockFetcher(
        denylistGate: (c) {
          gated = true;
          throw StateError('blocked: $c');
        },
        localGet: (c) async {
          storeRead = true;
          return null;
        },
      );

      await expectLater(
        fetcher.fetch(cid.encode()),
        throwsA(isA<StateError>()),
      );
      expect(gated, isTrue);
      // The gate threw before the store was consulted.
      expect(storeRead, isFalse);
    });

    test('synthesizes identity CIDs without store or network access',
        () async {
      final data = Uint8List.fromList([9, 8, 7]);
      final cid = _identityCid(data);
      var storeRead = false;
      var networkRead = false;
      final fetcher = GatedBlockFetcher(
        localGet: (c) async {
          storeRead = true;
          return null;
        },
        wantBlock: (c) async {
          networkRead = true;
          return null;
        },
      );

      final block = await fetcher.fetch(cid.encode());
      expect(block, isNotNull);
      expect(block!.data, equals(data));
      expect(block.cid.encode(), equals(cid.encode()));
      expect(block.format, equals('raw'));
      expect(storeRead, isFalse);
      expect(networkRead, isFalse);
    });

    test('returns the local block without touching the network', () async {
      final block = await Block.fromData(
        Uint8List.fromList([1, 2, 3]),
        format: 'raw',
      );
      var networkRead = false;
      final fetcher = GatedBlockFetcher(
        localGet: (c) async => block,
        wantBlock: (c) async {
          networkRead = true;
          return null;
        },
      );

      expect(await fetcher.fetch(block.cid.encode()), same(block));
      expect(networkRead, isFalse);
    });

    test('falls back to the network and writes the block back', () async {
      final block = await Block.fromData(
        Uint8List.fromList([4, 5, 6]),
        format: 'raw',
      );
      final written = <Block>[];
      final fetcher = GatedBlockFetcher(
        localGet: (c) async => null,
        localPut: (b) async => written.add(b),
        wantBlock: (c) async => block,
      );

      expect(await fetcher.fetch(block.cid.encode()), same(block));
      expect(written, equals([block]));
    });

    test('localOnly returns null instead of hitting the network', () async {
      var networkRead = false;
      final fetcher = GatedBlockFetcher(
        localGet: (c) async => null,
        wantBlock: (c) async {
          networkRead = true;
          return null;
        },
      );

      expect(await fetcher.fetch('bafkreiwhatever', localOnly: true), isNull);
      expect(networkRead, isFalse);
    });

    test('returns null when no network fetcher is configured', () async {
      final fetcher = GatedBlockFetcher(localGet: (c) async => null);
      expect(await fetcher.fetch('bafkreiwhatever'), isNull);
    });

    test('returns null when the network fetch misses', () async {
      final fetcher = GatedBlockFetcher(
        localGet: (c) async => null,
        wantBlock: (c) async => null,
      );
      expect(await fetcher.fetch('bafkreiwhatever'), isNull);
    });

    test(
      'rereadAfterFetch prefers the stored copy over the network block',
      () async {
        final stored = await Block.fromData(
          Uint8List.fromList([1, 1, 1]),
          format: 'raw',
        );
        final network = await Block.fromData(
          Uint8List.fromList([2, 2, 2]),
          format: 'raw',
        );
        var reads = 0;
        final written = <Block>[];
        final fetcher = GatedBlockFetcher(
          localGet: (c) async => ++reads == 1 ? null : stored,
          localPut: (b) async => written.add(b),
          wantBlock: (c) async => network,
          rereadAfterFetch: true,
        );

        expect(await fetcher.fetch(stored.cid.encode()), same(stored));
        // The store already persisted the block (Bitswap write-back), so
        // the fetcher must not write it a second time.
        expect(written, isEmpty);
        expect(reads, equals(2));
      },
    );
  });
}
