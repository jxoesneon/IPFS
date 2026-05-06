import 'dart:typed_data';
import 'package:fixnum/fixnum.dart';
import 'package:test/test.dart';
import 'package:dart_ipfs/src/core/ipld/selectors/ipld_selector.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';

void main() {
  group('IPLDSelector Coverage Tests', () {
    group('toBytes encoding', () {
      test('toBytes encodes all selector type', () async {
        final selector = IPLDSelector(type: SelectorType.all);
        final bytes = await selector.toBytes();
        expect(bytes, isNotEmpty);
      });

      test('toBytes encodes none selector type', () async {
        final selector = IPLDSelector.none();
        final bytes = await selector.toBytes();
        expect(bytes, isNotEmpty);
      });

      test('toBytes encodes explore selector with path', () async {
        final selector = IPLDSelector.explore(
          path: 'some/path',
          selector: IPLDSelector.all(),
        );
        final bytes = await selector.toBytes();
        expect(bytes, isNotEmpty);
      });

      test('toBytes encodes matcher selector with criteria', () async {
        final selector = IPLDSelector.matcher(
          criteria: {'key': 'value', 'number': 42},
        );
        final bytes = await selector.toBytes();
        expect(bytes, isNotEmpty);
      });

      test('toBytes encodes recursive selector with maxDepth', () async {
        final selector = IPLDSelector.recursive(
          selector: IPLDSelector.all(),
          maxDepth: 10,
        );
        final bytes = await selector.toBytes();
        expect(bytes, isNotEmpty);
      });

      test('toBytes encodes recursive selector with stopAtLink', () async {
        final selector = IPLDSelector.recursive(
          selector: IPLDSelector.all(),
          stopAtLink: true,
        );
        final bytes = await selector.toBytes();
        expect(bytes, isNotEmpty);
      });

      test('toBytes encodes union selector', () async {
        final selector = IPLDSelector.union([
          IPLDSelector.all(),
          IPLDSelector.none(),
        ]);
        final bytes = await selector.toBytes();
        expect(bytes, isNotEmpty);
      });

      test('toBytes encodes intersection selector', () async {
        final selector = IPLDSelector.intersection([
          IPLDSelector.all(),
          IPLDSelector.none(),
        ]);
        final bytes = await selector.toBytes();
        expect(bytes, isNotEmpty);
      });

      test('toBytes encodes selector with nested subselectors', () async {
        final selector = IPLDSelector.recursive(
          selector: IPLDSelector.union([
            IPLDSelector.all(),
            IPLDSelector.matcher(criteria: {'a': 1}),
          ]),
          maxDepth: 5,
        );
        final bytes = await selector.toBytes();
        expect(bytes, isNotEmpty);
      });
    });

    group('fromBytesAsync decoding', () {
      test('fromBytesAsync decodes all selector', () async {
        final original = IPLDSelector.all();
        final bytes = await original.toBytes();
        final decoded = await IPLDSelector.fromBytesAsync(bytes);
        expect(decoded.type, equals(original.type));
      });

      test('fromBytesAsync decodes none selector', () async {
        final original = IPLDSelector.none();
        final bytes = await original.toBytes();
        final decoded = await IPLDSelector.fromBytesAsync(bytes);
        expect(decoded.type, equals(original.type));
      });

      test('fromBytesAsync decodes explore selector', () async {
        final original = IPLDSelector.explore(
          path: 'test/path',
          selector: IPLDSelector.all(),
        );
        final bytes = await original.toBytes();
        final decoded = await IPLDSelector.fromBytesAsync(bytes);
        expect(decoded.type, equals(original.type));
        expect(decoded.fieldPath, equals(original.fieldPath));
      });

      test('fromBytesAsync decodes matcher selector with criteria', () async {
        final original = IPLDSelector.matcher(
          criteria: {'key': 'value', 'num': 123},
        );
        final bytes = await original.toBytes();
        final decoded = await IPLDSelector.fromBytesAsync(bytes);
        expect(decoded.type, equals(original.type));
        expect(decoded.criteria, equals(original.criteria));
      });

      test('fromBytesAsync decodes recursive selector', () async {
        final original = IPLDSelector.recursive(
          selector: IPLDSelector.all(),
          maxDepth: 15,
          stopAtLink: false,
        );
        final bytes = await original.toBytes();
        final decoded = await IPLDSelector.fromBytesAsync(bytes);
        expect(decoded.type, equals(original.type));
        expect(decoded.maxDepth, equals(original.maxDepth));
        expect(decoded.stopAtLink, equals(original.stopAtLink));
      });

      test('fromBytesAsync decodes union selector', () async {
        final original = IPLDSelector.union([
          IPLDSelector.all(),
          IPLDSelector.none(),
        ]);
        final bytes = await original.toBytes();
        final decoded = await IPLDSelector.fromBytesAsync(bytes);
        expect(decoded.type, equals(original.type));
        expect(decoded.subSelectors, isNotNull);
      });

      test('fromBytesAsync decodes intersection selector', () async {
        final original = IPLDSelector.intersection([
          IPLDSelector.all(),
          IPLDSelector.none(),
        ]);
        final bytes = await original.toBytes();
        final decoded = await IPLDSelector.fromBytesAsync(bytes);
        expect(decoded.type, equals(original.type));
        expect(decoded.subSelectors, isNotNull);
      });
    });

    group('fromNode decoding', () {
      test('fromNode decodes all selector', () {
        final node = IPLDNode()
          ..kind = Kind.MAP
          ..mapValue = (IPLDMap()
            ..entries.addAll([
              MapEntry()
                ..key = '.tag'
                ..value = (IPLDNode()
                  ..kind = Kind.STRING
                  ..stringValue = 'SelectorType.all'),
            ]));
        final selector = IPLDSelector.fromNode(node);
        expect(selector.type, equals(SelectorType.all));
      });

      test('fromNode decodes none selector', () {
        final node = IPLDNode()
          ..kind = Kind.MAP
          ..mapValue = (IPLDMap()
            ..entries.addAll([
              MapEntry()
                ..key = '.tag'
                ..value = (IPLDNode()
                  ..kind = Kind.STRING
                  ..stringValue = 'SelectorType.none'),
            ]));
        final selector = IPLDSelector.fromNode(node);
        expect(selector.type, equals(SelectorType.none));
      });

      test('fromNode decodes selector with criteria', () {
        final criteriaNode = IPLDNode()
          ..kind = Kind.MAP
          ..mapValue = (IPLDMap()
            ..entries.addAll([
              MapEntry()
                ..key = 'test'
                ..value = (IPLDNode()
                  ..kind = Kind.STRING
                  ..stringValue = 'value'),
            ]));
        final node = IPLDNode()
          ..kind = Kind.MAP
          ..mapValue = (IPLDMap()
            ..entries.addAll([
              MapEntry()
                ..key = '.tag'
                ..value = (IPLDNode()
                  ..kind = Kind.STRING
                  ..stringValue = 'SelectorType.matcher'),
              MapEntry()
                ..key = 'criteria'
                ..value = criteriaNode,
            ]));
        final selector = IPLDSelector.fromNode(node);
        expect(selector.type, equals(SelectorType.matcher));
        expect(selector.criteria, isNotEmpty);
      });

      test('fromNode decodes selector with maxDepth', () {
        final node = IPLDNode()
          ..kind = Kind.MAP
          ..mapValue = (IPLDMap()
            ..entries.addAll([
              MapEntry()
                ..key = '.tag'
                ..value = (IPLDNode()
                  ..kind = Kind.STRING
                  ..stringValue = 'SelectorType.recursive'),
              MapEntry()
                ..key = 'maxDepth'
                ..value = (IPLDNode()
                  ..kind = Kind.INTEGER
                  ..intValue = Int64(20)),
            ]));
        final selector = IPLDSelector.fromNode(node);
        expect(selector.maxDepth, equals(20));
      });

      test('fromNode decodes selector with fieldPath', () {
        final node = IPLDNode()
          ..kind = Kind.MAP
          ..mapValue = (IPLDMap()
            ..entries.addAll([
              MapEntry()
                ..key = '.tag'
                ..value = (IPLDNode()
                  ..kind = Kind.STRING
                  ..stringValue = 'SelectorType.explore'),
              MapEntry()
                ..key = 'path'
                ..value = (IPLDNode()
                  ..kind = Kind.STRING
                  ..stringValue = 'some/path'),
            ]));
        final selector = IPLDSelector.fromNode(node);
        expect(selector.fieldPath, equals('some/path'));
      });

      test('fromNode decodes selector with stopAtLink', () {
        final node = IPLDNode()
          ..kind = Kind.MAP
          ..mapValue = (IPLDMap()
            ..entries.addAll([
              MapEntry()
                ..key = '.tag'
                ..value = (IPLDNode()
                  ..kind = Kind.STRING
                  ..stringValue = 'SelectorType.recursive'),
              MapEntry()
                ..key = 'stopAtLink'
                ..value = (IPLDNode()
                  ..kind = Kind.BOOL
                  ..boolValue = true),
            ]));
        final selector = IPLDSelector.fromNode(node);
        expect(selector.stopAtLink, isTrue);
      });
    });

    group('round-trip encoding/decoding', () {
      test('round-trip all selector', () async {
        final original = IPLDSelector.all();
        final bytes = await original.toBytes();
        final decoded = await IPLDSelector.fromBytesAsync(bytes);
        expect(decoded.type, equals(original.type));
      });

      test('round-trip complex nested selector', () async {
        final original = IPLDSelector.recursive(
          selector: IPLDSelector.union([
            IPLDSelector.explore(
              path: 'deep/path',
              selector: IPLDSelector.matcher(criteria: {'type': 'file'}),
            ),
            IPLDSelector.none(),
          ]),
          maxDepth: 10,
          stopAtLink: true,
        );
        final bytes = await original.toBytes();
        final decoded = await IPLDSelector.fromBytesAsync(bytes);
        expect(decoded.type, equals(original.type));
        expect(decoded.maxDepth, equals(original.maxDepth));
        expect(decoded.stopAtLink, equals(original.stopAtLink));
      });
    });
  });
}
