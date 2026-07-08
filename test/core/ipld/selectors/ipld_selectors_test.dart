// test/core/ipld/selectors/ipld_selectors_test.dart
//
// Tests for the official IPLD selector vocabulary and executor.

// ignore_for_file: directives_ordering, prefer_const_constructors

import 'dart:io';

import 'package:test/test.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/errors/ipld_errors.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipld_handler.dart';
import 'package:dart_ipfs/src/core/ipld/selectors/ipld_selector.dart' as ipld;
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';

void main() {
  late Directory tempDir;
  late BlockStore blockStore;
  late IPLDHandler handler;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('ipld_selectors_test');
    blockStore = BlockStore(path: tempDir.path);
    await blockStore.start();
    handler = IPLDHandler(IPFSConfig(), blockStore);
  });

  tearDown(() async {
    await blockStore.stop();
    await tempDir.delete(recursive: true);
  });

  Future<CID> putBlock(dynamic data, {String codec = 'dag-cbor'}) async {
    final block = await handler.put(data, codec: codec);
    return block.cid;
  }

  IPLDNode mapNode(Map<String, IPLDNode> entries) {
    final map = IPLDMap();
    for (final entry in entries.entries) {
      map.entries.add(
        MapEntry()
          ..key = entry.key
          ..value = entry.value,
      );
    }
    return IPLDNode()
      ..kind = Kind.MAP
      ..mapValue = map;
  }

  IPLDNode emptyMap() => mapNode({});

  IPLDNode stringNode(String value) => IPLDNode()
    ..kind = Kind.STRING
    ..stringValue = value;

  group('Selector parsing', () {
    test('parses matcher', () {
      final selector = ipld.parseSelector(const ipld.Matcher().toNode());
      expect(selector, isA<ipld.Matcher>());
    });

    test('parses exploreAll', () {
      final node = ipld.ExploreAll(next: const ipld.Matcher()).toNode();
      final selector = ipld.parseSelector(node) as ipld.ExploreAll;
      expect(selector.next, isA<ipld.Matcher>());
    });

    test('parses exploreFields', () {
      final node = ipld.ExploreFields(
        fields: {
          'a': const ipld.Matcher(),
          'b': ipld.ExploreAll(next: const ipld.Matcher()),
        },
      ).toNode();
      final selector = ipld.parseSelector(node) as ipld.ExploreFields;
      expect(selector.fields.keys, unorderedEquals(['a', 'b']));
      expect(selector.fields['a'], isA<ipld.Matcher>());
      expect(selector.fields['b'], isA<ipld.ExploreAll>());
    });

    test('parses exploreIndex', () {
      final node = ipld.ExploreIndex(
        index: 2,
        next: const ipld.Matcher(),
      ).toNode();
      final selector = ipld.parseSelector(node) as ipld.ExploreIndex;
      expect(selector.index, 2);
      expect(selector.next, isA<ipld.Matcher>());
    });

    test('parses exploreRange', () {
      final node = ipld.ExploreRange(
        start: 1,
        end: 4,
        next: const ipld.Matcher(),
      ).toNode();
      final selector = ipld.parseSelector(node) as ipld.ExploreRange;
      expect(selector.start, 1);
      expect(selector.end, 4);
    });

    test('parses exploreRecursive', () {
      final node = ipld.ExploreRecursive(
        limit: const ipld.DepthRecursionLimit(3),
        sequence: ipld.ExploreAll(next: const ipld.ExploreRecursiveEdge()),
      ).toNode();
      final selector = ipld.parseSelector(node) as ipld.ExploreRecursive;
      expect(selector.limit, isA<ipld.DepthRecursionLimit>());
      expect((selector.limit as ipld.DepthRecursionLimit).depth, 3);
      expect(selector.sequence, isA<ipld.ExploreAll>());
    });

    test('parses exploreUnion', () {
      final node = ipld.ExploreUnion(
        members: [
          const ipld.Matcher(),
          ipld.ExploreAll(next: const ipld.Matcher()),
        ],
      ).toNode();
      final selector = ipld.parseSelector(node) as ipld.ExploreUnion;
      expect(selector.members, hasLength(2));
    });

    test('parses exploreInterpretAs', () {
      final node = ipld.ExploreInterpretAs(
        adl: 'sha2-256-trunc254-augmented-hashmap',
        next: const ipld.Matcher(),
      ).toNode();
      final selector = ipld.parseSelector(node) as ipld.ExploreInterpretAs;
      expect(selector.adl, 'sha2-256-trunc254-augmented-hashmap');
    });

    test('parses exploreConditional', () {
      final node = ipld.ExploreConditional(
        condition: const ipld.Matcher(),
        next: ipld.ExploreAll(next: const ipld.Matcher()),
      ).toNode();
      final selector = ipld.parseSelector(node) as ipld.ExploreConditional;
      expect(selector.condition, isA<ipld.Matcher>());
      expect(selector.next, isA<ipld.ExploreAll>());
    });

    test('rejects unknown selector keys', () {
      final node = mapNode({'unknownSelector': emptyMap()});
      expect(
        () => ipld.parseSelector(node),
        throwsA(isA<ipld.SelectorParseError>()),
      );
    });

    test('rejects missing required fields', () {
      final node = mapNode({'exploreAll': emptyMap()});
      expect(
        () => ipld.parseSelector(node),
        throwsA(isA<ipld.SelectorParseError>()),
      );
    });

    test('rejects malformed field types', () {
      final bad = mapNode({
        'exploreIndex': mapNode({
          'index': stringNode('not-an-int'),
          'next': const ipld.Matcher().toNode(),
        }),
      });
      expect(
        () => ipld.parseSelector(bad),
        throwsA(isA<ipld.SelectorParseError>()),
      );
    });

    test('rejects multi-key selector maps', () {
      final node = IPLDNode()
        ..kind = Kind.MAP
        ..mapValue = (IPLDMap()
          ..entries.addAll([
            MapEntry()
              ..key = 'matcher'
              ..value = emptyMap(),
            MapEntry()
              ..key = 'exploreAll'
              ..value = emptyMap(),
          ]));
      expect(
        () => ipld.parseSelector(node),
        throwsA(isA<ipld.SelectorParseError>()),
      );
    });
  });

  group('Selector serialization', () {
    test('round-trips through DAG-CBOR', () async {
      final original = ipld.ExploreRecursive(
        limit: const ipld.DepthRecursionLimit(3),
        sequence: ipld.ExploreAll(next: const ipld.ExploreRecursiveEdge()),
      );
      final bytes = await ipld.encodeSelectorDagCbor(original);
      final decoded = await ipld.decodeSelectorDagCbor(bytes);
      expect(decoded, equals(original));
    });

    test('round-trips through DAG-JSON', () async {
      final original = ipld.ExploreFields(
        fields: {
          'a': const ipld.Matcher(),
          'b': ipld.ExploreIndex(index: 1, next: const ipld.Matcher()),
        },
      );
      final bytes = await ipld.encodeSelectorDagJson(original);
      final decoded = await ipld.decodeSelectorDagJson(bytes);
      expect(decoded, equals(original));
    });

    test('decodeSelectorBytes detects DAG-JSON', () async {
      final selector = const ipld.Matcher();
      final bytes = await ipld.encodeSelectorDagJson(selector);
      final decoded = await ipld.decodeSelectorBytes(bytes);
      expect(decoded, isA<ipld.Matcher>());
    });

    test('decodeSelectorBytes detects DAG-CBOR', () async {
      final selector = const ipld.Matcher();
      final bytes = await ipld.encodeSelectorDagCbor(selector);
      final decoded = await ipld.decodeSelectorBytes(bytes);
      expect(decoded, isA<ipld.Matcher>());
    });
  });

  group('Selector execution', () {
    test('matcher returns the root node', () async {
      final cid = await putBlock({'hello': 'world'});
      final results = await handler
          .executeSelectorStream(cid, const ipld.Matcher())
          .toList();
      expect(results, hasLength(1));
      expect(results.first.cid.toString(), cid.toString());
      expect(results.first.node.kind, Kind.MAP);
    });

    test('exploreAll traverses map children and follows links', () async {
      final childCid = await putBlock({'value': 42});
      final rootCid = await putBlock({'child': childCid, 'other': 'x'});

      final results = await handler
          .executeSelectorStream(
            rootCid,
            ipld.ExploreAll(next: const ipld.Matcher()),
          )
          .toList();

      final cids = results.map((r) => r.cid.toString()).toSet();
      expect(cids, contains(childCid.toString()));
      // The 'other' child is a plain value, so it is reported against the root CID.
      expect(cids, contains(rootCid.toString()));
    });

    test('exploreFields traverses only named fields', () async {
      final childCid = await putBlock({'value': 42});
      final rootCid = await putBlock({'a': childCid, 'b': 'ignored'});

      final results = await handler
          .executeSelectorStream(
            rootCid,
            ipld.ExploreFields(fields: {'a': const ipld.Matcher()}),
          )
          .toList();

      expect(results, hasLength(1));
      expect(results.first.cid.toString(), childCid.toString());
    });

    test('exploreIndex and exploreRange traverse list indices', () async {
      final items = [
        await putBlock({'n': 0}),
        await putBlock({'n': 1}),
        await putBlock({'n': 2}),
      ];
      final rootCid = await putBlock({'items': items});

      final indexResults = await handler
          .executeSelectorStream(
            rootCid,
            ipld.ExploreFields(
              fields: {
                'items': ipld.ExploreIndex(
                  index: 1,
                  next: const ipld.Matcher(),
                ),
              },
            ),
          )
          .toList();
      expect(indexResults, hasLength(1));
      expect(indexResults.first.cid.toString(), items[1].toString());

      final rangeResults = await handler
          .executeSelectorStream(
            rootCid,
            ipld.ExploreFields(
              fields: {
                'items': ipld.ExploreRange(
                  start: 0,
                  end: 2,
                  next: const ipld.Matcher(),
                ),
              },
            ),
          )
          .toList();
      expect(rangeResults, hasLength(2));
    });

    test('exploreUnion applies all members', () async {
      final a = await putBlock({'k': 'a'});
      final b = await putBlock({'k': 'b'});
      final rootCid = await putBlock({'a': a, 'b': b});

      final results = await handler
          .executeSelectorStream(
            rootCid,
            ipld.ExploreUnion(
              members: [
                ipld.ExploreFields(fields: {'a': const ipld.Matcher()}),
                ipld.ExploreFields(fields: {'b': const ipld.Matcher()}),
              ],
            ),
          )
          .toList();
      expect(results, hasLength(2));
    });

    test('exploreRecursive respects depth limit', () async {
      // root -> child -> grandchild
      final grandchild = await putBlock({'level': 2});
      final child = await putBlock({'next': grandchild});
      final root = await putBlock({'next': child});

      final selector = ipld.ExploreRecursive(
        limit: const ipld.DepthRecursionLimit(2),
        sequence: ipld.ExploreUnion(
          members: [
            const ipld.Matcher(),
            ipld.ExploreAll(next: const ipld.ExploreRecursiveEdge()),
          ],
        ),
      );

      final results = await handler
          .executeSelectorStream(root, selector, includePath: true)
          .toList();

      // With depth 2 we should reach the grandchild but not traverse beyond it.
      final paths = results.map((r) => r.path).toList();
      expect(paths, contains(''));
      expect(paths, contains('next'));
      expect(paths, contains('next/next'));
      expect(paths, isNot(contains('next/next/next')));
    });

    test(
      'exploreConditional applies next only when condition matches',
      () async {
        final rootCid = await putBlock({'type': 'file', 'data': 'payload'});

        final results = await handler
            .executeSelectorStream(
              rootCid,
              ipld.ExploreConditional(
                condition: ipld.ExploreFields(
                  fields: {'type': const ipld.Matcher()},
                ),
                next: ipld.ExploreFields(
                  fields: {'data': const ipld.Matcher()},
                ),
              ),
            )
            .toList();

        expect(results, hasLength(1));
        expect(results.first.node.stringValue, 'payload');
      },
    );

    test('exploreInterpretAs passes through for recognized ADL', () async {
      final rootCid = await putBlock({'value': 1});
      final results = await handler
          .executeSelectorStream(
            rootCid,
            ipld.ExploreInterpretAs(
              adl: 'sha2-256-trunc254-augmented-hashmap',
              next: const ipld.Matcher(),
            ),
          )
          .toList();
      expect(results, hasLength(1));
    });

    test('exploreInterpretAs rejects unknown ADL', () async {
      final rootCid = await putBlock({'value': 1});
      await expectLater(
        handler
            .executeSelectorStream(
              rootCid,
              ipld.ExploreInterpretAs(
                adl: 'unknown-adl',
                next: const ipld.Matcher(),
              ),
            )
            .toList(),
        throwsA(isA<IPLDError>()),
      );
    });

    test('includePath escapes / and ~ per RFC 6901', () async {
      final rootCid = await putBlock({
        'a/b~c': {'nested': 'value'},
      });

      final results = await handler
          .executeSelectorStream(
            rootCid,
            ipld.ExploreAll(
              next: ipld.ExploreUnion(
                members: [
                  const ipld.Matcher(),
                  ipld.ExploreAll(next: const ipld.Matcher()),
                ],
              ),
            ),
            includePath: true,
          )
          .toList();

      final paths = results.map((r) => r.path).toSet();
      expect(paths, contains('a~1b~0c'));
      expect(paths, contains('a~1b~0c/nested'));
    });
  });

  group('Budget enforcement', () {
    test('maxDepth stops traversal', () async {
      final child = await putBlock({'leaf': true});
      final root = await putBlock({'child': child});

      await expectLater(
        handler
            .executeSelectorStream(
              root,
              ipld.ExploreAll(next: const ipld.Matcher()),
              maxDepth: 0,
            )
            .toList(),
        throwsA(isA<ipld.SelectorBudgetExceeded>()),
      );
    });

    test('maxNodes stops traversal', () async {
      final child = await putBlock({'leaf': true});
      final root = await putBlock({'child': child});

      await expectLater(
        handler
            .executeSelectorStream(
              root,
              ipld.ExploreAll(next: const ipld.Matcher()),
              maxNodes: 1,
            )
            .toList(),
        throwsA(isA<ipld.SelectorBudgetExceeded>()),
      );
    });
  });

  group('Visited set / diamond DAG', () {
    test('does not revisit a shared descendant', () async {
      // root -> a -> shared
      // root -> b -> shared
      final shared = await putBlock({'shared': true});
      final a = await putBlock({'to': shared});
      final b = await putBlock({'to': shared});
      final root = await putBlock({'a': a, 'b': b});

      final results = await handler
          .executeSelectorStream(
            root,
            ipld.ExploreAll(next: ipld.ExploreAll(next: const ipld.Matcher())),
          )
          .toList();

      // Without a visited set the shared block would be reported twice.
      final sharedCount = results
          .where((r) => r.cid.toString() == shared.toString())
          .length;
      expect(sharedCount, 1);
    });
  });
}
