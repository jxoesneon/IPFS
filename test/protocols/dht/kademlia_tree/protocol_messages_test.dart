import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/protocol_messages.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/proto/generated/dht/kademlia.pb.dart' as kad;

void main() {
  final sender = PeerId(value: Uint8List.fromList([1, 2, 3]));
  final recipient = PeerId(value: Uint8List.fromList([4, 5, 6]));
  final messageId = 'test-message-id';

  group('PingMessage', () {
    test('creates ping message', () {
      final message = PingMessage(messageId, sender, recipient);
      expect(message.messageId, equals(messageId));
      expect(message.sender, equals(sender));
      expect(message.recipient, equals(recipient));
    });

    test('converts to DHT message', () {
      final message = PingMessage(messageId, sender, recipient);
      final dhtMessage = message.toDHTMessage();
      expect(dhtMessage.type, equals(kad.Message_MessageType.PING));
    });
  });

  group('StoreMessage', () {
    test('creates store message', () {
      final key = Uint8List.fromList([1, 2, 3]);
      final value = Uint8List.fromList([4, 5, 6]);
      final message = StoreMessage(messageId, sender, recipient, key, value);
      expect(message.messageId, equals(messageId));
      expect(message.sender, equals(sender));
      expect(message.recipient, equals(recipient));
      expect(message.key, equals(key));
      expect(message.value, equals(value));
    });

    test('converts to DHT message', () {
      final key = Uint8List.fromList([1, 2, 3]);
      final value = Uint8List.fromList([4, 5, 6]);
      final message = StoreMessage(messageId, sender, recipient, key, value);
      final dhtMessage = message.toDHTMessage();
      expect(dhtMessage.type, equals(kad.Message_MessageType.PUT_VALUE));
      expect(dhtMessage.key, equals(key));
      expect(dhtMessage.record.key, equals(key));
      expect(dhtMessage.record.value, equals(value));
    });
  });

  group('FindNodeMessage', () {
    test('creates find node message', () {
      final targetId = PeerId(value: Uint8List.fromList([7, 8, 9]));
      final message = FindNodeMessage(messageId, sender, recipient, targetId);
      expect(message.messageId, equals(messageId));
      expect(message.sender, equals(sender));
      expect(message.recipient, equals(recipient));
      expect(message.targetId, equals(targetId));
    });

    test('converts to DHT message', () {
      final targetId = PeerId(value: Uint8List.fromList([7, 8, 9]));
      final message = FindNodeMessage(messageId, sender, recipient, targetId);
      final dhtMessage = message.toDHTMessage();
      expect(dhtMessage.type, equals(kad.Message_MessageType.FIND_NODE));
      expect(dhtMessage.key, equals(targetId.value));
    });
  });

  group('FindValueMessage', () {
    test('creates find value message', () {
      final key = Uint8List.fromList([10, 11, 12]);
      final message = FindValueMessage(messageId, sender, recipient, key);
      expect(message.messageId, equals(messageId));
      expect(message.sender, equals(sender));
      expect(message.recipient, equals(recipient));
      expect(message.key, equals(key));
    });

    test('converts to DHT message', () {
      final key = Uint8List.fromList([10, 11, 12]);
      final message = FindValueMessage(messageId, sender, recipient, key);
      final dhtMessage = message.toDHTMessage();
      expect(dhtMessage.type, equals(kad.Message_MessageType.GET_VALUE));
      expect(dhtMessage.key, equals(key));
    });
  });

  group('AddProviderMessage', () {
    test('creates add provider message', () {
      final key = Uint8List.fromList([13, 14, 15]);
      final message = AddProviderMessage(messageId, sender, recipient, key);
      expect(message.messageId, equals(messageId));
      expect(message.sender, equals(sender));
      expect(message.recipient, equals(recipient));
      expect(message.key, equals(key));
    });

    test('converts to DHT message', () {
      final key = Uint8List.fromList([13, 14, 15]);
      final message = AddProviderMessage(messageId, sender, recipient, key);
      final dhtMessage = message.toDHTMessage();
      expect(dhtMessage.type, equals(kad.Message_MessageType.ADD_PROVIDER));
      expect(dhtMessage.key, equals(key));
      expect(dhtMessage.providerPeers.isNotEmpty, isTrue);
      expect(dhtMessage.providerPeers.first.id, equals(sender.value));
    });
  });

  group('GetProvidersMessage', () {
    test('creates get providers message', () {
      final key = Uint8List.fromList([16, 17, 18]);
      final message = GetProvidersMessage(messageId, sender, recipient, key);
      expect(message.messageId, equals(messageId));
      expect(message.sender, equals(sender));
      expect(message.recipient, equals(recipient));
      expect(message.key, equals(key));
    });

    test('converts to DHT message', () {
      final key = Uint8List.fromList([16, 17, 18]);
      final message = GetProvidersMessage(messageId, sender, recipient, key);
      final dhtMessage = message.toDHTMessage();
      expect(dhtMessage.type, equals(kad.Message_MessageType.GET_PROVIDERS));
      expect(dhtMessage.key, equals(key));
    });
  });
}
