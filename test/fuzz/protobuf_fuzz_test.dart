// Fuzz tests for protobuf-based parsers (Bitswap and DHT messages).
//
// These tests feed random, truncated, and corrupt byte sequences to the
// Bitswap message decoder and DHT message/envelope decoders, verifying that
// the parsers either produce a valid result or throw a known exception type —
// they must never crash or hang.
import 'dart:typed_data';

import 'package:dart_ipfs/src/proto/generated/bitswap/bitswap.pb.dart' as pb;
import 'package:dart_ipfs/src/proto/generated/dht/common_kademlia.pb.dart' as common_pb;
import 'package:dart_ipfs/src/proto/generated/dht/dht_messages.pb.dart' as dht_pb;
import 'package:dart_ipfs/src/protocols/bitswap/message.dart' as bitswap;
import 'package:dart_ipfs/src/protocols/dht/dht_envelope.dart';
import 'package:test/test.dart';

import '_fuzz_helpers.dart';

void main() {
  final rng = makeRandom();

  group('Protobuf fuzz', () {
    group('Bitswap message decoder', () {
      test(
        'random bytes fed to Bitswap Message.fromBytes do not crash',
        () async {
          for (var i = 0; i < 1000; i++) {
            final data = randomBytesRange(rng, 1, 5000);
            await _expectGracefulAsync(() => bitswap.Message.fromBytes(data));
          }
        },
      );

      test('truncated protobuf messages are handled gracefully', () async {
        final validMessages = _generateValidBitswapMessages();
        for (final msgBytes in validMessages) {
          for (var cut = 0; cut < msgBytes.length; cut++) {
            final truncatedMsg = truncated(msgBytes, cut);
            await _expectGracefulAsync(
              () => bitswap.Message.fromBytes(truncatedMsg),
            );
          }
        }
      });

      test('protobuf with invalid wire types is handled gracefully', () async {
        // Protobuf wire types are the low 3 bits of the tag byte.
        // Wire type 4 (end group) is invalid as a start tag.
        // Wire types 5, 6, 7 are reserved/invalid.
        for (var wt = 4; wt < 8; wt++) {
          for (var field = 1; field < 20; field++) {
            final tag = (field << 3) | wt;
            final data = Uint8List.fromList([tag, ...randomBytes(rng, 50)]);
            await _expectGracefulAsync(() => bitswap.Message.fromBytes(data));
          }
        }
      });

      test('corrupted valid Bitswap messages with flipped bytes', () async {
        final validMessages = _generateValidBitswapMessages();
        for (final msgBytes in validMessages) {
          for (var trial = 0; trial < 50; trial++) {
            final corrupted = withFlippedBytes(
              rng,
              msgBytes,
              1 + rng.nextInt(3),
            );
            await _expectGracefulAsync(
              () => bitswap.Message.fromBytes(corrupted),
            );
          }
        }
      });

      test('empty bytes are handled gracefully', () async {
        await _expectGracefulAsync(
          () => bitswap.Message.fromBytes(Uint8List(0)),
        );
      });

      test('direct pb.Message.fromBuffer with random bytes does not crash', () {
        for (var i = 0; i < 2000; i++) {
          final data = randomBytesRange(rng, 1, 3000);
          _expectGraceful(() => pb.Message.fromBuffer(data));
        }
      });
    });

    group('DHT message decoder', () {
      test('random bytes fed to DHT PingRequest.fromBuffer do not crash', () {
        for (var i = 0; i < 2000; i++) {
          final data = randomBytesRange(rng, 1, 3000);
          _expectGraceful(() => dht_pb.PingRequest.fromBuffer(data));
        }
      });

      test('truncated DHT messages are handled gracefully', () {
        final validMessages = _generateValidDhtMessages();
        for (final msgBytes in validMessages) {
          for (var cut = 0; cut < msgBytes.length; cut++) {
            final truncatedMsg = truncated(msgBytes, cut);
            _expectGraceful(() => dht_pb.PingRequest.fromBuffer(truncatedMsg));
          }
        }
      });

      test('DHT messages with invalid wire types are handled gracefully', () {
        for (var wt = 4; wt < 8; wt++) {
          for (var field = 1; field < 20; field++) {
            final tag = (field << 3) | wt;
            final data = Uint8List.fromList([tag, ...randomBytes(rng, 50)]);
            _expectGraceful(() => dht_pb.PingRequest.fromBuffer(data));
          }
        }
      });

      test('corrupted valid DHT messages with flipped bytes', () {
        final validMessages = _generateValidDhtMessages();
        for (final msgBytes in validMessages) {
          for (var trial = 0; trial < 50; trial++) {
            final corrupted = withFlippedBytes(
              rng,
              msgBytes,
              1 + rng.nextInt(3),
            );
            _expectGraceful(() => dht_pb.PingRequest.fromBuffer(corrupted));
          }
        }
      });
    });

    group('DHT envelope decoder', () {
      test('random bytes fed to DHTEnvelope.fromBytes do not crash', () {
        for (var i = 0; i < 3000; i++) {
          final data = randomBytesRange(rng, 1, 1000);
          _expectGraceful(() => DHTEnvelope.fromBytes(data));
        }
      });

      test('truncated DHT envelopes are handled gracefully', () {
        final valid = _generateValidDhtEnvelope();
        for (var cut = 0; cut < valid.length; cut++) {
          final truncatedEnv = truncated(valid, cut);
          _expectGraceful(() => DHTEnvelope.fromBytes(truncatedEnv));
        }
      });

      test('empty bytes are handled gracefully', () {
        _expectGraceful(() => DHTEnvelope.fromBytes(Uint8List(0)));
      });
    });
  });
}

