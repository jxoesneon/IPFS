import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:dart_ipfs/src/protocols/dht/interface_dht_handler.dart'; // For Key/Value
import 'mock_dht_handler.dart';

// Helper aliases if needed
// Key and Value are typedefs typically.
// mock_dht_handler.dart uses: import 'package:dart_ipfs/src/protocols/dht/Interface_dht_handler.dart';
// Let's assume Key and Value are available via that import.

void main() {
  group('MockDHTHandler', () {
    late MockDHTHandler dht;

    setUp(() async {
      dht = MockDHTHandler();
      await dht.start();
    });

    tearDown(() async {
      await dht.stop();
    });

    test('lifecycle tracks state correctly', () async {
      expect(dht.wasCalled('start'), isTrue);

      dht.reset(); // clear calls
      await dht.start();
      final status = await dht.getStatus();
      expect(status['running'], isTrue);

      await dht.stop();
      expect(dht.wasCalled('stop'), isTrue);
      final statusStopped = await dht.getStatus();
      expect(statusStopped['running'], isFalse);
    });

    test('putValue/getValue stores and retrieves', () async {
      // Create mock Key/Value
      // Assuming Key and Value are compatible with list/string/bytes?
      // Interface_dht_handler usually defines them.
      // If Key is class, wrap. If typedef, match.
      // Let's assume Key is String-like or has toString.
      // The mock uses toString().

      // Let's Mock PeerId and CID logic if needed.
      // Or just create objects that satisfy Types.

      // If Key is just `List<int>` or String check imports.
      // Checking local imports: `package:dart_ipfs/src/protocols/dht/Interface_dht_handler.dart`
      // I'll skip complex type creation if I can assume `MockDHTHandler` handles generics cleanly via dynamic or simple types in tests.
      // Actually `putValue(Key key, Value value)`.
      // I need to create compatible Key and Value.
      // Let's try creating a dummy Key implementation if it's an interface, or use real one.
      // But `Interface_dht_handler` is likely abstract.
      // Let's assume Key is `List<int>` based on IPFS conventions?
      // Wait, file `lib/src/protocols/dht/Interface_dht_handler.dart` likely defines classes/typedefs.
      // I'll defer complex test implementation to see errors, or inspect Interface_dht_handler first?
      // I'll bet on Key/Value being classes I can construct or mock.
      // Or simply:
      final key = Key(Uint8List.fromList([1, 2, 3]));
      final value = Value(Uint8List.fromList([4, 5, 6]));

      await dht.putValue(key, value);
      expect(dht.wasCalled('putValue'), isTrue);

      final retrieved = await dht.getValue(key);
      expect(retrieved, equals(value));
    });

    test('getValue throws if not found', () {
      final key = Key(Uint8List.fromList([9, 9, 9]));
      expect(() => dht.getValue(key), throwsException);
    });

    test('simulates delays', () async {
      dht.setSimulatedDelay(Duration(milliseconds: 50));
      final stopwatch = Stopwatch()..start();

      final key = Key(Uint8List.fromList([1]));
      final value = Value(Uint8List.fromList([1]));
      await dht.putValue(key, value);

      stopwatch.stop();
      expect(
        stopwatch.elapsedMilliseconds,
        greaterThanOrEqualTo(40),
      ); // allow some buffer
    });

    test('simulates errors on next call', () async {
      dht.throwOnNext(Exception('Simulated failure'));

      expect(
        () => dht.putValue(Key(Uint8List(1)), Value(Uint8List(1))),
        throwsException,
      );

      // Next call should succeed (error consumed)
      await dht.putValue(Key(Uint8List(1)), Value(Uint8List(1)));
      expect(dht.wasCalled('putValue'), isTrue);
    });

    test('reset clears data and state', () async {
      await dht.putValue(Key(Uint8List(1)), Value(Uint8List(1)));
      dht.reset(); // Also stops it

      await dht.start(); // Restart to query
      // Storage should be empty
      expect(() => dht.getValue(Key(Uint8List(1))), throwsException);
      expect(dht.getCalls().length, 1); // Only 'start'
      expect(dht.simulatedDelay, isNull);
    });

    test('operations throw if not running', () async {
      await dht.stop();
      expect(
        () => dht.putValue(Key(Uint8List(1)), Value(Uint8List(1))),
        throwsStateError,
      );
    });
  });
}
