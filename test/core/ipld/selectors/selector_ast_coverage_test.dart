// test/core/ipld/selectors/selector_ast_coverage_test.dart
//
// Coverage tests for the selector AST helpers: Slice resolution, condition
// parsing/equality, ipldKindName, ipldNodeEquals/ipldNodeHash, the data-model
// node helpers reached through toNode(), and the byte-slice branch of the
// executor.

// ignore_for_file: prefer_const_constructors

import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/errors/ipld_errors.dart';
import 'package:dart_ipfs/src/core/ipld/selectors/selector_ast.dart';
import 'package:dart_ipfs/src/core/ipld/selectors/selector_executor.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:dart_multihash/dart_multihash.dart';
import 'package:fixnum/fixnum.dart';
import 'package:test/test.dart' hide Matcher;

void main() {
  CID testCid([int seed = 0]) => CID.v1(
    'dag-cbor',
    Multihash.encode('sha2-256', Uint8List(32)..[0] = seed),
  );

  IPLDNode strNode(String v) => IPLDNode()
    ..kind = Kind.STRING
    ..stringValue = v;
  IPLDNode intNode(int v) => IPLDNode()
    ..kind = Kind.INTEGER
    ..intValue = Int64(v);
  IPLDNode floatNode(double v) => IPLDNode()
    ..kind = Kind.FLOAT
    ..floatValue = v;
  IPLDNode boolNode(bool v) => IPLDNode()
    ..kind = Kind.BOOL
    ..boolValue = v;
  IPLDNode nullNode() => IPLDNode()..kind = Kind.NULL;
  IPLDNode bytesNode(List<int> v) => IPLDNode()
    ..kind = Kind.BYTES
    ..bytesValue = v;
  IPLDNode bigIntNode(List<int> v) => IPLDNode()
    ..kind = Kind.BIG_INT
    ..bigIntValue = v;
  IPLDNode listNode(List<IPLDNode> values) => IPLDNode()
    ..kind = Kind.LIST
    ..listValue = (IPLDList()..values.addAll(values));
  IPLDNode mapNode(Map<String, IPLDNode> entries) {
    final map = IPLDMap();
    for (final e in entries.entries) {
      map.entries.add(
        MapEntry()
          ..key = e.key
          ..value = e.value,
      );
    }
    return IPLDNode()
      ..kind = Kind.MAP
      ..mapValue = map;
  }

  IPLDNode linkNode(CID cid) => IPLDNode()
    ..kind = Kind.LINK
    ..linkValue = (IPLDLink()
      ..version = cid.version
      ..codec = cid.codec ?? 'dag-cbor'
      ..multihash = cid.multihash.toBytes());

  group('Slice.resolve', () {
    test('negative to counts from the end of the node', () {
      expect(const Slice(from: 0, to: -1).resolve(5), equals((0, 4)));
    });

    test('overflowing to clamps to the length', () {
      expect(const Slice(from: 1, to: 100).resolve(5), equals((1, 5)));
    });

    test('negative from counts from the end and clamps at zero', () {
      expect(const Slice(from: -2, to: 5).resolve(5), equals((3, 5)));
      expect(const Slice(from: -100, to: 2).resolve(5), equals((0, 2)));
    });

    test('empty or out-of-range slices resolve to null', () {
      expect(const Slice(from: 3, to: 1).resolve(5), isNull);
      expect(const Slice(from: 5, to: 9).resolve(5), isNull);
      // A zero-width range at offset zero still resolves.
      expect(const Slice(from: 0, to: 0).resolve(5), equals((0, 0)));
    });
  });

  group('equality and hashCodes', () {
    test('Slice', () {
      expect(const Slice(from: 0, to: 1), equals(const Slice(from: 0, to: 1)));
      expect(
        const Slice(from: 0, to: 1).hashCode,
        equals(const Slice(from: 0, to: 1).hashCode),
      );
      expect(
        const Slice(from: 0, to: 1),
        isNot(equals(const Slice(from: 0, to: 2))),
      );
    });

    test('IsLinkCondition', () {
      final cid = testCid();
      expect(
        IsLinkCondition(target: cid),
        equals(IsLinkCondition(target: cid)),
      );
      expect(
        IsLinkCondition(target: cid).hashCode,
        equals(IsLinkCondition(target: cid).hashCode),
      );
      expect(const IsLinkCondition(), equals(const IsLinkCondition()));
      expect(
        IsLinkCondition(target: cid),
        isNot(equals(const IsLinkCondition())),
      );
    });

    test('HasFieldCondition', () {
      expect(
        const HasFieldCondition('x'),
        equals(const HasFieldCondition('x')),
      );
      expect(
        const HasFieldCondition('x').hashCode,
        equals(const HasFieldCondition('x').hashCode),
      );
      expect(
        const HasFieldCondition('x'),
        isNot(equals(const HasFieldCondition('y'))),
      );
    });

    test('HasValueCondition', () {
      expect(
        HasValueCondition(intNode(1)),
        equals(HasValueCondition(intNode(1))),
      );
      expect(
        HasValueCondition(intNode(1)).hashCode,
        equals(HasValueCondition(intNode(1)).hashCode),
      );
      expect(
        HasValueCondition(intNode(1)),
        isNot(equals(HasValueCondition(intNode(2)))),
      );
    });

    test('HasKindCondition', () {
      expect(
        const HasKindCondition('map'),
        equals(const HasKindCondition('map')),
      );
      expect(
        const HasKindCondition('map').hashCode,
        equals(const HasKindCondition('map').hashCode),
      );
    });

    test('GreaterThanCondition and LessThanCondition', () {
      expect(GreaterThanCondition(1), equals(GreaterThanCondition(1)));
      expect(
        GreaterThanCondition(1).hashCode,
        equals(GreaterThanCondition(1).hashCode),
      );
      expect(LessThanCondition(2), equals(LessThanCondition(2)));
      expect(
        LessThanCondition(2).hashCode,
        equals(LessThanCondition(2).hashCode),
      );
    });

    test('AndCondition and OrCondition', () {
      expect(
        AndCondition([const HasKindCondition('map')]),
        equals(AndCondition([const HasKindCondition('map')])),
      );
      expect(
        AndCondition([const HasKindCondition('map')]).hashCode,
        equals(AndCondition([const HasKindCondition('map')]).hashCode),
      );
      expect(
        OrCondition([const HasKindCondition('map')]),
        equals(OrCondition([const HasKindCondition('map')])),
      );
      expect(
        OrCondition([const HasKindCondition('map')]).hashCode,
        equals(OrCondition([const HasKindCondition('map')]).hashCode),
      );
    });

    test('Matcher and RecursionLimitNone', () {
      expect(
        const Matcher(label: 'l', index: 1),
        equals(const Matcher(label: 'l', index: 1)),
      );
      expect(
        const Matcher(label: 'l').hashCode,
        equals(const Matcher(label: 'l').hashCode),
      );
      expect(const RecursionLimitNone(), equals(const RecursionLimitNone()));
      expect(
        const RecursionLimitNone().hashCode,
        equals(const RecursionLimitNone().hashCode),
      );
    });

    test('selector classes compare equal and hash consistently', () {
      void check(Object a, Object b) {
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      }

      check(
        ExploreAll(next: const Matcher()),
        ExploreAll(next: const Matcher()),
      );
      check(
        ExploreFields(fields: {'x': const Matcher()}),
        ExploreFields(fields: {'x': const Matcher()}),
      );
      check(
        const ExploreIndex(index: 1, next: Matcher()),
        const ExploreIndex(index: 1, next: Matcher()),
      );
      check(
        const ExploreRange(start: 0, end: 2, next: Matcher()),
        const ExploreRange(start: 0, end: 2, next: Matcher()),
      );
      check(const DepthRecursionLimit(3), const DepthRecursionLimit(3));
      check(
        const ExploreRecursive(
          limit: DepthRecursionLimit(3),
          sequence: ExploreRecursiveEdge(),
          stopAt: HasKindCondition('map'),
        ),
        const ExploreRecursive(
          limit: DepthRecursionLimit(3),
          sequence: ExploreRecursiveEdge(),
          stopAt: HasKindCondition('map'),
        ),
      );
      check(const ExploreRecursiveEdge(), const ExploreRecursiveEdge());
      check(
        ExploreUnion(members: [const Matcher()]),
        ExploreUnion(members: [const Matcher()]),
      );
      check(
        const ExploreInterpretAs(adl: 'hamt', next: Matcher()),
        const ExploreInterpretAs(adl: 'hamt', next: Matcher()),
      );
      check(
        const ExploreConditional(
          condition: HasFieldCondition('f'),
          next: Matcher(),
        ),
        const ExploreConditional(
          condition: HasFieldCondition('f'),
          next: Matcher(),
        ),
      );

      // Inequality on differing fields.
      expect(
        ExploreAll(next: const Matcher()),
        isNot(equals(ExploreAll(next: ExploreRecursiveEdge()))),
      );
      expect(
        ExploreFields(fields: {'x': const Matcher()}),
        isNot(equals(ExploreFields(fields: {'y': const Matcher()}))),
      );
      expect(
        const ExploreIndex(index: 1, next: Matcher()),
        isNot(equals(const ExploreIndex(index: 2, next: Matcher()))),
      );
      expect(
        const ExploreRange(start: 0, end: 2, next: Matcher()),
        isNot(equals(const ExploreRange(start: 0, end: 3, next: Matcher()))),
      );
      expect(
        const DepthRecursionLimit(3),
        isNot(equals(const DepthRecursionLimit(4))),
      );
      expect(
        const ExploreInterpretAs(adl: 'hamt', next: Matcher()),
        isNot(equals(const ExploreInterpretAs(adl: 'x', next: Matcher()))),
      );
      expect(
        const ExploreConditional(condition: HasFieldCondition('f')),
        isNot(equals(const ExploreConditional())),
      );
    });
  });

  group('IsLinkCondition.matches', () {
    test('matches links and optional targets', () {
      final cid = testCid();
      final link = linkNode(cid);
      expect(const IsLinkCondition().matches(link), isTrue);
      expect(IsLinkCondition(target: cid).matches(link), isTrue);
      expect(IsLinkCondition(target: testCid(9)).matches(link), isFalse);
      expect(const IsLinkCondition().matches(strNode('x')), isFalse);
    });
  });

  group('toNode compact forms', () {
    test('selectors serialize under their union keys', () {
      String key(Selector s) => s.toNode().mapValue.entries.single.key;
      expect(key(const Matcher()), '.');
      expect(key(ExploreAll(next: const Matcher())), 'a');
      expect(key(ExploreFields(fields: {'f': const Matcher()})), 'f');
      expect(key(const ExploreIndex(index: 0, next: Matcher())), 'i');
      expect(key(const ExploreRange(start: 0, end: 1, next: Matcher())), 'r');
      expect(
        key(
          const ExploreRecursive(
            limit: RecursionLimitNone(),
            sequence: ExploreRecursiveEdge(),
          ),
        ),
        'R',
      );
      expect(
        key(
          const ExploreRecursive(
            limit: DepthRecursionLimit(2),
            sequence: ExploreRecursiveEdge(),
            stopAt: IsLinkCondition(),
          ),
        ),
        'R',
      );
      expect(key(ExploreUnion(members: [const Matcher()])), '|');
      expect(key(const ExploreRecursiveEdge()), '@');
      expect(key(const ExploreInterpretAs(adl: 'hamt', next: Matcher())), '~');
      expect(
        key(
          const ExploreConditional(
            condition: HasKindCondition('map'),
            next: Matcher(),
          ),
        ),
        '&',
      );
    });

    test('matcher fields serialize', () {
      final node = const Matcher(
        label: 'l',
        index: 2,
        subset: Slice(from: 0, to: 1),
        onlyIf: HasFieldCondition('f'),
      ).toNode();
      final body = node.mapValue.entries.single.value.mapValue;
      expect(
        body.entries.map((e) => e.key).toSet(),
        containsAll(['subset', 'label', 'index', 'onlyIf']),
      );
    });

    test('conditions serialize under their keys', () {
      String key(Condition c) => c.toNode().mapValue.entries.single.key;
      expect(key(const IsLinkCondition()), '/');
      expect(key(IsLinkCondition(target: testCid())), '/');
      expect(key(const HasFieldCondition('f')), 'hasField');
      expect(key(HasValueCondition(intNode(1))), '=');
      expect(key(const HasKindCondition('map')), '%');
      expect(key(GreaterThanCondition(1)), 'greaterThan');
      expect(key(LessThanCondition(1.5)), 'lessThan');
      expect(key(AndCondition([const HasKindCondition('map')])), 'and');
      expect(key(OrCondition([const HasKindCondition('map')])), 'or');
    });
  });

  group('parseSelector guards', () {
    test('rejects non-map selector nodes', () {
      expect(
        () => parseSelector(strNode('x')),
        throwsA(isA<SelectorParseError>()),
      );
    });

    test('rejects non-map member bodies', () {
      expect(
        () => parseSelector(mapNode({'a': strNode('x')})),
        throwsA(isA<SelectorParseError>()),
      );
      expect(
        () => parseSelector(mapNode({'matcher': strNode('x')})),
        throwsA(isA<SelectorParseError>()),
      );
    });

    test('rejects non-list union members', () {
      expect(
        () => parseSelector(mapNode({'|': mapNode({})})),
        throwsA(isA<SelectorParseError>()),
      );
    });

    test('rejects bodies missing required fields', () {
      expect(
        () => parseSelector(mapNode({'a': mapNode({})})),
        throwsA(isA<SelectorParseError>()),
      );
    });

    test('rejects non-string fields where strings are required', () {
      expect(
        () => parseCondition(mapNode({'hasField': intNode(1)})),
        throwsA(isA<SelectorParseError>()),
      );
    });
  });

  group('decodeSelectorBytes', () {
    test('rejects empty and whitespace-only input', () {
      expect(
        decodeSelectorBytes(Uint8List(0)),
        throwsA(isA<SelectorParseError>()),
      );
      expect(
        decodeSelectorBytes(Uint8List.fromList([0x20, 0x09, 0x0a, 0x0d])),
        throwsA(isA<SelectorParseError>()),
      );
    });
  });

  group('parseSelectorEnvelope', () {
    test('unwraps the selector member', () {
      final envelope = mapNode({'selector': const Matcher().toNode()});
      expect(parseSelectorEnvelope(envelope), isA<Matcher>());
    });

    test('rejects non-map nodes', () {
      expect(
        () => parseSelectorEnvelope(strNode('x')),
        throwsA(isA<SelectorParseError>()),
      );
    });

    test('rejects envelopes without a selector field', () {
      expect(
        () => parseSelectorEnvelope(mapNode({'other': mapNode({})})),
        throwsA(isA<SelectorParseError>()),
      );
    });
  });

  group('parseCondition', () {
    test('rejects non-map nodes and multi-key maps', () {
      expect(
        () => parseCondition(strNode('x')),
        throwsA(isA<SelectorParseError>()),
      );
      expect(
        () => parseCondition(mapNode({'a': nullNode(), 'b': nullNode()})),
        throwsA(isA<SelectorParseError>()),
      );
    });

    test('isLink accepts links, null, and nothing else', () {
      final cid = testCid();
      expect(
        parseCondition(mapNode({'/': linkNode(cid)})),
        equals(IsLinkCondition(target: cid)),
      );
      expect(
        parseCondition(mapNode({'/': nullNode()})),
        equals(const IsLinkCondition()),
      );
      expect(
        () => parseCondition(mapNode({'/': strNode('x')})),
        throwsA(isA<SelectorParseError>()),
      );
    });

    test('parses the scalar condition members', () {
      expect(
        parseCondition(mapNode({'hasField': strNode('f')})),
        equals(const HasFieldCondition('f')),
      );
      expect(
        parseCondition(mapNode({'=': intNode(3)})),
        equals(HasValueCondition(intNode(3))),
      );
      expect(
        parseCondition(mapNode({'%': strNode('map')})),
        equals(const HasKindCondition('map')),
      );
      expect(
        parseCondition(mapNode({'greaterThan': intNode(3)})),
        equals(GreaterThanCondition(3)),
      );
      expect(
        parseCondition(mapNode({'greaterThan': floatNode(1.5)})),
        equals(GreaterThanCondition(1.5)),
      );
      expect(
        parseCondition(mapNode({'lessThan': intNode(9)})),
        equals(LessThanCondition(9)),
      );
    });

    test('numeric conditions reject non-numeric values', () {
      expect(
        () => parseCondition(mapNode({'greaterThan': strNode('x')})),
        throwsA(isA<SelectorParseError>()),
      );
      expect(
        () => parseCondition(mapNode({'lessThan': boolNode(true)})),
        throwsA(isA<SelectorParseError>()),
      );
    });

    test('rejects unknown condition keys', () {
      expect(
        () => parseCondition(mapNode({'bogus': intNode(1)})),
        throwsA(isA<SelectorParseError>()),
      );
    });
  });

  group('numeric condition matching', () {
    test('evaluates int, bigint, float and non-numeric nodes', () {
      expect(GreaterThanCondition(2).matches(intNode(3)), isTrue);
      // [sign=0, magnitude 0x0100] = 256.
      expect(
        GreaterThanCondition(200).matches(bigIntNode([0, 0x01, 0x00])),
        isTrue,
      );
      // [sign=1, magnitude 0x05] = -5.
      expect(LessThanCondition(0).matches(bigIntNode([1, 0x05])), isTrue);
      // Truncated big-ints count as zero.
      expect(GreaterThanCondition(-1).matches(bigIntNode([0])), isTrue);
      expect(LessThanCondition(2.0).matches(floatNode(1.5)), isTrue);
      expect(GreaterThanCondition(0).matches(strNode('x')), isFalse);
      expect(LessThanCondition(0).matches(mapNode({})), isFalse);
    });
  });

  group('ipldKindName', () {
    test('names every data-model kind', () {
      expect(ipldKindName(Kind.MAP), 'map');
      expect(ipldKindName(Kind.LIST), 'list');
      expect(ipldKindName(Kind.STRING), 'string');
      expect(ipldKindName(Kind.BYTES), 'bytes');
      expect(ipldKindName(Kind.INTEGER), 'int');
      expect(ipldKindName(Kind.BIG_INT), 'int');
      expect(ipldKindName(Kind.FLOAT), 'float');
      expect(ipldKindName(Kind.BOOL), 'bool');
      expect(ipldKindName(Kind.NULL), 'null');
      expect(ipldKindName(Kind.LINK), 'link');
    });
  });

  group('ipldNodeEquals', () {
    test('scalars compare by value', () {
      expect(ipldNodeEquals(nullNode(), nullNode()), isTrue);
      expect(ipldNodeEquals(boolNode(true), boolNode(true)), isTrue);
      expect(ipldNodeEquals(boolNode(true), boolNode(false)), isFalse);
      expect(ipldNodeEquals(intNode(3), intNode(3)), isTrue);
      expect(ipldNodeEquals(intNode(3), intNode(4)), isFalse);
      expect(ipldNodeEquals(bigIntNode([0, 1]), bigIntNode([0, 1])), isTrue);
      expect(ipldNodeEquals(bigIntNode([0, 1]), bigIntNode([0, 2])), isFalse);
      expect(ipldNodeEquals(floatNode(1.5), floatNode(1.5)), isTrue);
      expect(ipldNodeEquals(floatNode(1.5), floatNode(2.5)), isFalse);
      expect(ipldNodeEquals(strNode('a'), strNode('a')), isTrue);
      expect(ipldNodeEquals(strNode('a'), strNode('b')), isFalse);
      expect(ipldNodeEquals(bytesNode([1, 2]), bytesNode([1, 2])), isTrue);
      expect(ipldNodeEquals(bytesNode([1, 2]), bytesNode([1, 3])), isFalse);
      expect(ipldNodeEquals(bytesNode([1, 2]), bytesNode([1, 2, 3])), isFalse);
    });

    test('links compare codec and multihash', () {
      expect(ipldNodeEquals(linkNode(testCid()), linkNode(testCid())), isTrue);
      expect(
        ipldNodeEquals(linkNode(testCid()), linkNode(testCid(7))),
        isFalse,
      );
    });

    test('lists compare elementwise', () {
      expect(
        ipldNodeEquals(listNode([intNode(1)]), listNode([intNode(1)])),
        isTrue,
      );
      expect(
        ipldNodeEquals(
          listNode([intNode(1)]),
          listNode([intNode(1), intNode(2)]),
        ),
        isFalse,
      );
      expect(
        ipldNodeEquals(listNode([intNode(1)]), listNode([intNode(2)])),
        isFalse,
      );
    });

    test('maps compare by key and value', () {
      expect(
        ipldNodeEquals(mapNode({'a': intNode(1)}), mapNode({'a': intNode(1)})),
        isTrue,
      );
      expect(
        ipldNodeEquals(
          mapNode({'a': intNode(1)}),
          mapNode({'a': intNode(1), 'b': intNode(2)}),
        ),
        isFalse,
      );
      expect(
        ipldNodeEquals(mapNode({'a': intNode(1)}), mapNode({'b': intNode(1)})),
        isFalse,
      );
      expect(
        ipldNodeEquals(mapNode({'a': intNode(1)}), mapNode({'a': intNode(2)})),
        isFalse,
      );
    });

    test('different kinds never match', () {
      expect(ipldNodeEquals(strNode('1'), intNode(1)), isFalse);
    });
  });

  group('ipldNodeHash', () {
    test('produces a stable hash for every kind', () {
      final nodes = [
        nullNode(),
        boolNode(true),
        intNode(3),
        bigIntNode([0, 1]),
        floatNode(1.5),
        strNode('s'),
        bytesNode([1, 2]),
        linkNode(testCid()),
        listNode([intNode(1)]),
        mapNode({'a': intNode(1), 'b': strNode('x')}),
      ];
      for (final node in nodes) {
        expect(ipldNodeHash(node), isA<int>());
      }
      // Equal scalars hash equally.
      expect(ipldNodeHash(intNode(3)), equals(ipldNodeHash(intNode(3))));
      expect(
        ipldNodeHash(mapNode({'a': intNode(1)})),
        equals(ipldNodeHash(mapNode({'a': intNode(1)}))),
      );
    });
  });

  group('SelectorExecutor slice application', () {
    test('matcher subset slices bytes nodes', () async {
      final executor = SelectorExecutor(
        (_) async => bytesNode([10, 20, 30, 40]),
      );
      final results = await executor
          .execute(testCid(), const Matcher(subset: Slice(from: 1, to: 3)))
          .toList();
      expect(results.single.node.bytesValue, equals([20, 30]));
    });

    test('out-of-range byte slices fail to match', () async {
      final executor = SelectorExecutor(
        (_) async => bytesNode([10, 20, 30, 40]),
      );
      final results = await executor
          .execute(testCid(), const Matcher(subset: Slice(from: 9, to: 10)))
          .toList();
      expect(results, isEmpty);
    });

    test('slices only apply to string and bytes nodes', () async {
      final executor = SelectorExecutor((_) async => intNode(7));
      final results = await executor
          .execute(testCid(), const Matcher(subset: Slice(from: 0, to: 1)))
          .toList();
      expect(results, isEmpty);
    });

    test('exploreAll iterates list elements', () async {
      final executor = SelectorExecutor(
        (_) async => listNode([intNode(1), intNode(2)]),
      );
      final results = await executor
          .execute(testCid(), ExploreAll(next: const Matcher()))
          .toList();
      expect(results, hasLength(2));
      expect(results.map((r) => r.node.intValue.toInt()), [1, 2]);
    });

    test('unknown selector subtypes throw', () async {
      final executor = SelectorExecutor((_) async => mapNode({}));
      await expectLater(
        executor.execute(testCid(), const _UnknownSelector()).toList(),
        throwsA(isA<IPLDValidationError>()),
      );
    });
  });
}

class _UnknownSelector extends Selector {
  const _UnknownSelector();

  @override
  IPLDNode toNode() => IPLDNode()..kind = Kind.NULL;

  @override
  bool operator ==(Object other) => other is _UnknownSelector;

  @override
  int get hashCode => runtimeType.hashCode;
}