/// Asserts that a synchronous [action] either completes normally or throws a
/// known exception type.
void _expectGraceful(void Function() action) {
  try {
    action();
  } on FormatException {
    // Expected.
  } on RangeError {
    // Expected.
  } on ArgumentError {
    // Expected.
  } on StateError {
    // Expected.
  } on UnsupportedError {
    // Expected.
  } on Exception {
    // Expected — any typed exception from the protobuf decoder.
  }
}

/// Asserts that an asynchronous [action] either completes normally or throws a
/// known exception type. Errors are swallowed because the Bitswap decoder
/// already logs and skips invalid entries internally; the contract is that it
/// must not crash the isolate.
Future<void> _expectGracefulAsync(Future<void> Function() action) async {
  try {
    await action();
  } on FormatException {
    // Expected.
  } on RangeError {
    // Expected.
  } on ArgumentError {
    // Expected.
  } on StateError {
    // Expected.
  } on UnsupportedError {
    // Expected.
  } on Exception {
    // Expected — any typed exception from the decoder.
  }
}

/// Generates valid Bitswap message byte sequences.
List<Uint8List> _generateValidBitswapMessages() {
  final sequences = <Uint8List>[];
  // Empty message.
  sequences.add(pb.Message().writeToBuffer());
  // Message with pending bytes.
  final msg1 = pb.Message()..pendingBytes = 1024;
  sequences.add(msg1.writeToBuffer());
  // Message with a wantlist entry.
  final wantlist = pb.Message_Wantlist()
    ..full = false
    ..entries.add(
      pb.Message_Wantlist_Entry()
        ..block = List.filled(34, 0x12)
        ..priority = 5
        ..cancel = false
        ..sendDontHave = true,
    );
  final msg2 = pb.Message()..wantlist = wantlist;
  sequences.add(msg2.writeToBuffer());
  return sequences;
}

/// Generates valid DHT PingRequest byte sequences.
List<Uint8List> _generateValidDhtMessages() {
  final sequences = <Uint8List>[];
  // Empty PingRequest.
  sequences.add(dht_pb.PingRequest().writeToBuffer());
  // PingRequest with a peer ID.
  final kId = common_pb.KademliaId()..id = List.filled(32, 0xAA);
  final req = dht_pb.PingRequest()..peerId = kId;
  sequences.add(req.writeToBuffer());
  return sequences;
}

/// Generates a valid DHT envelope byte sequence.
Uint8List _generateValidDhtEnvelope() {
  return DHTEnvelope(
    requestId: 'test-request-123',
    payload: Uint8List.fromList(List.filled(50, 0xBB)),
  ).toBytes();
}
