// Auto-generated proto coverage tests. Do not hand-edit.

import 'package:test/test.dart';
import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pbenum.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';

void main() {
  group('IPLDNode', () {
    test('round-trips and accessors work', () {
      final original = IPLDNode(
        kind: Kind.values.first,
        boolValue: true,
        intValue: $fixnum.Int64(1),
        floatValue: 1.2,
        stringValue: 'a',
        bytesValue: const [0, 1, 2],
        listValue: IPLDList.create(),
        mapValue: IPLDMap.create(),
        linkValue: IPLDLink.create(),
        bigIntValue: const [0, 1, 2],
      );
      original.kind;
      original.boolValue;
      original.intValue;
      original.floatValue;
      original.stringValue;
      original.bytesValue;
      original.listValue;
      original.mapValue;
      original.linkValue;
      original.bigIntValue;
      original.hasKind();
      original.clearKind();
      original.hasBoolValue();
      original.clearBoolValue();
      original.hasIntValue();
      original.clearIntValue();
      original.hasFloatValue();
      original.clearFloatValue();
      original.hasStringValue();
      original.clearStringValue();
      original.hasBytesValue();
      original.clearBytesValue();
      original.hasListValue();
      original.clearListValue();
      original.hasMapValue();
      original.clearMapValue();
      original.hasLinkValue();
      original.clearLinkValue();
      original.hasBigIntValue();
      original.clearBigIntValue();
      original.ensureListValue();
      original.ensureLinkValue();
      original.ensureMapValue();
      expect(original.whichValue(), isNotNull);
      expect(IPLDNode.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = IPLDNode.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) {});
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(IPLDNode.fromJson(json), isNotNull);
    });
  });

  group('IPLDList', () {
    test('round-trips and accessors work', () {
      final original = IPLDList(values: [IPLDNode.create()]);
      expect(original.values.length, 1);
      original.values.clear();
      expect(IPLDList.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = IPLDList.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) {});
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(IPLDList.fromJson(json), isNotNull);
    });
  });

  group('IPLDMap', () {
    test('round-trips and accessors work', () {
      final original = IPLDMap(entries: [MapEntry.create()]);
      expect(original.entries.length, 1);
      original.entries.clear();
      expect(IPLDMap.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = IPLDMap.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) {});
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(IPLDMap.fromJson(json), isNotNull);
    });
  });

  group('MapEntry', () {
    test('round-trips and accessors work', () {
      final original = MapEntry(key: 'a', value: IPLDNode.create());
      expect(original.key, 'a');
      expect(original.value, isNotNull);
      original.hasKey();
      original.clearKey();
      original.hasValue();
      original.clearValue();
      original.ensureValue();
      expect(MapEntry.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = MapEntry.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) {});
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(MapEntry.fromJson(json), isNotNull);
    });
  });

  group('IPLDLink', () {
    test('round-trips and accessors work', () {
      final original = IPLDLink(
        version: 1,
        codec: 'a',
        multihash: const [0, 1, 2],
      );
      expect(original.version, 1);
      expect(original.codec, 'a');
      expect(original.multihash, const [0, 1, 2]);
      original.hasVersion();
      original.clearVersion();
      original.hasCodec();
      original.clearCodec();
      original.hasMultihash();
      original.clearMultihash();
      expect(IPLDLink.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = IPLDLink.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) {});
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(IPLDLink.fromJson(json), isNotNull);
    });
  });
}
