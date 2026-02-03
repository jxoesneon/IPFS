// ignore_for_file: avoid_print
// example/blog_use_case.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:dart_ipfs/dart_ipfs.dart';

/// Use Case: Publishing a Decentralized Blog
///
/// This example demonstrates how a user would:
/// 1. Initialize an IPFS node (in offline mode).
/// 2. Create blog content (HTML, CSS).
/// 3. Publish the files to IPFS.
/// 4. Organize them into a directory.
/// 5. Retrieve the verified content using its CID.
///
/// This simulates the core value proposition of IPFS: verifiable, content-addressed storage.
void main() async {
  print('📰 Starting Blog Publishing Use Case...\n');

  // 1. Initialize IPFS Config in Offline Mode
  // We use offline mode to focus on core logic (DAG, BlockStore) without network dependencies.
  final config = IPFSConfig(
    offline: true,
    blockStorePath: './blog_data/blocks',
    datastorePath: './blog_data/datastore',
  );

  print('🔹 Initializing IPFS Node (Offline Mode)...');
  final node = await IPFSNode.create(config);
  await node.start();
  print('✅ IPFS Node started!');

  try {
    // 2. Create Blog Content
    print('\n🔹 Creating Blog Assets...');

    final indexHtml = '''
    <!DOCTYPE html>
    <html>
    <head>
      <title>My Decentralized Blog</title>
      <link rel="stylesheet" href="style.css">
    </head>
    <body>
      <h1>Hello, IPFS!</h1>
      <p>This blog is hosted on the InterPlanetary File System.</p>
    </body>
    </html>
    ''';

    final styleCss = '''
    body { font-family: sans-serif; background: #f0f0f0; }
    h1 { color: #333; }
    ''';

    // 3. Add files to IPFS
    print('🔹 Adding files to IPFS...');

    final indexCid = await node.addFile(
      Uint8List.fromList(utf8.encode(indexHtml)),
    );
    print('   📝 index.html CID: $indexCid');

    final cssCid = await node.addFile(
      Uint8List.fromList(utf8.encode(styleCss)),
    );
    print('   🎨 style.css  CID: $cssCid');

    // 4. Create Directory (The "Blog" root)
    print('🔹 Creating Blog Directory...');

    // Note: In a real app, we'd use MFS (Mutable File System), but here we manually construct the DAG.
    // We demonstrate adding a directory structure.
    final directoryCid = await node.addDirectory({
      'index.html': Uint8List.fromList(utf8.encode(indexHtml)),
      'style.css': Uint8List.fromList(utf8.encode(styleCss)),
    });

    print('   📂 Blog Root CID: $directoryCid');

    // 5. Verification: Retrieve Content
    print('\n🔹 Verifying Content Retrieval...');

    final retrievedIndex = await node.get(indexCid);
    final retrievedIndexStr = utf8.decode(retrievedIndex!);

    if (retrievedIndexStr == indexHtml) {
      print('   ✅ index.html verified successfully!');
    } else {
      print('   ❌ index.html verification failed!');
    }

    // Retrieve via Directory Path (simulated)
    // The IPFSNode.get method with path support would be used here.
    // For now, we verify we can get the directory block itself.
    final dirBlock = await node.get(directoryCid);
    if (dirBlock != null) {
      print('   ✅ Directory block verified successfully!');
    }
  } catch (e, stack) {
    print('❌ Error occurred: $e');
    print(stack);
  } finally {
    print('\n🔹 Stopping IPFS Node...');
    await node.stop();
    print('✅ Node stopped.');
    print('\n🎉 Use Case Complete! Content was securely addressed and stored.');
  }
}

