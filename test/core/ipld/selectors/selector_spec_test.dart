// test/core/ipld/selectors/selector_spec_test.dart
//
// Conformance tests for the official IPLD selector vocabulary and its
// DAG-CBOR wire form (compact keyed representation, per
// https://ipld.io/specs/selectors/ and go-ipld-prime).

// ignore_for_file: directives_ordering, prefer_const_constructors

import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:fixnum/fixnum.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipld_handler.dart';
import 'package:dart_ipfs/src/core/ipld/codecs/standard_codecs.dart';
import 'package:dart_ipfs/src/core/ipld/selectors/ipld_selector.dart' as ipld;
import 'package:dart_ipfs/src/proto/generated/graphsync/graphsync.pb.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';

String hexOf(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  late Directory tempDir;
  late BlockStore blockStore;
  late IPLDHandler handler;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('selector_spec_test');
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

  IPLDNode intNode(int v) => IPLDNode()
    ..kind = Kind.INTEGER
    ..intValue = Int64(v);

  group('Compact schema encoding', () {
    test('matcher encodes as {"." : {}}', () async {
      final bytes = await ipld.encodeSelectorDagCbor(const ipld.Matcher());
      expect(hexOf(bytes), 'a1612ea0');
    });

    test('explore-all edge selector uses compact keys', () async {
      final selector = ipld.ExploreRecursive(
        limit: const ipld.DepthRecursionLimit(32),
        sequence: ipld.ExploreAll(next: const ipld.ExploreRecursiveEdge()),
      );
      final bytes = await ipld.encodeSelectorDagCbor(selector);
      // {"R": {"l": {"depth": 32}, ":>": {"a": {">": {"@": {}}}}}
      expect(
        hexOf(bytes),
        'a1'
        '6152'
        'a2'
        '616c' 'a1' '656465707468' '1820'
        '623a3e' 'a1' '6161' 'a1' '613e' 'a1' '6140' 'a0',
      );
    });

    test('union serializes as a bare list under "|"', () async {
      final bytes = await ipld.encodeSelectorDagCbor(
        ipld.ExploreUnion(members: [const ipld.Matcher()]),
      );
      // {"|": [{".": {}}]}
      expect(hexOf(bytes), 'a1617c81a1612ea0');
    });

    test('index/range/interpretAs/conditional use renamed fields', () async {
      Future<String> hex(ipld.Selector s) async =>
          hexOf(await ipld.encodeSelectorDagCbor(s));

      // {"i": {">": {".": {}}, "i": 2}} — canonical dag-cbor sorts map keys
      // by (length, bytes): ">" (0x3e) precedes "i" (0x69).
      expect(
        await hex(ipld.ExploreIndex(index: 2, next: const ipld.Matcher())),
        'a16169a2613ea1612ea0616902',
      );
      // {"r": {"$": 5, ">": {".": {}}, "^": 0}} — key order "$", ">", "^".
      expect(
        await hex(
          ipld.ExploreRange(start: 0, end: 5, next: const ipld.Matcher()),
        ),
        'a16172a3612405613ea1612ea0615e00',
      );
      // {"~": {">": {".": {}}, "as": "hamt"}} — ">" (1 char) before "as".
      expect(
        await hex(
          ipld.ExploreInterpretAs(adl: 'hamt', next: const ipld.Matcher()),
        ),
        'a1617ea2613ea1612ea06261736468616d74',
      );
      // {"&": {"&": {"hasField": "x"}, ">": {".": {}}}}
      expect(
        await hex(
          ipld.ExploreConditional(
            condition: const ipld.HasFieldCondition('x'),
            next: const ipld.Matcher(),
          ),
        ),
        'a16126a26126a1686861734669656c646178613ea1612ea0',
      );
    });

    test('matcher subset/label/index serialize', () async {
      final bytes = await ipld.encodeSelectorDagCbor(
        const ipld.Matcher(
          subset: ipld.Slice(from: 0, to: 3),
          label: 'part',
          index: 1,
        ),
      );
      final node = await DagCborCodec().decode(bytes);
      final body = node.mapValue.entries.single.value.mapValue;
      String? keyOf(MapEntry e) => e.key;
      final keys = body.entries.map(keyOf).toSet();
      expect(keys, containsAll(['subset', 'label', 'index']));
      final subset = body.entries
          .firstWhere((e) => e.key == 'subset')
          .value
          .mapValue;
      final sliceKeys = subset.entries.map(keyOf).toSet();
      expect(sliceKeys, containsAll(['[', ']']));
    });
  });

  group('DAG-CBOR round-trips', () {
    final selectors = <String, ipld.Selector>{
      'matcher': const ipld.Matcher(),
      'matcher with subset': const ipld.Matcher(
        subset: ipld.Slice(from: -2, to: 100),
        label: 'blk',
        index: 7,
        onlyIf: ipld.HasKindCondition('bytes'),
      ),
      'exploreAll': ipld.ExploreAll(next: const ipld.Matcher()),
      'exploreFields': ipld.ExploreFields(
        fields: {
          'Links': ipld.ExploreAll(next: const ipld.Matcher()),
          'Data': const ipld.Matcher(),
        },
      ),
      'exploreIndex': ipld.ExploreIndex(
        index: 3,
        next: const ipld.Matcher(),
      ),
      'exploreRange': ipld.ExploreRange(
        start: 1,
        end: 4,
        next: ipld.ExploreAll(next: const ipld.Matcher()),
      ),
      'exploreRecursive depth': ipld.ExploreRecursive(
        limit: const ipld.DepthRecursionLimit(10),
        sequence: ipld.ExploreUnion(
          members: [
            const ipld.Matcher(),
            ipld.ExploreAll(next: const ipld.ExploreRecursiveEdge()),
          ],
        ),
      ),
      'exploreRecursive none': ipld.ExploreRecursive(
        limit: const ipld.RecursionLimitNone(),
        sequence: ipld.ExploreAll(next: const ipld.ExploreRecursiveEdge()),
      ),
      'exploreUnion': ipld.ExploreUnion(
        members: [
          const ipld.Matcher(),
          ipld.ExploreAll(next: const ipld.Matcher()),
        ],
      ),
      'exploreConditional': ipld.ExploreConditional(
        condition: ipld.OrCondition([
          const ipld.HasFieldCondition('a'),
          const ipld.HasKindCondition('list'),
        ]),
        next: const ipld.Matcher(),
      ),
      'interpretAs': ipld.ExploreInterpretAs(
        adl: 'hamt',
        next: const ipld.Matcher(),
      ),
      'recursive edge': const ipld.ExploreRecursiveEdge(),
    };

    for (final entry in selectors.entries) {
      test('${entry.key} round-trips through DAG-CBOR', () async {
        final bytes = await ipld.encodeSelectorDagCbor(entry.value);
        expect(await ipld.decodeSelectorDagCbor(bytes), equals(entry.value));
      });

      test('${entry.key} round-trips through DAG-JSON', () async {
        final bytes = await ipld.encodeSelectorDagJson(entry.value);
        expect(await ipld.decodeSelectorDagJson(bytes), equals(entry.value));
      });
    }

    // The isLink condition uses the union key "/", which collides with
    // DAG-JSON's reserved link namespace, so it is exercised via DAG-CBOR.
    test('exploreRecursive with stopAt round-trips through DAG-CBOR', () async {
      final selector = ipld.ExploreRecursive(
        limit: const ipld.RecursionLimitNone(),
        stopAt: const ipld.IsLinkCondition(),
        sequence: ipld.ExploreAll(next: const ipld.ExploreRecursiveEdge()),
      );
      final bytes = await ipld.encodeSelectorDagCbor(selector);
      expect(await ipld.decodeSelectorDagCbor(bytes), equals(selector));
    });
  });

  group('Envelope and lenient decoding', () {
    test('decodes a {"selector": ...} envelope', () async {
      final selector = ipld.ExploreAll(next: const ipld.Matcher());
      final bytes = await ipld.encodeSelectorEnvelopeDagCbor(selector);
      expect(await ipld.decodeSelectorDagCbor(bytes), equals(selector));
      expect(await ipld.decodeSelectorBytes(bytes), equals(selector));
    });

    test('decodes long-form key aliases', () async {
      final node = mapNode({
        'exploreAll': mapNode({
          'next': mapNode({'matcher': mapNode({})}),
        }),
      });
      final selector = ipld.parseSelector(node);
      expect(selector, ipld.ExploreAll(next: const ipld.Matcher()));
    });

    test('decodes {"R": {"l": {"none": {}}}} as unlimited recursion', () {
      final node = mapNode({
        'R': mapNode({
          'l': mapNode({'none': mapNode({})}),
          ':>': mapNode({
            'a': mapNode({
              '>': mapNode({'@': mapNode({})}),
            }),
          }),
        }),
      });
      final selector = ipld.parseSelector(node) as ipld.ExploreRecursive;
      expect(selector.limit, isA<ipld.RecursionLimitNone>());
      expect(selector.sequence, isA<ipld.ExploreAll>());
    });

    test('rejects a limit without depth or none', () {
      final node = mapNode({
        'R': mapNode({
          'l': mapNode({'bogus': intNode(1)}),
          ':>': mapNode({'@': mapNode({})}),
        }),
      });
      expect(() => ipld.parseSelector(node), throwsA(anything));
    });
  });

  group('Conditions', () {
    IPLDNode mapWithField() => mapNode({'x': intNode(1)});

    test('hasField / hasKind / isLink evaluate correctly', () {
      expect(
        const ipld.HasFieldCondition('x').matches(mapWithField()),
        isTrue,
      );
      expect(
        const ipld.HasFieldCondition('y').matches(mapWithField()),
        isFalse,
      );
      expect(
        const ipld.HasKindCondition('map').matches(mapWithField()),
        isTrue,
      );
      expect(
        const ipld.HasKindCondition('list').matches(mapWithField()),
        isFalse,
      );
      expect(
        const ipld.IsLinkCondition().matches(mapWithField()),
        isFalse,
      );
    });

    test('hasValue / greaterThan / lessThan / and / or', () {
      final five = intNode(5);
      expect(ipld.HasValueCondition(intNode(5)).matches(five), isTrue);
      expect(ipld.HasValueCondition(intNode(6)).matches(five), isFalse);
      expect(ipld.GreaterThanCondition(4).matches(five), isTrue);
      expect(ipld.GreaterThanCondition(5).matches(five), isFalse);
      expect(ipld.LessThanCondition(6).matches(five), isTrue);
      expect(
        ipld.AndCondition([
          ipld.GreaterThanCondition(1),
          ipld.LessThanCondition(10),
        ]).matches(five),
        isTrue,
      );
      expect(
        ipld.OrCondition([
          ipld.LessThanCondition(1),
          ipld.GreaterThanCondition(10),
        ]).matches(five),
        isFalse,
      );
    });

    test('condition round-trips through dag-cbor', () async {
      final cond = ipld.AndCondition([
        const ipld.HasFieldCondition('type'),
        ipld.GreaterThanCondition(3),
      ]);
      final bytes = await DagCborCodec().encode(cond.toNode());
      final decoded = ipld.parseCondition(await DagCborCodec().decode(bytes));
      expect(decoded, equals(cond));
    });
  });

  group('Execution semantics', () {
    test('matcher onlyIf restricts the result set', () async {
      final cid = await putBlock({'kind': 'file'});
      final matches = await handler
          .executeSelectorStream(
            cid,
            const ipld.Matcher(onlyIf: ipld.HasFieldCondition('kind')),
          )
          .toList();
      expect(matches, hasLength(1));

      final misses = await handler
          .executeSelectorStream(
            cid,
            const ipld.Matcher(onlyIf: ipld.HasFieldCondition('missing')),
          )
          .toList();
      expect(misses, isEmpty);
    });

    test('matcher subset slices strings and bytes', () async {
      final strCid = await putBlock('hello world');
      final results = await handler
          .executeSelectorStream(
            strCid,
            const ipld.Matcher(subset: ipld.Slice(from: 0, to: 5)),
          )
          .toList();
      expect(results, hasLength(1));
      expect(results.first.node.stringValue, 'hello');

      // Out-of-range slices do not match.
      final noMatch = await handler
          .executeSelectorStream(
            strCid,
            const ipld.Matcher(subset: ipld.Slice(from: 50, to: 60)),
          )
          .toList();
      expect(noMatch, isEmpty);

      // Negative offsets count from the end.
      final tail = await handler
          .executeSelectorStream(
            strCid,
            const ipld.Matcher(subset: ipld.Slice(from: -5, to: 100)),
          )
          .toList();
      expect(tail.first.node.stringValue, 'world');
    });

    test('matcher label and index annotate results', () async {
      final cid = await putBlock([10, 20, 30]);
      final results = await handler
          .executeSelectorStream(
            cid,
            ipld.ExploreIndex(
              index: 1,
              next: const ipld.Matcher(label: 'picked', index: 1),
            ),
          )
          .toList();
      expect(results, hasLength(1));
      expect(results.first.label, 'picked');
      expect(results.first.index, 1);
    });

    test('exploreRecursive stopAt excludes matching node and children',
        () async {
      final poison = await putBlock({'poison': true});
      final child = await putBlock({'next': poison, 'ok': 1});
      final root = await putBlock({'next': child});

      final selector = ipld.ExploreRecursive(
        limit: const ipld.DepthRecursionLimit(10),
        stopAt: const ipld.HasFieldCondition('poison'),
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
      final paths = results.map((r) => r.path).toSet();
      expect(paths, containsAll(['', 'next', 'next/ok']));
      // The poisoned node (and anything below it) is not visited.
      expect(paths, isNot(contains('next/next')));
      expect(paths, isNot(contains('next/next/poison')));
    });

    test('RecursionLimitNone traverses until the executor budget', () async {
      final leaf = await putBlock({'leaf': true});
      final mid = await putBlock({'next': leaf});
      final root = await putBlock({'next': mid});

      final results = await handler
          .executeSelectorStream(
            root,
            ipld.ExploreRecursive(
              limit: const ipld.RecursionLimitNone(),
              sequence: ipld.ExploreUnion(
                members: [
                  const ipld.Matcher(),
                  ipld.ExploreAll(next: const ipld.ExploreRecursiveEdge()),
                ],
              ),
            ),
            includePath: true,
          )
          .toList();

      final paths = results.map((r) => r.path).toSet();
      expect(paths, containsAll(['', 'next', 'next/next', 'next/next/leaf']));
    });
  });

  group('Graphsync request envelope', () {
    test('selector field carries compact dag-cbor and decodes back', () async {
      final selector = ipld.ExploreRecursive(
        limit: const ipld.DepthRecursionLimit(10),
        sequence: ipld.ExploreAll(next: const ipld.ExploreRecursiveEdge()),
      );
      final request = GraphsyncRequest()
        ..id = 42
        ..root = Uint8List.fromList([1, 2, 3])
        ..selector = await ipld.encodeSelectorDagCbor(selector);

      final message = GraphsyncMessage()..requests.add(request);
      final decoded = GraphsyncMessage.fromBuffer(message.writeToBuffer());

      final roundTripped = await ipld.decodeSelectorBytes(
        Uint8List.fromList(decoded.requests.first.selector),
      );
      expect(roundTripped, equals(selector));

      // The wire bytes really are the compact keyed form.
      final node = await DagCborCodec().decode(
        Uint8List.fromList(decoded.requests.first.selector),
      );
      expect(node.mapValue.entries.single.key, 'R');
    });

    test('envelope form also accepted on the request path', () async {
      final selector = const ipld.Matcher();
      final envelope = await ipld.encodeSelectorEnvelopeDagCbor(selector);
      expect(await ipld.decodeSelectorBytes(envelope), equals(selector));
    });
  });

  group('Legacy selector bigint fix', () {
    test('criteria BIG_INT decodes via [sign, magnitude] convention', () {
      // [0, 0x01, 0x00] = positive, magnitude 0x0100 = 256.
      final criteriaNode = mapNode({
        'big': IPLDNode()
          ..kind = Kind.BIG_INT
          ..bigIntValue = [0, 0x01, 0x00],
      });
      final node = mapNode({
        '.tag': IPLDNode()
          ..kind = Kind.STRING
          ..stringValue = 'SelectorType.matcher',
        'criteria': criteriaNode,
      });
      final selector = ipld.IPLDSelector.fromNode(node);
      expect(selector.criteria['big'], BigInt.from(256));
    });

    test('criteria BIG_INT decodes negative values', () {
      final criteriaNode = mapNode({
        'big': IPLDNode()
          ..kind = Kind.BIG_INT
          ..bigIntValue = [1, 0x02], // sign=1 → -2
      });
      final node = mapNode({
        '.tag': IPLDNode()
          ..kind = Kind.STRING
          ..stringValue = 'SelectorType.matcher',
        'criteria': criteriaNode,
      });
      final selector = ipld.IPLDSelector.fromNode(node);
      expect(selector.criteria['big'], BigInt.from(-2));
    });
  });
}
