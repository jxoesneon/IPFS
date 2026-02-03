// test/mocks/test_helpers.dart
import 'dart:typed_data';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/utils/private_key.dart';

/// Test helper functions and utilities for integration tests.

/// Create a test block with specified data
Future<Block> createTestBlock(String data) async {
  final bytes = Uint8List.fromList(data.codeUnits);
  return await Block.fromData(bytes);
}

/// Create a test CID from a string
Future<CID> createTestCID(String value) async {
  // Create a simple CID for testing
  final bytes = Uint8List.fromList(value.codeUnits);
  final block = await Block.fromData(bytes);
  return block.cid;
}

/// Generate a mock private key for testing
IPFSPrivateKey generateTestPrivateKey({String? seed}) {
  // Generate a simple test key (not cryptographically secure)
  final keyBytes = Uint8List(32);
  if (seed != null) {
    final seedBytes = seed.codeUnits;
    for (var i = 0; i < 32 && i < seedBytes.length; i++) {
      keyBytes[i] = seedBytes[i];
    }
  } else {
    for (var i = 0; i < 32; i++) {
      keyBytes[i] = i;
    }
  }
  // Create from base64 encoded bytes for simplicity
  final base64Key =
      'CAESQLy4kUFsOpj1bPpKpZ+YHBvvZhhBjqDKLGKrCQQRZrGJlIzRaFD+FNqQGUDbE0xX8dEWqGglxP7QD3F3YU7FeEo=';
  return IPFSPrivateKey.fromString(base64Key);
}

/// Create multiple test blocks
Future<List<Block>> createTestBlocks(int count) async {
  final blocks = <Block>[];
  for (var i = 0; i < count; i++) {
    blocks.add(await createTestBlock('test-block-$i'));
  }
  return blocks;
}

/// Create a test block graph (linked blocks)
class TestBlockGraph {
  TestBlockGraph(this.blocks, this.rootCID);
  final List<Block> blocks;
  final CID rootCID;

  static Future<TestBlockGraph> create(int blockCount) async {
    final blocks = await createTestBlocks(blockCount);
    return TestBlockGraph(blocks, blocks.first.cid);
  }
}

