// example/main.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs_core/dart_ipfs_core.dart';

void main() async {
  print('--- dart_ipfs_core Example ---');

  // 1. CID Generation from raw content
  final rawData = Uint8List.fromList(utf8.encode('InterPlanetary File System in pure Dart'));
  final cid = await CID.fromContent(rawData);
  print('Computed CIDv1: ${cid.encode()}');
  print('CID Version: ${cid.version}, Codec: ${cid.codec}');

  // 2. Block and In-Memory BlockStore
  final block = Block(cid: cid, data: rawData);
  final store = InMemoryBlockStore();
  await store.start();

  final putResult = await store.putBlock(block);
  print('Put Block: ${putResult.isSuccess} (${block.size} bytes)');

  final getResult = await store.getBlock(cid);
  if (getResult.isSuccess && getResult.data != null) {
    final retrieved = getResult.data!;
    print('Retrieved Block Payload: "${utf8.decode(retrieved.data)}"');
  }

  // 3. IPLD DAG-CBOR Serialization
  final cborCodec = DagCborCodec();
  final ipldDoc = {
    'name': 'Decentralized Artifact',
    'version': 1,
    'tags': ['ipfs', 'dart', 'crypto'],
    'link': {'/': cid.encode()},
  };

  final encodedBytes = await cborCodec.encode(ipldDoc);
  print('Encoded DAG-CBOR Size: ${encodedBytes.length} bytes');

  final decodedDoc = await cborCodec.decode(encodedBytes);
  print('Decoded Document Name: ${decodedDoc['name']}');

  // 4. Ed25519 Signing and Verification
  final signer = Ed25519Signer();
  final keyPair = await signer.generateKeyPair();
  final message = Uint8List.fromList(utf8.encode('Verify peer identity'));
  final signature = await signer.sign(message, keyPair);
  final isValid = await signer.verify(message, signature, await keyPair.extractPublicKey());
  print('Ed25519 Signature Verified: $isValid');

  await store.stop();
  print('--- Example Complete ---');
}
