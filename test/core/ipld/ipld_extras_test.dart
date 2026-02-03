import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/ipld/extensions/ipld_node_json.dart';
import 'package:dart_ipfs/src/core/ipld/selectors/ipld_selector.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:fixnum/fixnum.dart';
import 'package:test/test.dart';

void main() {
  group('IPLDNodeJson', () {
    test('toJson simple', () {
      final node = IPLDNode()
        ..kind = Kind.MAP
        ..mapValue = (IPLDMap()
          ..entries.add(
            MapEntry()
              ..key = 'hello'
              ..value = (IPLDNode()
                ..kind = Kind.STRING
                ..stringValue = 'world'),
          ));

      final jsonStr = node.toJson();
      // proto3 json output might vary in spacing, but should parse back
      final decoded = jsonDecode(jsonStr);
      expect(decoded, containsPair('hello', 'world'));
    });
  });

  group('IPLDSelector', () {
    test('factories create correct types', () {
      expect(IPLDSelector.all().type, SelectorType.all);
      expect(IPLDSelector.none().type, SelectorType.none);

      final matcher = IPLDSelector.matcher(criteria: {'a': 1});
      expect(matcher.type, SelectorType.matcher);
      expect(matcher.criteria, containsPair('a', 1));

      final explore = IPLDSelector.explore(path: 'p', selector: matcher);
      expect(explore.type, SelectorType.explore);
      expect(explore.fieldPath, equals('p'));
      expect(explore.subSelectors, hasLength(1));

      final rec = IPLDSelector.recursive(
        selector: IPLDSelector.all(),
        maxDepth: 5,
      );
      expect(rec.type, SelectorType.recursive);
      expect(rec.maxDepth, equals(5));

      final union = IPLDSelector.union([
        IPLDSelector.all(),
        IPLDSelector.none(),
      ]);
      expect(union.type, SelectorType.union);
      expect(union.subSelectors, hasLength(2));
    });

    test('serialization round trip', () async {
      // Create a complex selector
      final selector = IPLDSelector.recursive(
        maxDepth: 3,
        selector: IPLDSelector.explore(
          path: 'links',
          selector: IPLDSelector.union([
            IPLDSelector.matcher(criteria: {'name': 'file.txt'}),
            IPLDSelector.all(),
          ]),
        ),
      );

      final bytes = await selector.toBytes();
      expect(bytes, isNotEmpty);

      // Decode back
      final decoded = await IPLDSelector.fromBytesAsync(bytes);

      expect(decoded.type, SelectorType.recursive);
      expect(decoded.maxDepth, equals(3));
      expect(decoded.subSelectors, hasLength(1));

      final child = decoded.subSelectors!.first;
      expect(child.type, SelectorType.explore);
      expect(child.fieldPath, equals('links'));

      final grandchild = child.subSelectors!.first;
      expect(grandchild.type, SelectorType.union);
      expect(grandchild.subSelectors, hasLength(2));
    });
  });
}

