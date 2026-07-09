// Auto-generated proto coverage tests. Do not hand-edit.

import 'package:test/test.dart';
import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pbenum.dart';
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart';

void main() {
  group('Data', () {
    test('round-trips and accessors work', () {
      final original = Data(type: Data_DataType.values.first, data: const [0, 1, 2], filesize: $fixnum.Int64(1), blocksizes: [$fixnum.Int64(1)], hashType: $fixnum.Int64(1), fanout: $fixnum.Int64(1), mode: 1, mtime: $fixnum.Int64(1), mtimeNsecs: 1);
      expect(original.type, isNotNull);
      expect(original.data, const [0, 1, 2]);
      expect(original.filesize, $fixnum.Int64(1));
      expect(original.blocksizes.length, 1);
      expect(original.hashType, $fixnum.Int64(1));
      expect(original.fanout, $fixnum.Int64(1));
      expect(original.mode, 1);
      expect(original.mtime, $fixnum.Int64(1));
      expect(original.mtimeNsecs, 1);
      original.hasType();
      original.clearType();
      original.hasData();
      original.clearData();
      original.hasFilesize();
      original.clearFilesize();
      original.blocksizes.clear();
      original.hasHashType();
      original.clearHashType();
      original.hasFanout();
      original.clearFanout();
      original.hasMode();
      original.clearMode();
      original.hasMtime();
      original.clearMtime();
      original.hasMtimeNsecs();
      original.clearMtimeNsecs();
      expect(Data.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = Data.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(Data.fromJson(json), isNotNull);
    });
  });

  group('Metadata', () {
    test('round-trips and accessors work', () {
      final original = Metadata(mimeType: 'a', size: $fixnum.Int64(1), properties: [MapEntry('k', 'v')]);
      expect(original.mimeType, 'a');
      expect(original.size, $fixnum.Int64(1));
      expect(original.properties['k'], isNotNull);
      expect(original.properties.length, 1);
      original.hasMimeType();
      original.clearMimeType();
      original.hasSize();
      original.clearSize();
      original.properties.clear();
      expect(Metadata.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = Metadata.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(Metadata.fromJson(json), isNotNull);
    });
  });

}
