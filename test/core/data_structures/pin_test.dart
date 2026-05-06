import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:dart_ipfs/src/core/data_structures/pin.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/proto/generated/core/pin.pb.dart';
import 'package:fixnum/fixnum.dart';

void main() {
  late BlockStore blockStore;
  late CID cid;

  setUp(() {
    // Create a minimal BlockStore implementation for testing
    blockStore = BlockStore(path: 'test_tmp/pin_test');
    cid = CID.decode('QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn');
  });

  group('Pin', () {
    test('constructor initializes with timestamp', () {
      final before = DateTime.now();
      final pin = Pin(
        cid: cid,
        type: PinTypeProto.PIN_TYPE_DIRECT,
        blockStore: blockStore,
      );
      final after = DateTime.now();
      expect(
        pin.timestamp.isAfter(
          before.subtract(const Duration(milliseconds: 100)),
        ),
        isTrue,
      );
      expect(
        pin.timestamp.isBefore(after.add(const Duration(milliseconds: 100))),
        isTrue,
      );
    });

    test('constructor accepts custom timestamp', () {
      final customTime = DateTime(2024, 1, 1);
      final pin = Pin(
        cid: cid,
        type: PinTypeProto.PIN_TYPE_DIRECT,
        blockStore: blockStore,
        timestamp: customTime,
      );
      expect(pin.timestamp, equals(customTime));
    });

    test('toProto converts to protobuf', () {
      final pin = Pin(
        cid: cid,
        type: PinTypeProto.PIN_TYPE_RECURSIVE,
        blockStore: blockStore,
        timestamp: DateTime(2024, 1, 1),
      );
      final proto = pin.toProto();
      expect(proto.cid, equals(cid.toProto()));
      expect(proto.type, equals(PinTypeProto.PIN_TYPE_RECURSIVE));
    });

    test('toString returns formatted string', () {
      final pin = Pin(
        cid: cid,
        type: PinTypeProto.PIN_TYPE_DIRECT,
        blockStore: blockStore,
      );
      final str = pin.toString();
      expect(str, contains('Pin('));
      expect(str, contains('cid:'));
      expect(str, contains('type:'));
      expect(str, contains('timestamp:'));
    });

    test('fromProto creates Pin from protobuf', () {
      final proto = PinProto()
        ..cid = cid.toProto()
        ..type = PinTypeProto.PIN_TYPE_RECURSIVE
        ..timestamp = Int64(1704067200000); // 2024-01-01 in milliseconds
      final pin = Pin.fromProto(proto, blockStore);
      expect(pin.cid, equals(cid));
      expect(pin.type, equals(PinTypeProto.PIN_TYPE_RECURSIVE));
      expect(pin.timestamp.millisecondsSinceEpoch, equals(1704067200000));
    });
  });
}
