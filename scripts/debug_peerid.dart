// ignore_for_file: avoid_print, curly_braces_in_flow_control_structures
import 'package:p2plib/p2plib.dart';
import 'package:dart_ipfs/src/utils/base58.dart';

void main() {
  print('Testing PeerId creation...');

  // Test 1: Ed25519 (Common modern IPFS key)
  // 12D3KooWKnDdG3iXw9eTFijk3EWSunZcFi54Zka4wmtqtt6rPxc8
  final ed25519Str = '12D3KooWKnDdG3iXw9eTFijk3EWSunZcFi54Zka4wmtqtt6rPxc8';
  try {
    final bytes = Base58().base58Decode(ed25519Str);
    print('Ed25519 bytes length: ${bytes.length}');
    final pid = PeerId(value: bytes);
    print('Ed25519 PeerId created successfully: $pid');
  } catch (e) {
    print('Ed25519 Failed: $e');
  }

  // Test 2: RSA (Classic IPFS key)
  // QmNnooDu7bfjPFoTZYxMNLWUQJyrVwtbZg5gBMjTezGAJN
  final rsaStr = 'QmNnooDu7bfjPFoTZYxMNLWUQJyrVwtbZg5gBMjTezGAJN';
  try {
    final bytes = Base58().base58Decode(rsaStr);
    print('RSA bytes length: ${bytes.length}');
    final pid = PeerId(value: bytes);
    print('RSA PeerId created successfully: $pid');
  } catch (e) {
    print('RSA Failed: $e');
  }

  // Test 3: Raw 32 bytes (Likely what p2plib wants?)
  try {
    final bytes = Uint8List(32);
    for (int i = 0; i < 32; i++) bytes[i] = i;
    final pid = PeerId(value: bytes);
    print('Raw 32 bytes PeerId created successfully: $pid');
  } catch (e) {
    print('Raw 32 bytes Failed: $e');
  }

  // Test 4: Raw 64 bytes (From existing test)
  try {
    final bytes = Uint8List(64);
    for (int i = 0; i < 64; i++) bytes[i] = i;
    final pid = PeerId(value: bytes);
    print('Raw 64 bytes PeerId created successfully: $pid');
  } catch (e) {
    print('Raw 64 bytes Failed: $e');
  }

  // Test 5: PeerId.fromKeys (32 byte keys)
  try {
    final encKey = Uint8List(32);
    final signKey = Uint8List(32);
    for (int i = 0; i < 32; i++) encKey[i] = 1;
    for (int i = 0; i < 32; i++) signKey[i] = 2;

    final pid = PeerId.fromKeys(encryptionKey: encKey, signKey: signKey);
    print('PeerId.fromKeys (32+32) created successfully: $pid');
    print('Value length: ${pid.value.length}');
  } catch (e) {
    print('PeerId.fromKeys Failed: $e');
  }
}
