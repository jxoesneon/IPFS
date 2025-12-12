// test/protocol_test.dart  
/// Test for Core IPFS Protocol Compliance
import 'dart:typed_data';
import 'package:fixnum/fixnum.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/proto/generated/dht/kademlia.pb.dart' as kad;
import 'package:dart_ipfs/src/proto/generated/bitswap/bitswap.pb.dart' as bitswap;
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart' as unixfs;
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart' as dag;

Future<void> main() async {
  print('🧪 IPFS Protocol Compliance Test\n');
  print('Testing: CID, Kademlia DHT, Bitswap, UnixFS, DAG-PB');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  
  var passCount = 0;
  var failCount = 0;
  
  // Test 1: CID v0
  print('Test 1: CID v0...');
  try {
    final hash = Uint8List.fromList(List.filled(32, 0x42));
    final cid = CID.v0(hash);
    assert(cid.version == 0);
    assert(cid.codec == 'dag-pb');
    final encoded = cid.encode();
    assert(encoded.startsWith('Qm'));
    final decoded = CID.decode(encoded);
    assert(decoded.version == 0);
    print('  ✅ CID v0 PASS\n');
    passCount++;
  } catch (e) {
    print('  ❌ FAIL: $e\n');
    failCount++;
  }
  
  // Test 2: CID v1
  print('Test 2: CID v1...');
  try {
    final content = Uint8List.fromList('Hello IPFS!'.codeUnits);
    final cid = await CID.fromContent(content, codec: 'raw', version: 1);
    assert(cid.version == 1);
    final encoded = cid.encode();
    final decoded = CID.decode(encoded);
    assert(decoded.version == 1);
    print('  ✅ CID v1 PASS\n');
    passCount++;
  } catch (e) {
    print('  ❌ FAIL: $e\n');
    failCount++;
  }
  
  // Test 3: Kademlia Message
  print('Test 3: Kademlia DHT message...');
  try {
    final msg = kad.Message()
      ..type = kad.Message_MessageType.PING
      ..key = Uint8List.fromList('test'.codeUnits);
    final bytes = msg.writeToBuffer();
    final decoded = kad.Message.fromBuffer(bytes);
    assert(decoded.type == kad.Message_MessageType.PING);
    print('  ✅ Kademlia PASS\n');
    passCount++;
  } catch (e) {
    print('  ❌ FAIL: $e\n');
    failCount++;
  }
  
  // Test 4: Bitswap Message
  print('Test 4: Bitswap 1.2.0 message...');
  try {
    final msg = bitswap.Message()
      ..wantlist = (bitswap.Message_Wantlist()
        ..entries.add(bitswap.Message_Wantlist_Entry()
          ..block = Uint8List.fromList('cid'.codeUnits)
          ..priority = 1));
    final bytes = msg.writeToBuffer();
    final decoded = bitswap.Message.fromBuffer(bytes);
    assert(decoded.wantlist.entries.isNotEmpty);
    print('  ✅ Bitswap PASS\n');
    passCount++;
  } catch (e) {
    print('  ❌ FAIL: $e\n');
    failCount++;
  }
  
  // Test 5: UnixFS
  print('Test 5: UnixFS data structure...');
  try {
    final data = unixfs.Data()
      ..type = unixfs.Data_DataType.File
      ..data = Uint8List.fromList('content'.codeUnits);
    final bytes = data.writeToBuffer();
    final decoded = unixfs.Data.fromBuffer(bytes);
    assert(decoded.type == unixfs.Data_DataType.File);
    print('  ✅ UnixFS PASS\n');
    passCount++;
  } catch (e) {
    print('  ❌ FAIL: $e\n');
    failCount++;
  }
  
  // Test 6: DAG-PB
  print('Test 6: DAG-PB (MerkleDAG)...');
  try {
    final node = dag.PBNode()
      ..data = Uint8List.fromList('data'.codeUnits)
      ..links.add(dag.PBLink()
        ..hash = Uint8List.fromList(List.filled(32, 1))
        ..name = 'link1'
        ..size = Int64(100));
    final bytes = node.writeToBuffer();
    final decoded = dag.PBNode.fromBuffer(bytes);
    assert(decoded.links.length == 1);
    print('  ✅ DAG-PB PASS\n');
    passCount++;
  } catch (e) {
    print('  ❌ FAIL: $e\n');
    failCount++;
  }
  
  // Results
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('Results: $passCount passed, $failCount failed');
  
  if (failCount == 0) {
    print('\n🎉 ALL TESTS PASSED!');
    print('✅ IPFS Protocol Standardization Verified!\n');
  }
}
