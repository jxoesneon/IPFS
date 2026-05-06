import 'package:test/test.dart';
import 'package:dart_ipfs/src/protocols/bitswap/wantlist.dart';
import 'package:dart_ipfs/src/protocols/bitswap/message.dart' as msg;

void main() {
  group('Wantlist', () {
    test('add and remove entries', () {
      final wantlist = Wantlist();
      wantlist.add('QmTest1', priority: 1);
      wantlist.add('QmTest2', priority: 2);
      expect(wantlist.length, equals(2));
      expect(wantlist.contains('QmTest1'), isTrue);
      wantlist.remove('QmTest1');
      expect(wantlist.contains('QmTest1'), isFalse);
      expect(wantlist.length, equals(1));
    });

    test('add with negative priority throws ArgumentError', () {
      final wantlist = Wantlist();
      expect(() => wantlist.add('QmTest', priority: -1), throwsArgumentError);
    });

    test('getEntry returns entry for CID', () {
      final wantlist = Wantlist();
      wantlist.add('QmTest', priority: 5);
      final entry = wantlist.getEntry('QmTest');
      expect(entry, isNotNull);
      expect(entry?.cid, equals('QmTest'));
      expect(entry?.priority, equals(5));
    });

    test('getEntry returns null for non-existent CID', () {
      final wantlist = Wantlist();
      expect(wantlist.getEntry('QmNonExistent'), isNull);
    });

    test('entries returns unmodifiable map', () {
      final wantlist = Wantlist();
      wantlist.add('QmTest');
      final entries = wantlist.entries;
      expect(entries, isA<Map>());
    });

    test('clear removes all entries', () {
      final wantlist = Wantlist();
      wantlist.add('QmTest1');
      wantlist.add('QmTest2');
      expect(wantlist.length, equals(2));
      wantlist.clear();
      expect(wantlist.length, equals(0));
    });

    test('toString returns formatted string', () {
      final wantlist = Wantlist();
      wantlist.add('QmTest');
      final str = wantlist.toString();
      expect(str, contains('Wantlist'));
      expect(str, contains('entries'));
    });

    test('add with custom wantType and sendDontHave', () {
      final wantlist = Wantlist();
      wantlist.add('QmTest', wantType: msg.WantType.have, sendDontHave: true);
      final entry = wantlist.getEntry('QmTest');
      expect(entry?.wantType, equals(msg.WantType.have));
      expect(entry?.sendDontHave, isTrue);
    });
  });
}
